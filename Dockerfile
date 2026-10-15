# 第一阶段：直接拉取官方对应架构的完整版 Debian Bookworm 作为 rootfs 来源
FROM debian:bookworm AS rootfs-stage
# 清理可能引起权限冲突的特殊设备节点
RUN rm -rf /dev/* /proc/* /sys/*

# 第二阶段：构建主运行环境
FROM debian:bookworm-slim

# 1. 安装必要的系统依赖
RUN apt-get update && apt-get install -y \
    proot wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. 动态下载对应架构的 ttyd
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64"; \
    else echo "Unsupported arch: $ARCH"; exit 1; fi && \
    wget -O /usr/local/bin/ttyd "$TTYD_URL" && chmod +x /usr/local/bin/ttyd

# 3. 创建普通用户并直接从第一阶段复制完整的 Debian Rootfs（设定属主为 appuser）
RUN useradd -m -u 1000 appuser && mkdir -p /debian-rootfs
COPY --from=rootfs-stage --chown=appuser:appuser / /debian-rootfs/

USER appuser
WORKDIR /home/appuser

# 4. 配置 Web 端口和默认密码变量
ENV PORT=8080
ENV WEB_USERNAME=admin
ENV WEB_PASSWORD=dockbian123
EXPOSE 8080

# 5. 核心启动命令
CMD ["sh", "-c", "/usr/local/bin/ttyd -p ${PORT} -c ${WEB_USERNAME}:${WEB_PASSWORD} -W proot -S /debian-rootfs -0 -w /root /bin/bash"]
