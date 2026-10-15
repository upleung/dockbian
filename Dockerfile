# 使用基础 Debian 镜像进行构建
FROM debian:bookworm-slim

# 1. 安装必要的系统依赖 (proot 引擎和下载工具)
RUN apt-get update && apt-get install -y \
    proot wget tar xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. 动态下载对应架构的 ttyd 和 Debian Rootfs，并将其解压
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64" && \
        ROOTFS_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bookworm/rootfs.tar.xz"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.aarch64" && \
        ROOTFS_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-arm64v8/bookworm/rootfs.tar.xz"; \
    else echo "Unsupported arch: $ARCH"; exit 1; fi && \
    # 安装 Web 终端引擎 ttyd
    wget -O /usr/local/bin/ttyd "$TTYD_URL" && chmod +x /usr/local/bin/ttyd && \
    # 下载完全独立的 Debian 纯净版文件系统
    wget -O /rootfs.tar.xz "$ROOTFS_URL" && \
    mkdir /debian-rootfs && \
    # 忽略 /dev 等特殊挂载点报错，强行解压完整根目录
    tar -xJf /rootfs.tar.xz -C /debian-rootfs --exclude='./dev/*' || true && \
    rm /rootfs.tar.xz

# 3. 创建普通用户以满足无 root 运行的安全要求
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /debian-rootfs

USER appuser
WORKDIR /home/appuser

# 4. 配置 Web 端口和默认密码变量
ENV PORT=8080
ENV WEB_USERNAME=admin
ENV WEB_PASSWORD=dockbian123
EXPOSE 8080

# 5. 核心启动命令：通过 ttyd 启动 Web 终端，终端内部运行 proot 模拟 root 权限
CMD ["sh", "-c", "/usr/local/bin/ttyd -p ${PORT} -c ${WEB_USERNAME}:${WEB_PASSWORD} -W proot -S /debian-rootfs -0 -w /root /bin/bash"]
