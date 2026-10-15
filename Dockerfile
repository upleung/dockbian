# 第一阶段：使用官方完整版 Debian Bookworm 构建内部 Rootfs
FROM debian:bookworm AS rootfs-stage

ENV DEBIAN_FRONTEND=noninteractive

# 预装完整版 Debian 常用系统工具、Python3、GCC 编译工具链及 SSH 客户端
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    lsb-release \
    curl \
    wget \
    unzip \
    zip \
    xz-utils \
    bzip2 \
    gzip \
    tar \
    git \
    vim \
    nano \
    htop \
    procps \
    psmisc \
    lsof \
    iproute2 \
    iputils-ping \
    net-tools \
    dnsutils \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    jq \
    tmux \
    less \
    file \
    locales \
    sudo && \
    echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99proot-nosandbox && \
    echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/99proot-unsafe-io && \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 第二阶段：外层运行环境使用完整版 debian:bookworm
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ARG NEZHA_VERSION=v2.3.5

# 1. 安装外层系统依赖 (加入 unzip 用于解压 nezha-agent)
RUN apt-get update && apt-get install -y --no-install-recommends \
    proot \
    wget \
    unzip \
    ca-certificates \
    tini && \
    rm -rf /var/lib/apt/lists/*

# 2. 动态下载对应架构的 ttyd (v1.7.7) 与 nezha-agent (v2.3.5)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"; \
        NEZHA_URL="https://github.com/nezhahq/agent/releases/download/${NEZHA_VERSION}/nezha-agent_linux_amd64.zip"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64"; \
        NEZHA_URL="https://github.com/nezhahq/agent/releases/download/${NEZHA_VERSION}/nezha-agent_linux_arm64.zip"; \
    else echo "Unsupported arch: $ARCH"; exit 1; fi && \
    wget -q -O /usr/local/bin/ttyd "$TTYD_URL" && \
    chmod +x /usr/local/bin/ttyd && \
    wget -q -O /tmp/nezha-agent.zip "$NEZHA_URL" && \
    unzip -q /tmp/nezha-agent.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/nezha-agent && \
    rm -f /tmp/nezha-agent.zip

# 3. 创建非 root 普通用户并复制第一阶段的完整 Debian Rootfs
RUN useradd -m -u 1000 appuser && \
    mkdir -p /debian-rootfs /home/appuser/nezha && \
    chown -R appuser:appuser /home/appuser
COPY --from=rootfs-stage --chown=appuser:appuser / /debian-rootfs/
# 同步将 nezha-agent 复制一份到内部 Rootfs，方便在终端内直接调用查看版本或调试
RUN cp /usr/local/bin/nezha-agent /debian-rootfs/usr/local/bin/nezha-agent && \
    chown appuser:appuser /debian-rootfs/usr/local/bin/nezha-agent

# 4. 生成容器启动脚本（避免本地新建脚本产生 Windows CRLF 换行符报错）
RUN cat << 'EOF' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# 若配置了 NZ_SERVER 和 NZ_CLIENT_SECRET，则在后台启动 nezha-agent
if [ -n "$NZ_SERVER" ] && [ -n "$NZ_CLIENT_SECRET" ]; then
    # 若未手动指定 NZ_UUID，则根据通信地址与密钥生成固定 UUID，避免容器重启产生重复节点
    if [ -z "$NZ_UUID" ]; then
        HASH=$(printf "%s" "${NZ_SERVER}-${NZ_CLIENT_SECRET}" | md5sum | awk '{print $1}')
        NZ_UUID="${HASH:0:8}-${HASH:8:4}-4${HASH:13:3}-a${HASH:17:3}-${HASH:20:12}"
    fi

    cat << YAML > /home/appuser/nezha/config.yml
client_secret: ${NZ_CLIENT_SECRET}
debug: ${NZ_DEBUG:-false}
disable_auto_update: ${NZ_DISABLE_AUTO_UPDATE:-true}
disable_command_execute: ${NZ_DISABLE_COMMAND_EXECUTE:-false}
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: ${NZ_INSECURE_TLS:-false}
ip_report_period: 1800
report_delay: ${NZ_REPORT_DELAY:-3}
server: ${NZ_SERVER}
skip_connection_count: ${NZ_SKIP_CONNECTION_COUNT:-true}
skip_procs_count: ${NZ_SKIP_PROCS_COUNT:-false}
temperature: false
tls: ${NZ_TLS:-false}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${NZ_UUID}
YAML

    echo "[Init] Starting Nezha Agent (Server: ${NZ_SERVER}, TLS: ${NZ_TLS:-false}, UUID: ${NZ_UUID})..."
    /usr/local/bin/nezha-agent -c /home/appuser/nezha/config.yml >/dev/null 2>&1 &
else
    echo "[Init] NZ_SERVER or NZ_CLIENT_SECRET not set, skipping Nezha Agent startup."
fi

echo "[Init] Starting Web Terminal on port ${PORT}..."
exec /usr/local/bin/ttyd -p "${PORT}" -c "${WEB_USERNAME}:${WEB_PASSWORD}" -W \
    proot -0 -r /debian-rootfs -b /dev -b /proc -b /sys -b /etc/resolv.conf -w /root /bin/bash -l
EOF

USER appuser
WORKDIR /home/appuser

# 5. 声明所有可在面板中自定义覆盖的环境变量及默认值
ENV PORT=8080 \
    WEB_USERNAME=admin \
    WEB_PASSWORD=dockbian123 \
    NZ_SERVER="" \
    NZ_CLIENT_SECRET="" \
    NZ_TLS="false" \
    NZ_UUID="" \
    NZ_DISABLE_AUTO_UPDATE="true" \
    NZ_DISABLE_COMMAND_EXECUTE="false" \
    NZ_SKIP_CONNECTION_COUNT="true" \
    NZ_REPORT_DELAY="3" \
    PROOT_NO_SECCOMP=1 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=xterm-256color \
    LANG=en_US.UTF-8

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]