<div align="center">

# 📦 Dockbian

**基于 PRoot 与 Web 终端，在非特权容器中运行拥有完整 Root 权限的 Debian 12 (Bookworm) 系统**

[![Docker Pulls](https://img.shields.io/docker/pulls/mcgtekwrt/dockbian?style=flat-square&logo=docker&logoColor=white&label=Docker%20Pulls&color=2496ED)](https://hub.docker.com/r/mcgtekwrt/dockbian)
[![Docker Image Size](https://img.shields.io/docker/image-size/mcgtekwrt/dockbian/latest?style=flat-square&logo=docker&logoColor=white&label=Image%20Size&color=2496ED)](https://hub.docker.com/r/mcgtekwrt/dockbian)
[![Build Status](https://img.shields.io/github/actions/workflow/status/upleung/dockbian/build-push.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=Build%20%26%20Push)](https://github.com/upleung/dockbian/actions)
[![Debian](https://img.shields.io/badge/Debian-12%20(Bookworm)-A81D33?style=flat-square&logo=debian&logoColor=white)](https://www.debian.org/)
[![Arch](https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-success?style=flat-square&logo=linux&logoColor=white)](https://hub.docker.com/r/mcgtekwrt/dockbian/tags)

<br/>

[![English](https://img.shields.io/badge/🌐_Language-English-2ea44f?style=for-the-badge)](README.md)
[![简体中文](https://img.shields.io/badge/🌐_语言-简体中文-007ec6?style=for-the-badge)](README_zh.md)

</div>

---

## 📖 项目简介

**Dockbian** 是一个多架构 Docker 镜像，它将 **PRoot** 用户态沙盒引擎、完整的 **Debian 12 (Bookworm)** 根文件系统（Rootfs）、**ttyd** 网页终端以及 **哪吒监控探针 (Nezha Agent)** 深度整合到了单个轻量级容器中。

该项目专为现代容器托管平台（PaaS）、受限 Kubernetes 容器及安全沙盒内核（如 gVisor）打造。在这些环境中，平台通常强制容器以非 root 普通用户运行，且不开放原生 22（SSH）端口。通过 Dockbian，外层容器以安全的普通用户（`UID 1000`）合规运行，而你只需通过浏览器访问网页，即可进入一个模拟完整 `root`（`UID 0`）权限的 Debian 终端环境，自由使用 `apt` 安装软件包。

---

## ✨ 核心特性

- 🛡️ **免 Root 权限与沙盒兼容**：外层遵循安全规范以非特权用户（`appuser`, UID 1000）运行，内部通过 `PRoot` 模拟完整 `root` 权限并挂载独立 `/debian-rootfs`。
- 💻 **开箱即用的 Web 终端**：内置 `ttyd` (`v1.7.7`)，支持 HTTP 基础密码认证与 256 色 `xterm` 终端交互，无需暴露 22 端口即可在浏览器中操作命令行。
- 📊 **集成哪吒探针 v1**：内置 `nezha-agent` (`v2.3.5`)，支持通过环境变量自动生成 `config.yml` 配置文件与固定节点 UUID（重启容器不会产生重复节点）。
- 🧰 **完整版工具链预装**：内部 Debian 12 系统已原生预装 Python3、GCC/Make 编译工具链（`build-essential`）、Git、Vim、Tmux、SSH 客户端及常用网络诊断工具。
- 🔧 **APT / DPKG 深度调优**：预先配置禁用 `_apt` 沙盒降权报错、绕过 `seccomp` 拦截、补全 `/sbin` 环境变量路径，彻底解决用户态容器内 `apt install` 常见报错。
- 🌍 **双架构双仓库同步**：基于 GitHub Actions 自动编译构建 `linux/amd64` (`x86_64`) 与 `linux/arm64` (`aarch64`) 双架构镜像，同步推送至 Docker Hub 与 GHCR。

---

## 🚀 快速开始

### 1. Docker 命令行部署

你可以选择从 **Docker Hub** 或 **GitHub Container Registry (GHCR)** 拉取镜像：

```bash
# 从 Docker Hub 拉取
docker pull mcgtekwrt/dockbian:latest

# 或从 GHCR 拉取
docker pull ghcr.io/upleung/dockbian:latest

```

**使用默认账号密码启动（默认账号 `admin` / 默认密码 `dockbian123`）：**

```bash
docker run -d \
  --name dockbian \
  -p 8080:8080 \
  --restart unless-stopped \
  mcgtekwrt/dockbian:latest

```

**自定义密码并启用哪吒监控探针启动：**

```bash
docker run -d \
  --name dockbian \
  -p 8080:8080 \
  -e WEB_USERNAME=admin \
  -e WEB_PASSWORD=YourStrongPassword \
  -e NZ_SERVER=nezha.example.com:443 \
  -e NZ_CLIENT_SECRET=your_nezha_secret_key \
  -e NZ_TLS=true \
  --restart unless-stopped \
  mcgtekwrt/dockbian:latest

```

容器启动后，在浏览器访问 `http://localhost:8080` 并输入账号密码即可进入 root 终端。

---

### 2. Docker Compose 部署

新建 `docker-compose.yml` 文件：

```yaml
services:
  dockbian:
    image: mcgtekwrt/dockbian:latest
    container_name: dockbian
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - WEB_USERNAME=admin
      - WEB_PASSWORD=dockbian123
      - NZ_SERVER=
      - NZ_CLIENT_SECRET=
      - NZ_TLS=false

```

启动服务：

```bash
docker compose up -d

```

---

### 3. 云容器平台（PaaS）部署

1. 在容器平台选择通过 **GitHub 仓库部署** 或直接拉取 **Docker 镜像**（`mcgtekwrt/dockbian:latest`）。
2. Web 端口保持默认的 **`8080`**（或由平台自动注入 `PORT` 环境变量）。
3. 进入平台控制面板的 **Environment（环境变量）** 页面，按需自定义终端密码或填入哪吒探针参数。
4. 点击保存并重启应用，打开平台分配的 HTTPS 域名即可在浏览器中使用 Debian root 终端。

---

## ⚙️ 环境变量说明

所有配置项均支持在容器平台面板的环境变量（Environment）或 `.env` 文件中动态覆盖，无需重新编译镜像：

| 变量名 | 是否必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `PORT` | 选填 | `8080` | Web 终端监听端口 |
| `WEB_USERNAME` | 选填 | `admin` | Web 终端登录用户名 |
| `WEB_PASSWORD` | 选填 | `dockbian123` | Web 终端登录密码 |
| `NZ_SERVER` | 启用探针必填 | `""` | 哪吒面板通信地址与端口（如 `nezha.example.com:443` 或 `1.2.3.4:8008`） |
| `NZ_CLIENT_SECRET` | 启用探针必填 | `""` | 哪吒面板生成的 Agent 连接密钥（未填则自动跳过探针启动） |
| `NZ_TLS` | 选填 | `false` | 是否启用 TLS 加密连接（`443` 反代端口填 `true`，直连端口填 `false`） |
| `NZ_UUID` | 选填 | *自动固定生成* | 节点 UUID。留空时将根据通信地址与密钥自动计算固定哈希值 |
| `NZ_DISABLE_AUTO_UPDATE` | 选填 | `true` | 是否禁用探针自动更新 |
| `NZ_DISABLE_COMMAND_EXECUTE` | 选填 | `false` | 是否禁用哪吒面板远程执行命令功能 |
| `NZ_SKIP_CONNECTION_COUNT` | 选填 | `true` | 是否跳过连接数统计（建议在 gVisor 等沙盒内核下保持 `true`） |
| `NZ_REPORT_DELAY` | 选填 | `3` | 系统状态上报间隔（单位：秒，范围 1–4） |

#### 📋 `.env` 快捷粘贴模板

如果平台支持一键导入 `.env` 文件，可直接复制以下内容修改后粘贴：

```env
WEB_USERNAME=admin
WEB_PASSWORD=dockbian123
NZ_SERVER=nezha.example.com:443
NZ_CLIENT_SECRET=your_nezha_agent_secret_key
NZ_TLS=true

```

---

## 🧰 预装软件包清单

镜像内部的 Debian 12 (`bookworm`) 环境已预先安装以下常用工具，进入终端即可直接使用：

* **系统与终端工具**：`bash`, `sudo`, `procps`, `psmisc`, `htop`, `lsof`, `less`, `file`, `tmux`, `locales`
* **开发与编译环境**：`python3`, `python3-pip`, `python3-venv`, `build-essential` (`gcc`, `g++`, `make`), `git`, `jq`
* **网络与远程工具**：`curl`, `wget`, `openssh-client` (`ssh`, `scp`, `sftp`), `iproute2` (`ip`, `ss`), `iputils-ping`, `net-tools`, `dnsutils` (`dig`, `nslookup`)
* **编辑器与解压缩**：`vim`, `nano`, `tar`, `gzip`, `bzip2`, `xz-utils`, `zip`, `unzip`

如需安装其他软件，可直接在网页终端内执行 `apt update && apt install -y <软件包名>`。

---

## 🙏 致谢

本项目的实现离不开以下优秀开源项目的支持与启发：

* [linuxserver/proot-apps](https://github.com/linuxserver/proot-apps) — 提供了在 Docker 容器内运行 PRoot 用户态系统的架构思路与参考。
* [debuerreotype/docker-debian-artifacts](https://github.com/debuerreotype/docker-debian-artifacts) — 提供了纯净、可复现的 Debian 容器根文件系统构建产物。
* [proot-me/proot](https://github.com/proot-me/proot) — 强大的用户态 `chroot`、`mount --bind` 与权限模拟引擎。
* [Debian Project](https://www.debian.org/) — 稳定、自由、通用的 Linux 操作系统底座。
* [tsl0922/ttyd](https://github.com/tsl0922/ttyd) & [nezhahq/agent](https://github.com/nezhahq/agent) — 提供高性能的 Web 终端映射与轻量级服务器状态监控。