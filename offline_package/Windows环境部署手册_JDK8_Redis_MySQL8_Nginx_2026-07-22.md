# Windows 环境部署手册 — JDK 1.8 + Redis + MySQL 8.0 + Nginx

> 更新：2026-07-22 | 适用系统：Windows Server / Windows 10/11 64位
> 用途：离线环境一次性部署全套开发/运行环境
> ⚠️ 全部使用压缩包安装，无需 .msi 安装程序

---

## 一、软件清单

| 软件 | 版本 | 安装包 | 下载链接 |
|:----|:----:|:------:|---------|
| JDK 1.8 | OpenJDK 8u492 (Temurin) | zip 包（~180 MB） | [下载](https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip) |
| Redis | 7.2.8 (官方 Windows 版，含 Service) | zip 包（~16 MB） | [下载](https://github.com/redis-windows/redis-windows/releases/download/7.2.8/Redis-7.2.8-Windows-x64-msys2-with-Service.zip) |
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
# 1. 将 Redis-7.2.8-Windows-x64-msys2-with-Service.zip 解压到 D:\tools\Redis-7.2.8-Windows-x64-msys2-with-Service\
# 2. 进入解压目录
cd D:\tools\Redis-7.2.8-Windows-x64-msys2-with-Service\
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

配置文件：`D:\tools\Redis-7.2.8-Windows-x64-msys2-with-Service\redis.windows.conf`

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

### 5.4 注册为 Windows 服务（开机自启）

> 🔧 2026-07-22 Claude：Nginx 无原生 Windows 服务支持，使用 WinSW wrapper 实现自启动。
> WinSW 已随工具包下载（`offline_package/WinSW-x64.exe`）。

```bash
# 1. 将 WinSW-x64.exe 复制到 Nginx 目录并重命名
copy WinSW-x64.exe D:\tools\nginx-1.30.4\nginx-service.exe

# 2. 在同目录创建 nginx-service.xml（内容见下方）
notepad D:\tools\nginx-1.30.4\nginx-service.xml

# 3. 安装服务（以管理员身份运行）
cd D:\tools\nginx-1.30.4
nginx-service.exe install

# 4. 启动服务
nginx-service.exe start

# 5. 验证
curl http://localhost
```

**nginx-service.xml 内容（复制粘贴到文件中）：**

```xml
<service>
  <id>Nginx</id>
  <name>Nginx</name>
  <description>Nginx Web Server (nginx-1.30.4)</description>
  <executable>D:\tools\nginx-1.30.4\nginx.exe</executable>
  <stopexecutable>D:\tools\nginx-1.30.4\nginx.exe</stopexecutable>
  <stopargument>-s</stopargument>
  <stopargument>stop</stopargument>
  <startmode>Automatic</startmode>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>8</keepFiles>
  </log>
</service>
```

```bash
# ===== 服务管理命令 =====
nginx-service.exe start       # 启动
nginx-service.exe stop        # 停止
nginx-service.exe restart     # 重启
nginx-service.exe status      # 查看状态

# ===== 卸载服务 =====
nginx-service.exe stop
nginx-service.exe uninstall

# ===== 查看服务状态 =====
sc query Nginx
sc qc Nginx                   # 查看服务配置详情

---

## 六、Windows 服务自启动管理（汇总）

> 🔧 2026-07-22 Claude：三角色验证后补充。所有服务均可通过 `sc` 命令管理，
> 启动类型均为"自动(Automatic)"，重启 Windows 后自动运行。

### 6.1 服务一览

| 服务 | 服务名 | 注册方式 | 启动类型 | 依赖 |
|------|--------|---------|:--:|------|
| MySQL 8.0 | MySQL80 | `mysqld --install` | 自动 | 无 |
| Redis 7.2.8 | Redis | `redis-server --service-install` | 自动 | 无 |
| Nginx 1.30.4 | Nginx | WinSW `install` | 自动 | MySQL（可选） |

### 6.2 安装后验证（建议按此顺序）

```bash
# 1. 确认所有服务已注册
sc query state= all | findstr /i "mysql redis nginx"

# 2. 确认启动类型为"自动"
sc qc MySQL80 | findstr START_TYPE
sc qc Redis   | findstr START_TYPE
sc qc Nginx   | findstr START_TYPE

# 3. 手动启动所有服务（如果未自动启动）
net start MySQL80
net start Redis
net start Nginx

# 4. 验证服务可正常停止和重启
net stop Nginx    && net start Nginx
net stop Redis    && net start Redis
net stop MySQL80  && net start MySQL80
```

### 6.3 完全卸载（如需重装）

```bash
# 停止并删除所有服务（以管理员身份运行）
net stop Nginx    && cd D:\tools\nginx-1.30.4 && nginx-service.exe uninstall && cd \
net stop Redis    && cd D:\tools\Redis-7.2.8-Windows-x64-msys2-with-Service && redis-server.exe --service-uninstall && cd \
net stop MySQL80  && sc delete MySQL80

# 删除程序目录
rmdir /s /q D:\tools\nginx-1.30.4
rmdir /s /q D:\tools\Redis-7.2.8-Windows-x64-msys2-with-Service
rmdir /s /q D:\tools\mysql-8.0.46-winx64
```

### 6.4 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 服务启动后立刻停止 | 配置文件语法错误或端口占用 | 检查日志（Nginx: `logs/error.log`，MySQL: `data/*.err`） |
| "服务已存在" | 重复安装 | `sc delete <服务名>` 后再安装 |
| 80 端口被占用 | IIS/其他 Web 服务器在运行 | `net stop w3svc` 或改 Nginx 端口 |
| 3306 端口被占用 | 已有 MySQL 运行 | `net stop MySQL80` 或改端口 |

---

## 七、附录：下载链接汇总（可手动下载）

如果自动下载失败，可通过浏览器打开以下链接手动下载：

| 软件 | 链接 |
|:----|------|
| JDK 1.8 | `https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip` |
| Redis | `https://github.com/redis-windows/redis-windows/releases/download/7.2.8/Redis-7.2.8-Windows-x64-msys2-with-Service.zip` |
| MySQL 8.0 | `https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.46-winx64.zip` |
| Nginx | `https://nginx.org/download/nginx-1.30.4.zip` |

---

*本手册由 🧩 Reasonix 生成，2026-07-22*
