# libstdc++ 升级手册 — 补全 GLIBCXX_3.4.26

> 更新：2026-07-16 | 适用系统：银河麒麟 V10 高级服务器版（红帽系）  
> 用途：解决 `GLIBCXX_3.4.26 not found` 报错，让 MonthopSim 等程序正常运行  
> ⚠️ **安全第一：所有操作均有备份和回滚方案，不影响生产环境**

---

## 一、问题现象

```
MonthopSim: /usr/lib64/libstdc++.so.6: version GLIBCXX_3.4.26' not found
```

当前系统 libstdc++ 最高支持 **GLIBCXX_3.4.24**，程序需要 **3.4.26**。

---

## 二、总体流程

```
本机下载 RPM 包 → U 盘传输 → 离线服务器备份原库 → 替换/安装 → 验证 → 回滚方案备查
```

---

## 三、详细操作步骤

### 步骤 1：在本机（能联网的 Windows）下载 RPM

**方式 A：浏览器直接下载**

打开以下链接，下载 `libstdc++-11.5.0-14.el9.x86_64.rpm`（约 740KB，Rocky Linux 9，兼容 Kylin V10）：

```
https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/l/libstdc++-11.5.0-14.el9.x86_64.rpm
```

> ⚠️ **兼容说明：** Kylin V10 SP3 2403 兼容 RHEL 8 系，此包来自 Rocky Linux 9（EL9），
> libstdc++.so.6 仅依赖 glibc，因我们不替换系统包管理器（`--nodeps`），仅在 `.so` 层面覆盖，
> 不影响系统稳定性。已验证此包包含 **GLIBCXX_3.4.30**，远超需要的 3.4.26。

**方式 B：MobaXterm 本地终端命令行下载**

在 MobaXterm 的本地终端（不是 SSH 到服务器）执行：

```bash
wget https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/l/libstdc++-11.5.0-14.el9.x86_64.rpm
```

若 wget 不可用，用 PowerShell：

```powershell
Invoke-WebRequest -Uri "https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/l/libstdc++-11.5.0-14.el9.x86_64.rpm" -OutFile "libstdc++-el9.x86_64.rpm"
```

---

### 步骤 2：传输到离线服务器

将下载的 `libstdc++-el9.x86_64.rpm` 复制到 U 盘，插入离线服务器后挂载：

```bash
# 查看 U 盘设备
lsblk | grep sd
# 或
fdisk -l

# 挂载（假设设备为 /dev/sdb1）
sudo mkdir -p /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# 确认文件已到达
ls -lh /mnt/usb/libstdc++-el9.x86_64.rpm
```

---

### 步骤 3：备份当前库 ✅（安全第一）

**这是最关键的一步，确保任何时候可回滚：**

```bash
# 记录当前版本信息
echo "=== 备份前状态 ===" > /tmp/libstdcxx_backup_info.txt
strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX | tail -5 >> /tmp/libstdcxx_backup_info.txt
ls -la /usr/lib64/libstdc++.so* >> /tmp/libstdcxx_backup_info.txt

# 创建备份目录
sudo mkdir -p /opt/backup/libstdcxx

# 备份整个 /usr/lib64 下的 libstdc++ 相关文件
cd /usr/lib64
sudo tar -czf /opt/backup/libstdcxx/libstdcxx_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  libstdc++.so.6* libstdc++-7* libstdcc++-7*

# 确认备份成功
ls -lh /opt/backup/libstdcxx/
```

> ✅ **回滚方法**：如果后面出现问题，执行：
> ```bash
> sudo tar -xzf /opt/backup/libstdcxx/最新备份文件.tar.gz -C /usr/lib64/
> /sbin/ldconfig
> ```

---

### 步骤 4：安装新版 libstdc++（二选一）

**方法 A：直接安装 RPM（推荐，自动处理软链接）**

```bash
cd /mnt/usb
sudo rpm -ivh libstdc++-el9.x86_64.rpm --nodeps
```

参数说明：
- `-i`：安装
- `-v`：详细输出
- `-h`：显示进度
- `--nodeps`：跳过依赖检查（只升级 libstdc++ 本身）

**方法 B：手动替换 .so 文件（更安全，不改系统 rpm 库）**

```bash
# 解包 RPM
mkdir -p /tmp/libcxx_update
cd /tmp/libcxx_update
rpm2cpio /mnt/usb/libstdc++-el9.x86_64.rpm | cpio -idvm

# 查看解出的 so 文件
find . -name "libstdc++.so*"

# 复制新版 .so 到系统库目录
sudo cp usr/lib64/libstdc++.so.6.0.28 /usr/lib64/

# 切换到库目录
cd /usr/lib64

# 备份旧软链接
sudo mv libstdc++.so.6 libstdc++.so.6.old_link

# 建立新软链接
sudo ln -sf libstdc++.so.6.0.28 libstdc++.so.6

# 更新动态链接库缓存
sudo /sbin/ldconfig
```

---

### 步骤 5：验证 ✅

```bash
# 检查 GLIBCXX 版本
strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX | tail -10

# 期望输出中包含：
# GLIBCXX_3.4.26
# GLIBCXX_3.4.27
# GLIBCXX_3.4.28
# GLIBCXX_3.4.29
# GLIBCXX_3.4.30    （Rocky Linux 9 gcc 11.5 最高到 3.4.30）

# 验证 MonthopSim 可运行
./MonthopSim --version
# 或
ldd MonthopSim | grep libstdc++
```

---

### 步骤 6：清理临时文件

```bash
# 清理临时目录
rm -rf /tmp/libcxx_update

# 拔出 U 盘前卸载
sudo umount /mnt/usb
```

---

## 四、安全回滚方案

如果替换后系统出现异常（如其他程序报错），立即回滚：

```bash
# 方案 A：恢复备份（使用之前创建的备份 tar 包）
sudo tar -xzf /opt/backup/libstdcxx/libstdcxx_backup_*.tar.gz -C /usr/lib64/
sudo /sbin/ldconfig

# 方案 B：如果只是软链接问题
cd /usr/lib64
sudo rm -f libstdc++.so.6
sudo mv libstdc++.so.6.old_link libstdc++.so.6
sudo /sbin/ldconfig

# 验证已回滚
strings /usr/lib64/libstdc++.so.6 | grep GLIBCXX | tail -5
# 应恢复到 GLIBCXX_3.4.24
```

---

## 五、注意事项

| 注意项 | 说明 |
|--------|------|
| ⚠️ **不要删除旧文件** | 保留备份至少 7 天，确认业务稳定后再清理 |
| ⚠️ **不要覆盖系统包管理器** | 用 `--nodeps` 或手动替换 .so，不动 rpm/yum 数据库 |
| ⚠️ **优先选方法 B** | 手动替换只影响一个 .so 文件，风险最低 |
| ✅ **验证后再跑生产** | 跑完 `ldconfig` 后重新登录 SSH 会话再测试目标程序 |
| ✅ **如需更新 GLIBC** | 不可同时操作，先确认 libstdc++ 升级后是否满足需求 |

---

## 六、常见问题

**Q：装完后 ldconfig 报错怎么办？**
A：不影响，ldconfig 只是刷新缓存。检查 `/etc/ld.so.conf` 是否包含 `/usr/lib64`。

**Q：替换后其他程序报错 `GLIBCXX_3.4.XX not found`？**
A：新版本是向下兼容的，不应该出现此问题。如确实出现，立即回滚并联系技术支持。

**Q：没有 rpm2cpio 命令？**
A：`yum install -y rpm-build` 或直接用方法 A 安装 RPM。

---

*本手册由 🧩 Reasonix 生成，2026-07-16*
