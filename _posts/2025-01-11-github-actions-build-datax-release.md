---
categories: [编程语言, Java]
date: 2025-01-09 10:10:00 +0800
last_modified_at: 2025-01-09 11:22:00 +0800
tags:
- DataX
- GitHub Actions
title: 如何使用 GitHub Actions 构建 DataX 包并发布到 GitHub Release？
---

起因是同事需要使用 DataX，但官方并未提供直接可用的预编译包，网上搜索一圈没有找到，所以我决定基于源码自行编译 DataX，并利用 GitHub Actions 实现自动化构建和发布。

## 本地编译环境准备

如果你需要本地编译，请确保您的编译环境满足以下要求：

- **Java 版本**：使用 Java 8。
- **Maven 版本**：使用 Maven 3.5。

> **注意**：Maven 3.6 及以上版本会导致编译失败。
{: .prompt-tip }

## 步骤一：Fork 官方仓库并下载源码

首先，前往 DataX 的官方 GitHub 仓库 [https://github.com/alibaba/DataX.git](https://github.com/alibaba/DataX.git)，点击 "Fork" 将项目复制到您的账户下。然后，将 Fork 后的仓库克隆到本地：

```bash
git clone https://github.com/your-username/DataX.git
cd DataX
```

## 步骤二：添加 Maven Wrapper 支持

为了确保在任何环境下都能使用指定版本的 Maven，我们为项目添加 Maven Wrapper。执行以下命令：

```bash
mvn -N io.takari:maven:wrapper -Dmaven=3.5.4
```

这将在项目中生成 `.mvn` 目录和 `mvnw` 脚本，确保使用 Maven 3.5.4 进行构建。

## 步骤三：配置 GitHub Actions 实现自动化构建和发布

在项目根目录下，创建 `.github/workflows` 目录，并在其中添加 `release.yml` 文件，内容如下：

```yaml
name: Build and Release DataX

on:
  push:
    branches:
      - master
  create:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 设置 JDK
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '8'

      - name: 构建 DataX
        run: |
          ./mvnw -U clean package assembly:assembly -Dmaven.test.skip=true

      - name: 创建发布 Artifact
        run: |
          tar -cvf datax.tar target/datax
          xz -9e datax.tar

      - name: 上传构建产物
        uses: actions/upload-artifact@v3
        with:
          name: datax-package
          path: datax.tar.xz

  release:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - name: 下载构建的 Artifact
        uses: actions/download-artifact@v3
        with:
          name: datax-package

      - name: 创建 GitHub Release
        id: create_release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref_name }}
          release_name: "Release ${{ github.ref_name }}"
          body: |
            此版本包含最新构建的 DataX 包。
          draft: false
          prerelease: false

      - name: 上传 Release 资产到 GitHub
        uses: svenstaro/upload-release-action@v2
        with:
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          file: datax.tar.xz
          asset_name: datax.tar.xz
          tag: ${{ github.ref_name }}
```

> **注意**：选择 `tar.xz` 格式是因为 GitHub 对每个 Release 中的单个文件大小限制为 2 GiB，而 `tar.gz` 压缩后的文件约为 2.2G，超过限制。使用 `tar.xz` 压缩后，文件大小约为 1.64G，符合要求。

## 步骤四：创建标签并推送

在本地创建一个新的标签，并推送到远程仓库：

```bash
git tag v1.0.0
git push origin v1.0.0
```

推送标签后，GitHub Actions 将自动触发构建和发布流程。

## 等待构建完成并下载

大约半小时后，构建过程应已完成。前往 Fork 后的仓库的 Releases 页面，下载最新的构建包，如下图所示：

![GitHub Releases](/img/image-20250110155702.webp){: .shadow }

如果不想自行构建，可以直接下载我已构建好的包：[https://github.com/harrisonwang/DataX/releases/download/v1.0.0/datax.tar.xz](https://github.com/harrisonwang/DataX/releases/download/v1.0.0/datax.tar.xz)

## 本地编译（可选）

如果要本地进行编译，可以跳过配置 GitHub Actions 的步骤三，直接在本地执行：

```bash
./mvnw clean package -DskipTests
```

构建好的包位于本地 `target/datax` 目录。

通过上述步骤，你就实现了 DataX 的自动化构建和发布。
