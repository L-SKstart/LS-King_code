# Windows 环境部署手册 — JDK 1.8 + Redis + MySQL 8.0 + Nginx

> 更新：2026-07-22 | 适用系统：Windows Server / Windows 10/11 64位
> 用途：离线环境一次性部署全套开发/运行环境

---

## 一、软件清单

| 软件 | 版本 | 安装包大小 | 下载链接 |
|:----|:----:|:---------:|---------|
| JDK 1.8 | OpenJDK 8u492 (Temurin) | ~170 MB | [下载](https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.msi) |
| Redis | 5.0.14.1 (tporadowski) | ~10 MB | [下载](https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.msi) |
| MySQL | 8.0.46 | ~566 MB | [下载](https://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-8.0.46.0.msi) |
| Nginx | 1.30.4 (稳定版) | ~3 MB | [下载](https://nginx.org/download/nginx-1.30.4.zip) |

---

## 二、JDK 1.8 安装

### 2.1 安装步骤

```bash
# 1. 双击 OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.msi
# 2. 一路 Next，默认安装到 C:\Program Files\Eclipse Adoptium\jdk-8.0.492.09-hotspot\
# 3. 安装完成后配置环境变量
```

### 2.2 配置环境变量

右键 **此电脑 → 属性 → 高级系统设置 → 环境变量**，添加：

```
# 系统变量 → 新建
变量名: JAVA_HOME
变量值: C:\Program Files\Eclipse Adoptium\jdk-8.0.492.09-hotspot\

# 系统变量 → Path → 编辑 → 新建
%JAVA_HOME%\bin
```

### 2.3 验证

```bash
java -version
# 应输出：openjdk version "1.8.0_492"
```

---

## 三、Redis 安装

### 3.1 安装步骤

```bash
# 1. 双击 Redis-x64-5.0.14.1.msi
# 2. 安装时勾选：
#    ☑ Add the Redis installation folder to the PATH environment variable
# 3. 默认端口：6379
```

### 3.2 启动与测试

```bash
# 启动 Redis 服务
net start Redis

# 测试连接
redis-cli ping
# 应输出：PONG
```

### 3.3 常用配置

配置文件位置：`C:\Program Files\Redis\redis.windows.conf`

```conf
# 如需设置密码（去掉注释并修改）
requirepass yourpassword

# 如需绑定指定 IP
bind 127.0.0.1
```

---

## 四、MySQL 8.0 安装

### 4.1 安装步骤

```bash
# 1. 双击 mysql-installer-community-8.0.46.0.msi
# 2. 选择安装类型：Server only（仅安装 MySQL Server）
# 3. 配置类型：Development Computer（开发机）或 Server Computer（服务器）
# 4. 端口：3306（默认）
# 5. 认证方式：Use Legacy Authentication Method（兼容旧版）
# 6. 设置 root 密码
# 7. 服务名：MySQL80
# 8. 安装完成后自动启动
```

### 4.2 验证

```bash
mysql -u root -p
# 输入密码后进入 MySQL 命令行
SELECT VERSION();
# 应输出：8.0.46
```

### 4.3 常用命令

```bash
# 启动/停止 MySQL 服务
net start MySQL80
net stop MySQL80
```

---

## 五、Nginx 安装

### 5.1 安装步骤

Nginx 是绿色版，解压即用，无需安装。

```bash
# 1. 解压 nginx-1.30.4.zip
# 2. 移动到目标目录，如 C:\nginx-1.30.4\
```

### 5.2 启动与验证

```bash
# 启动
cd C:\nginx-1.30.4\
start nginx

# 验证
curl http://localhost:80
# 或在浏览器打开 http://localhost
# 应看到：Welcome to nginx!
```

### 5.3 常用命令

```bash
nginx -s stop      # 快速停止
nginx -s quit      # 优雅停止
nginx -s reload    # 重载配置
nginx -t           # 测试配置文件
```

### 5.4 配置示例

配置文件：`C:\nginx-1.30.4\conf\nginx.conf`

```nginx
server {
    listen       80;
    server_name  localhost;

    location / {
        root   html;
        index  index.html index.htm;
    }
}
```

---

## 六、附录：下载链接汇总（可手动下载）

如果自动下载失败，可通过浏览器打开以下链接手动下载：

| 软件 | 链接 |
|:----|------|
| JDK 1.8 | `https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.msi` |
| Redis | `https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.msi` |
| MySQL 8.0 | `https://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-8.0.46.0.msi` |
| Nginx | `https://nginx.org/download/nginx-1.30.4.zip` |

---

*本手册由 🧩 Reasonix 生成，2026-07-22*
