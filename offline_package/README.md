# 离线开发工具包 — 下载说明

> 生成时间：2026-07-22
> 用途：离线 Windows 环境开发工具（JDK/Redis/MySQL/Nginx/VSCode/DBeaver）

---

## 已下载（在 offline_package/ 目录下）

| 软件 | 文件 | 说明 |
|:----|:----|:------|
| VS Code | `VSCode-x64.zip` | 解压即用 |
| 中文语言包 | `vscode-language-pack-zh-hans.vsix` | 安装后 VS Code 内 Ctrl+Shift+P → 输入"Configure Display Language" → 选择中文 |

## 需自行下载

以下文件网络原因无法直接下载，请点击链接手动下载后放入 `offline_package/` 目录：

| 软件 | 版本 | 大小 | 下载链接 |
|:----|:----:|:----:|:---------|
| DBeaver Community | 最新 | ~123 MB | https://dbeaver.io/files/dbeaver-ce-latest-win32.win32.x86_64.zip |

## 配套操作手册

`docs/manuals/Windows环境部署手册_JDK8_Redis_MySQL8_Nginx_2026-07-22.md`
- JDK 1.8（压缩包安装 + 环境变量配置）
- Redis（压缩包安装 + 服务注册）
- MySQL 8.0（压缩包安装 + 初始化 + 服务注册）
- Nginx（压缩包安装 + 启动/配置）

## 安装步骤

1. 将所有文件放入 `D:\tools\` 目录（建议统一管理）
2. 按手册逐个安装配置
3. VS Code 解压后双击 `Code.exe`，装中文语言包
4. DBeaver 解压后双击 `dbeaver.exe`
