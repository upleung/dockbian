# 第一阶段：直接拉取官方对应架构的完整版 Debian Bookworm 作为 rootfs 来源
FROM debian:bookworm AS rootfs-stage

ENV DEBIAN_FRONTEND=noninteractive

# 1. 原生预装高频基础工具，并写入 proot 专用的 apt/dpkg 兼容配置
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    unzip \
    xz-utils \
    git \
    vim \
    nano \
    procps \
    iproute2 \
    iputils-ping \
    locales \
    sudo && \
    # 禁用 apt 沙盒降权与同步 I/O 限制，防止在 proot 内执行 apt 报错
    echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99proot-nosandbox && \
    echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/99proot-unsafe-io && \
    # 生成 UTF-8 语言环境，防止终端中文乱码
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 第二阶段：构建主运行环境
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装必要的系统依赖 (引入 tini 防止僵尸进程)
RUN apt-get update && apt-get install -y --no-install-recommends \
    proot \
    wget \
    ca-certificates \
    tini && \
    rm -rf /var/lib/apt/lists/*

# 2. 动态下载对应架构的 ttyd
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64"; \
    else echo "Unsupported arch: $ARCH"; exit 1; fi && \
    wget -q -O /usr/local/bin/ttyd "$TTYD_URL" && \
    chmod +x /usr/local/bin/ttyd

# 3. 创建普通用户并直接从第一阶段复制完整的 Debian Rootfs（设定属主为 appuser）
RUN useradd -m -u 1000 appuser && mkdir -p /debian-rootfs
COPY --from=rootfs-stage --chown=appuser:appuser / /debian-rootfs/

USER appuser
WORKDIR /home/appuser

# 4. 配置 Web 端口、默认密码及 proot 运行环境变量
# 显式补全 /usr/sbin 和 /sbin 到 PATH，解决非 root 用户下 dpkg 找不到 ldconfig 的问题
ENV PORT=8080 \
    WEB_USERNAME=admin \
    WEB_PASSWORD=dockbian123 \
    PROOT_NO_SECCOMP=1 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=xterm-256color \
    LANG=en_US.UTF-8

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]

# 5. 核心启动命令：加入 -L 将硬链接转为软链接，显式绑定系统目录
CMD ["sh", "-c", "exec /usr/local/bin/ttyd -p ${PORT} -c ${WEB_USERNAME}:${WEB_PASSWORD} -W proot -L -0 -r /debian-rootfs -b /dev -b /proc -b /sys -b /etc/resolv.conf -w /root /bin/bash -l"]