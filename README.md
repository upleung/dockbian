<div align="center">

# 📦 Dockbian

**Run a Full Root-Simulated Debian 12 (Bookworm) Environment Inside an Unprivileged Container via PRoot & Web Terminal**

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

## 📖 Introduction

**Dockbian** is a multi-architecture Docker image that combines **PRoot**, a complete **Debian 12 (Bookworm)** root filesystem, **ttyd** (Web Terminal), and **Nezha Agent** into a single lightweight container.

It is specifically designed for modern container hosting platforms (PaaS), Kubernetes pods, and restricted sandbox environments (such as gVisor) where containers are forced to run as a non-root user and native SSH (Port 22) is blocked. With Dockbian, the outer container runs safely as an unprivileged user (`UID 1000`), while giving you a full root-simulated (`UID 0`) Debian shell directly in your browser.

---

## ✨ Key Features

- 🛡️ **Rootless & Sandbox Friendly**: Runs externally as non-root (`appuser`, UID 1000) to pass strict PaaS security policies, while simulating full `root` privileges internally via `PRoot`.
- 💻 **Browser-Based Web Terminal**: Powered by `ttyd` (`v1.7.7`) with HTTP Basic Authentication and full 256-color `xterm` support. No SSH port exposure required.
- 📊 **Built-in Nezha Monitoring**: Pre-packaged with `nezha-agent` (`v2.3.5`). Automatically generates configuration and deterministic node UUIDs via environment variables.
- 🧰 **Batteries-Included Debian 12**: Pre-installed with essential system tools, network diagnostics, `python3`, `gcc`/`make` (`build-essential`), `git`, `vim`, `tmux`, and `openssh-client`.
- 🔧 **APT & DPKG Optimized**: Pre-configured to bypass `_apt` sandbox privilege-drop errors, `seccomp` filters, and `sbin` `PATH` limitations in user-space environments.
- 🌍 **Multi-Arch Support**: Automatically built and pushed for both `linux/amd64` (`x86_64`) and `linux/arm64` (`aarch64`).

---

## 🚀 Quick Start

### 1. Docker CLI

You can pull the image from either **Docker Hub** or **GitHub Container Registry (GHCR)**:

```bash
# Pull from Docker Hub
docker pull mcgtekwrt/dockbian:latest

# Or pull from GHCR
docker pull ghcr.io/upleung/dockbian:latest

```

**Run with default credentials (`admin` / `dockbian123`):**

```bash
docker run -d \
  --name dockbian \
  -p 8080:8080 \
  --restart unless-stopped \
  mcgtekwrt/dockbian:latest

```

**Run with custom credentials and Nezha Agent enabled:**

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

Once started, open `http://localhost:8080` in your browser and log in.

---

### 2. Docker Compose

Create a `docker-compose.yml` file:

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

Start the service:

```bash
docker compose up -d

```

---

### 3. Cloud & PaaS Platform Deployment

1. Select **Deploy from GitHub Repository** or **Deploy from Docker Image** (`mcgtekwrt/dockbian:latest`).
2. Expose HTTP port **`8080`** (or let the platform inject the `PORT` variable automatically).
3. Navigate to the platform's **Environment Variables** settings to customize your login password or Nezha Agent parameters.
4. Save and restart the application, then visit the assigned HTTPS domain to access your root terminal.

---

## ⚙️ Environment Variables

All parameters can be customized dynamically via container environment variables or a `.env` file without rebuilding the image:

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `PORT` | No | `8080` | Web terminal listening port |
| `WEB_USERNAME` | No | `admin` | HTTP Basic Auth username for the Web terminal |
| `WEB_PASSWORD` | No | `dockbian123` | HTTP Basic Auth password for the Web terminal |
| `NZ_SERVER` | Optional* | `""` | Nezha dashboard gRPC address & port (e.g., `nezha.example.com:443`) |
| `NZ_CLIENT_SECRET` | Optional* | `""` | Nezha Agent secret key (Required if `NZ_SERVER` is set) |
| `NZ_TLS` | No | `false` | Enable TLS encryption for Nezha connection (`true` or `false`) |
| `NZ_UUID` | No | *Auto-generated* | Custom UUID for Nezha node. If empty, a fixed UUID is derived from server & secret |
| `NZ_DISABLE_AUTO_UPDATE` | No | `true` | Disable automatic binary updates for Nezha Agent |
| `NZ_DISABLE_COMMAND_EXECUTE` | No | `false` | Disable remote command execution from Nezha dashboard |
| `NZ_SKIP_CONNECTION_COUNT` | No | `true` | Skip network connection counting (Recommended in sandboxed/gVisor kernels) |
| `NZ_REPORT_DELAY` | No | `3` | System status reporting interval in seconds (1–4) |

#### 📋 Quick `.env` Template

```env
WEB_USERNAME=admin
WEB_PASSWORD=dockbian123
NZ_SERVER=nezha.example.com:443
NZ_CLIENT_SECRET=your_nezha_agent_secret_key
NZ_TLS=true

```

---

## 🧰 Pre-installed Toolkit

The internal Debian 12 (`bookworm`) rootfs comes pre-loaded with commonly used utilities so you can start working immediately:

* **System & Shell**: `bash`, `sudo`, `procps`, `psmisc`, `htop`, `lsof`, `less`, `file`, `tmux`, `locales`
* **Development & Build**: `python3`, `python3-pip`, `python3-venv`, `build-essential` (`gcc`, `g++`, `make`), `git`, `jq`
* **Network & Remote**: `curl`, `wget`, `openssh-client` (`ssh`, `scp`, `sftp`), `iproute2` (`ip`, `ss`), `iputils-ping`, `net-tools`, `dnsutils` (`dig`, `nslookup`)
* **Editors & Archives**: `vim`, `nano`, `tar`, `gzip`, `bzip2`, `xz-utils`, `zip`, `unzip`

Need more packages? Simply run `apt update && apt install -y <package>` directly inside the Web terminal!

---

## 🙏 Acknowledgements

This project stands on the shoulders of the following open-source projects:

* [linuxserver/proot-apps](https://github.com/linuxserver/proot-apps) — Inspiration and architecture reference for running PRoot applications in userspace within Docker.
* [debuerreotype/docker-debian-artifacts](https://github.com/debuerreotype/docker-debian-artifacts) — Reproducible Debian rootfs artifacts for container images.
* [proot-me/proot](https://github.com/proot-me/proot) — User-space implementation of `chroot`, `mount --bind`, and `binfmt_misc`.
* [Debian Project](https://www.debian.org/) — The universal operating system powering the container environment.
* [tsl0922/ttyd](https://github.com/tsl0922/ttyd) & [nezhahq/agent](https://github.com/nezhahq/agent) — Web terminal sharing and lightweight server monitoring.

