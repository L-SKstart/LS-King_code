# Windows 环境部署手册 — JDK 1.8 + Redis + MySQL 8.0 + Nginx

> 更新：2026-07-22 | 适用系统：Windows Server / Windows 10/11 64位
> 用途：离线环境一次性部署全套开发/运行环境
> ⚠️ 全部使用压缩包安装，无需 .msi 安装程序

---

## 一、软件清单

| 软件 | 版本 | 安装包 | 下载链接 |
|:----|:----:|:------:|---------|
| JDK 1.8 | OpenJDK 8u492 (Temurin) | zip 包（~180 MB） | [下载](https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip) |
| Redis | 7.2.7 (官方 Windows 版) | zip 包（~30 MB） | [下载](https://github.com/redis-windows/redis-windows/releases/download/7.2.7/Redis-7.2.7-Windows-x64.zip) |
| MySQL | 8.0.46 | zip 包（~260 MB） | [下载](https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip) |
| Nginx | 1.30.4 (稳定版) | zip 包（~3 MB） | [下载](https://nginx.org/download/nginx-1.30.4.zip) |

---

## 二、JDK 1.8 安装

### 2.1 解压安装

```bash
# 1. 将 OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip 复制到目标目录
# 2. 解压到目标目录，如 D:\tools\jdk-8.0.492.09-hotspot\
#    建议统一放在 D:\tools\ 下
```

### 2.2 配置环境变量

右键 **此电脑 → 属性 → 高级系统设置 → 环境变量**，添加：

```
# 系统变量 → 新建
变量名: JAVA_HOME
变量值: D:\tools\jdk-8.0.492.09-hotspot\

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

### 3.1 解压安装

```bash
# 1. 将 Redis-7.2.7-Windows-x64.zip 解压到 D:\tools\redis-7.2.7\
# 2. 进入解压目录
cd D:\tools\redis-7.2.7\
```

### 3.2 启动

```bash
# 启动 Redis 服务（前台运行，关窗口即停止）
redis-server.exe

# 或者注册为 Windows 服务（后台运行）
redis-server.exe --service-install
redis-server.exe --service-start

# 测试连接
redis-cli ping
# 应输出：PONG
```

### 3.3 常用配置

配置文件：`D:\tools\redis-7.2.7\redis.windows.conf`

```conf
# 如需设置密码
requirepass yourpassword

# 如需绑定指定 IP
bind 127.0.0.1

# 如需后台运行（非服务模式）
daemonize yes
```

---

## 四、MySQL 8.0 安装

### 4.1 解压安装

```bash
# 1. 将 mysql-8.0.46-winx64.zip 解压到 D:\tools\mysql-8.0.46-winx64\
# 2. 进入解压目录
cd D:\tools\mysql-8.0.46-winx64\
```

### 4.2 初始化数据目录

```bash
# 创建数据目录
mkdir data

# 初始化数据库（生成 root 临时密码）
mysqld --initialize --console
# ↑ 记下输出的临时密码，类似：root@localhost: xxxxxxxx
```

### 4.3 安装 MySQL 服务并启动

```bash
# 安装 Windows 服务
mysqld --install MySQL80

# 启动服务
net start MySQL80

# 使用临时密码登录
mysql -u root -p
# 输入刚才记下的临时密码
```

### 4.4 修改 root 密码

登录 MySQL 后执行：

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';
```

### 4.5 验证

```bash
mysql -u root -p123456
SELECT VERSION();
# 应输出：8.0.46
```

### 4.6 常用命令

```bash
# 启动/停止 MySQL 服务
net start MySQL80
net stop MySQL80

# 卸载服务（如需重装）
mysqld --remove MySQL80
```

---

## 五、Nginx 安装

### 5.1 解压安装

```bash
# 1. 将 nginx-1.30.4.zip 解压到 D:\tools\nginx-1.30.4\
```

### 5.2 启动与验证

```bash
# 启动
cd D:\tools\nginx-1.30.4\
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

配置文件：`D:\tools\nginx-1.30.4\conf\nginx.conf`

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
| JDK 1.8 | `https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip` |
| Redis | `https://github.com/redis-windows/redis-windows/releases/download/7.2.7/Redis-7.2.7-Windows-x64.zip` |
| MySQL 8.0 | `https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip` |
| Nginx | `https://nginx.org/download/nginx-1.30.4.zip` |

---

*本手册由 🧩 Reasonix 生成，2026-07-22*
