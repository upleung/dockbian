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
    # 适配 proot 用户态环境，禁用 apt 沙盒降权与同步 I/O 限制
    echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/99proot-nosandbox && \
    echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/99proot-unsafe-io && \
    # 生成 UTF-8 语言环境
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 第二阶段：外层运行环境同样使用完整版 debian:bookworm（移除 slim）
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装外层系统依赖
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

# 3. 创建非 root 普通用户并复制第一阶段的完整 Debian Rootfs
RUN useradd -m -u 1000 appuser && mkdir -p /debian-rootfs
COPY --from=rootfs-stage --chown=appuser:appuser / /debian-rootfs/

USER appuser
WORKDIR /home/appuser

# 4. 配置环境变量
ENV PORT=8080 \
    WEB_USERNAME=admin \
    WEB_PASSWORD=dockbian123 \
    PROOT_NO_SECCOMP=1 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=xterm-256color \
    LANG=en_US.UTF-8

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]

# 5. 启动命令
CMD ["sh", "-c", "exec /usr/local/bin/ttyd -p ${PORT} -c ${WEB_USERNAME}:${WEB_PASSWORD} -W proot -0 -r /debian-rootfs -b /dev -b /proc -b /sys -b /etc/resolv.conf -w /root /bin/bash -l"]