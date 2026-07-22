# 离线开发工具包 — 下载说明

> 生成时间：2026-07-22 | 更新：2026-07-22 17:25 (🎯 Claude)
> 用途：离线 Windows 环境全套开发工具（JDK/Redis/MySQL/Nginx/VSCode/DBeaver）

---

## 已下载（在 offline_package/ 目录下）

| 软件 | 版本 | 文件 | 大小 | 状态 |
|:----|:----|:-----|:----:|:--:|
| VS Code | 最新 | `VSCode-x64.zip` | ~296 MB | ✅ |
| VS Code 中文语言包 | 最新 | `vscode-language-pack-zh-hans.vsix` | ~600 KB | ✅ |
| DBeaver Community | 最新 | `dbeaver-ce.zip` | ~124 MB | ✅ |
| JDK 1.8 | OpenJDK 8u492 (Temurin) | `OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip` | ~102 MB | ✅ |
| Redis | 7.2.8 (含 Windows Service) | `Redis-7.2.8-Windows-x64-msys2-with-Service.zip` | ~16 MB | ✅ |
| MySQL | 8.0.46 | `mysql-8.0.46-winx64.zip` | ~237 MB | ✅ |
| Nginx | 1.30.4 (稳定版) | `nginx-1.30.4.zip` | ~2.7 MB | ✅ |
| WinSW | 3.0-alpha.11 | `WinSW-x64.exe` | ~18 MB | ✅ |

---

## 汉化说明

| 软件 | 汉化方式 |
|:----|:---------|
| VS Code | 安装 `vscode-language-pack-zh-hans.vsix` → Ctrl+Shift+P → Configure Display Language → 中文简体 |
| DBeaver | **已内置中文**。启动后：窗口 → 首选项 → User Interface → 选择 Simplified Chinese。或编辑 `dbeaver.ini`，在 `-vmargs` 前加 `-nl zh` |

---

## 配套部署手册

📘 **`Windows环境部署手册_JDK8_Redis_MySQL8_Nginx_2026-07-22.md`**（已放入本目录）

涵盖内容：

- JDK 1.8 — 压缩包安装 + 环境变量配置（JAVA_HOME / PATH）
- Redis 7.2.8 — 压缩包安装 + Windows 服务注册（开机自启）
- MySQL 8.0.46 — 压缩包安装 + 初始化 + 服务注册（开机自启）
- Nginx 1.30.4 — 压缩包安装 + WinSW 服务注册（开机自启）
- 服务管理章节 — 验证、启动、停止、卸载、常见问题

---

## 安装步骤（概览）

1. 将本目录所有文件复制到目标电脑（U 盘/移动硬盘）
2. 建议统一解压到 `D:\tools\` 下
3. 按部署手册逐项安装配置
4. VS Code 解压后双击 `Code.exe`，安装中文语言包
5. DBeaver 解压后双击 `dbeaver.exe`，切换语言为中文
