---
categories: [计算机网络]
date: 2025-01-10 13:12:00 +0800
last_modified_at: 2025-01-10 13:22:00 +0800
tags:
- Docker
- 镜像代理
- 代理
title: 使用 Docker 镜像代理站后，docker build 为什么会失败？
---

如果你使用 Docker 镜像代理站，可能会遇到一个让人困惑的问题：明明 `docker pull` 命令可以成功拉取镜像，但在使用 `docker build` 或 `docker compose build` 构建镜像时却会失败。这是什么原因导致的呢？

关于 Docker 镜像代理站搭建，可以参考我前面的文章[《如何使用 Cloudflare Workers 自建 Docker 镜像代理》](https://voxsay.com/posts/how-to-build-docker-hub-mirror-with-cloudflare-workers/)和[《解决国内无法下载 Docker 镜像的问题》](https://voxsay.com/posts/china-docker-registry-proxy-guide/)。

## 问题原因分析

从 Docker 19.03 版本开始，BuildKit 默认启用作为构建引擎。虽然镜像代理站能够加速镜像拉取，但它本质上只是一个代理层，镜像的 manifest 文件依然指向官方 Docker 地址。当 BuildKit 尝试读取 manifest 文件时，仍需向 `auth.docker.io/token` 请求匿名 token。然而，由于网络环境（如 GFW）的干扰，这个请求会被阻断，导致构建失败。

错误日志如下：

```bash
Sending build context to Docker daemon  1.208GB
Step 1/6 : FROM pytorch/torchserve:0.11.0-gpu as builder
Get "https://registry-1.docker.io/v2/": read tcp 192.168.210.99:53042->54.236.113.205:443: read: connection reset by peer
```

## 解决方案

针对这个问题，有两种主要解决思路：

### 方法 1：禁用 BuildKit，使用传统构建方式

通过禁用 BuildKit，可以回退到传统的 Docker 构建方式。这种方法分为以下几种场景：

#### 1.1 命令行临时禁用 BuildKit

在构建镜像之前，首先将 Dockerfile 中的基础镜像地址指向镜像代理站。例如：

```Dockerfile
FROM your-mirror-site/pytorch/torchserve:0.11.0-gpu as builder
```

然后，通过以下命令临时禁用 BuildKit，并使用传统构建方式：

```bash
DOCKER_BUILDKIT=0 docker build -f Dockerfile -t image-name:latest .
```

或者：

```bash
DOCKER_BUILDKIT=0 docker compose build
```

又或者直接使用 `docker compose up -d` 命令，它会拉取和构建镜像，然后启动容器。

#### 1.2 临时环境变量禁用 BuildKit

你也可以在当前终端会话中通过设置环境变量临时禁用 BuildKit：

```bash
export DOCKER_BUILDKIT=0
```

然后执行构建命令：

```bash
docker build -f Dockerfile -t image-name:latest .
```

或者：

```bash
docker compose build
```

或者直接使用 `docker compose up -d` 命令，它会拉取和构建镜像，然后启动容器。

##### 1.3 永久禁用 BuildKit（不推荐）

修改 Docker 的环境变量配置文件，永久禁用 BuildKit。虽然方便，但并不建议这样做，因为 BuildKit 目前才是官方推荐的构建工具。

> 有文章说可以通过 `"buildkit": false` 配置永久禁用，尝试后发现并没有效果。
{: .prompt-tip }

### 方法 2：为 BuildKit 配置代理

如果已经有网络代理，可以直接为 BuildKit 配置代理，这样就不需要依赖 Docker 镜像代理站了，也就不存在这个问题。可以编辑 `/etc/docker/daemon.json` 文件，添加以下内容添加 Docker 的代理：

```json
{
  "proxies": {
    "http-proxy": "socks5://192.168.208.55:10808",
    "https-proxy": "socks5://192.168.208.55:10808",
    "no-proxy": "127.0.0.0/8"
  }
}
```

> 注意：Docker 支持配置镜像代理，也就是 mirror，同时也支持配置网络代理，也就是 proxy，这里的代理指的是 proxy。

保存后，重启 Docker 服务使配置生效：

```bash
sudo systemctl restart docker
```

配置完成后，BuildKit 可以通过代理访问网络，从而避免因网络问题导致的构建失败。

---

## 总结

Docker 构建失败的问题主要与 BuildKit 的网络访问机制有关。通过禁用 BuildKit或者为其配置网络代理，都可以有效解决问题。如果你希望更灵活的解决方案，可以根据使用场景选择适合的方法：

- **临时禁用 BuildKit**：适合短期构建任务；
- **为 BuildKit 配置代理**：适合需要长期支持的场景。
