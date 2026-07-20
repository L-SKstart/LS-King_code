# A-离线服务器-安全预控项目 完整操作手册

> 日期：2026-06-25 | 服务器：银河麒麟 ky10 | 架构：x86_64 | 项目路径：`/opt/glzz`

---

## 一、创建用户

```bash
useradd -m gluser
passwd gluser
```

`useradd -m` 自动创建同名组 `gluser`、家目录 `/home/gluser`。输密码时不回显，输入两次。

```bash
id gluser    # 验证
```

---

## 二、文件传输（离线环境）

物理隔离，scp 不可用，用 U 盘中转：

```bash
# 本地：U 盘插上，拷文件进去
cp /本地文件路径 /run/media/你的用户/U盘名/

# 服务器：U 盘插上，找到挂载点，拷出来
lsblk | grep sd          # 确认 U 盘设备
cp /run/media/gluser/U盘名/文件名 /opt/glzz/
```

---

## 三、安装 Xvfb + 字体

```bash
dnf install xorg-x11-server-Xvfb -y
dnf install wqy-microhei-fonts -y
```

如果离线 yum 源不可用，需先挂 ISO：

```bash
mount /path/to/kylin.iso /mnt
cat > /etc/yum.repos.d/local.repo << 'EOF'
[local-base]
name=Kylin Local Base
baseurl=file:///mnt
enabled=1
gpgcheck=0
EOF
dnf clean all && dnf makecache
```

---

## 四、启动 Xvfb 虚拟显示器

```bash
Xvfb :1 -screen 0 1920x1080x24 &
```

| 参数 | 含义 |
|------|------|
| `:1` | 虚拟显示器编号 |
| `1920x1080` | 分辨率 |
| `x24` | 色深 |
| `&` | 后台运行 |

验证：`ps aux | grep Xvfb`

> ⚠️ Xvfb 是虚拟帧缓冲，窗口在内存中渲染，物理屏幕看不到。

---

## 五、启动 Java 程序

### 5.1 程序依赖

| 组件 | 路径 |
|------|------|
| JAR | `/opt/glzz/reverse-client.jar` |
| 配置文件 | `/opt/glzz/ClientConfig` |
| 原生库 | `/opt/glzz/lib/libsigar-amd64-linux.so` |

### 5.2 一行启动（Xvfb 模式）

```bash
cd /opt/glzz && DISPLAY=:1 java -Djava.library.path=/opt/glzz/ -jar /opt/glzz/reverse-client.jar &
```

| 参数 | 作用 |
|------|------|
| `cd /opt/glzz` | 工作目录 → 程序找到 `ClientConfig` |
| `DISPLAY=:1` | 指向 Xvfb 虚拟显示器 |
| `-Djava.library.path=/opt/glzz/` | 加载 Sigar 原生库 |
| `&` | 后台运行 |

### 5.3 物理显示器模式

```bash
xhost +SI:localuser:gluser
cd /opt/glzz && DISPLAY=:0 java -Djava.library.path=/opt/glzz/ -jar /opt/glzz/reverse-client.jar &
```

| DISPLAY | 效果 |
|---------|------|
| `:0` | 物理显示器，能看见窗口 |
| `:1` | Xvfb 虚拟，看不见窗口 |

---

## 六、run.sh 管理脚本

路径：`/opt/glzz/run.sh`

```bash
#!/bin/bash

APP_DIR="/opt/glzz"
JAR="reverse-client.jar"
DISPLAY_NUM=":1"

export DISPLAY=$DISPLAY_NUM

stop() {
    PID=$(ps aux | grep "$JAR" | grep -v grep | awk '{print $2}')
    if [ -n "$PID" ]; then
        kill $PID
        echo "已停止 PID: $PID"
    else
        echo "进程未运行"
    fi
}

start() {
    cd "$APP_DIR"
    DISPLAY=$DISPLAY_NUM \
        java -Djava.library.path="$APP_DIR/" -jar "$APP_DIR/$JAR" &
    echo "已启动"
}

restart() {
    stop
    sleep 2
    start
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    *)       echo "用法: $0 {start|stop|restart}" ;;
esac
```

```bash
chmod +x /opt/glzz/run.sh
/opt/glzz/run.sh start       # 启动
/opt/glzz/run.sh restart     # 重启
/opt/glzz/run.sh stop        # 停止
```

---

## 七、sudo 权限

```bash
echo "gluser ALL=(ALL) NOPASSWD: /opt/glzz/run.sh" >> /etc/sudoers.d/gluser
chmod 440 /etc/sudoers.d/gluser
```

验证：`sudo -u gluser sudo -l`

---

## 八、常见报错速查

| 报错 | 原因 | 解决 |
|------|------|------|
| `no libsigar-amd64-linux.so` | 原生库不在路径 | `-Djava.library.path=/opt/glzz/` |
| `FileNotFoundException: ClientConfig` | 工作目录不对 | 先 `cd /opt/glzz` |
| `Can't connect to X11` | gluser 无权连 X | `xhost +SI:localuser:gluser` |
| `No X11 DISPLAY` / `HeadlessException` | 变量丢失 | `export DISPLAY && java` 同一行 |
| `Errors from xkbcomp are not fatal` | 键盘布局警告，忽略 | — |
| `mount -o loop` read-only | ISO 9660/squashfs 天生只读 | 确认文件系统类型 |
| `Transaction test error` | yum 包冲突（麒麟 mini vs 完整版） | `rpm -e --nodeps kylin-settings-mini` |
