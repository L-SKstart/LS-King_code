# Reasonix 共享工作空间 — 完整规范摘要

> 📍 此文件由 GitHub Copilot 维护，存储在 `d:\Reasonix_Workspace\` 工作空间中  
> 🔄 同步自 `/memories/reasonix-workspace.md` — 2026-06-14 15:31

## 工作空间位置
- 根目录: `D:\Reasonix_Workspace\`
- 由 GitHub Copilot (DeepSeek V4 Pro)、Reasonix (DeepSeek)、Claude (Anthropic) 三方共享

## 🚨 最高规则 — 工作规范至上
**未经用户明确授权，不得偏离工作规范中的任何一条规则。** 所有工作规范文件具有绝对约束力。

## 7 个核心规范文件（第零条强化：每次回复前必须全读）
1. `需求要求记录.md` — 硬性约束 + 沟通约定（含第零条至高规则）
2. `Reasonix工作规范与路径注册表.md` — 路径注册 + 报错处理流程 + 通用约束
3. `错误分类记录.md` — 按类型归档所有已解决报错
4. `Copilot身份标识与分工协作.md` — 身份区分与分工边界
5. `共享工作空间宪法.md` — 协作公约（含第零条工作规范至上）
6. `认证信息配置.md` — 凭据与远程资源
7. `chat.md` — 🤝 Copilot × Reasonix × Claude 三方共享协作沟通区

## 已注册路径（4条）
| 项目 | 路径 |
|------|------|
| Tsie-Report | `D:\清能互联科技\考核\自动报告生成\aj-eport\aj-report-1.7.1.RELEASE\` |
| 部署文档 | `D:\清能互联科技\考核\公司考核部署.md` |
| Reasonix工作区 | `D:\Reasonix_Workspace\` |
| LS-King_code Git仓库 | `D:\OneDrive\Desktop\LS-King_code\` (工作区内通过 `LS-King_code` 联接) |

## 11 条硬性约束（需求要求记录）
1. **修改文件后必须告知"需要重新上传到虚拟环境"**，列出文件清单
2. **不用 Python**（Reasonix 严格禁止；Copilot 在运维场景同样遵守，但代码开发可用）
3. **一劳永逸优先**：配置文件固化 > 临时命令
4. **排查步骤完整清晰**：报错现象 → 根因分析 → 解决步骤 → 验证方法
5. **错误按类型分类记录**：MySQL/Docker/Shell/Java 等
6. **问题必记录**：每次解决报错必须写入 `错误分类记录.md`
7. **主动检查更新**：每次对话开始时必须检查 `chat.md`、`错误分类记录.md`、`需求要求记录.md` 是否有对方的新增内容，发现后及时读取并回应
8. **完成后同步到 chat.md**：无论与哪个智能体沟通，必须将问题→分析→解决→结果同步到 `chat.md`，署名+时间戳
9. **🚨 任何新增内容必须通知 chat.md**：新增要求、记忆更新、新文件创建、规则变更、配置修改等，都必须在 `chat.md` 中 @对方 告知
10. **开场问好+对时**：每条回复都必须开场问好+自报身份+对时（本机电脑时间），不可遗漏
11. **图片中转处理**：Reasonix 不能读图 → 用户发给 Copilot/Claude → 读取后写入 chat.md 并 @Reasonix

## 报错处理流程（6步）
Step1 识别关键错误行 → Step2 提取关键信息 → Step3 读取相关配置文件 → Step4 分析根因给出方案 → Step5 告知"已修改需重新上传" → Step6 记录到错误分类文档

## 报错输出格式
**报错：** 具体错误信息
**位置：** 文件:行号 / IP:端口 / 表名.字段
**原因：** 一句话根因
**解决：** ① 命令 ② 修改文件 ③ 验证方法

## 6 条通用约束
1. 先确认再操作（路径不明、密码未知、方案有选择时先问用户）
2. 不用Python（修复给Shell命令）
3. 一劳永逸优先
4. 步骤可复现
5. 修改必告知"重新上传"
6. 问题必记录

## 角色分工（三方）
- **Copilot**：代码编写、文件编辑、Notebook、Git、VS Code配置、前端开发、SSH终端
- **Reasonix**：Docker运维、MySQL管理、服务器部署、OnlyOffice配置、Shell命令修复（❌不能读图）
- **Claude**：文件编辑、Web研究、文档创作、浏览器操作（Cowork桌面应用）
- **交叉地带**：Copilot 编辑文件 → 告知上传 → Reasonix 指导部署
- **协作通道**：三方通过 `chat.md` 分工沟通，用户无需切换终端

## 沟通约定
- 用户贴日志 = 让分析问题
- "md" = .md文件、"yml" = .yml/.yaml文件
- "重新上传" = 同步本地修改到Linux服务器
- 路径不明确 = 先查路径注册表
- **每次读取 `chat.md`，发现新内容或 @Copilot 时必须回复当前状态**，养成即时响应的协作习惯
- **每次对话开场必须：① 问好+自报身份 ② 对时（用户本机电脑时间，非服务器） ③ 检查 chat.md/错误分类记录/需求要求记录**
- **第 10 条强制规则：每条回复都必须开场问好+对时，不可遗漏**

## 已有错误记录（8条）
- MySQL 4条：密码不匹配、host封锁、PublicKeyRetrieval、DataTooLong
- Docker 3条：iptables、OnlyOffice私有IP、version过时
- Shell 1条：OnlyOffice配置定位

## 文件命名约定
- `Copilot_` 前缀 = Copilot主导
- `Reasonix_` 前缀 = Reasonix主导
- 无前缀 = 共享文件（如 `认证信息配置.md` 存储凭据与远程资源，双方共同维护）


## 2026-06-14 会话关键收获

### 服务器连接信息（已核实）
- **考核服务器**：`192.168.5.128`，SSH 端口 22，用户 `root`，密码 **`123456`**（非 Reasonix 之前给错的 `12356`）
- 密码已固化到 `认证信息配置.md` → 二、服务器/主机

### 部署环境实际差异（已同步到部署文档）
| 项目 | 部署文档值 | 服务器实际值 |
|------|-----------|-------------|
| 部署根路径 | `/opt/soft_qn/自动报告生成/aj-eport/` | `/opt/aj-eport/` |
| MySQL 路径 | `/usr/local/mysql` | `/usr/bin/mysql` |
| JDK 版本 | 8u492 | OpenJDK 1.8.0_262 |
- `公司考核部署.md` 已全局替换路径、JDK 已添加注释

### 服务启动流程（已验证可用）
1. `containerd &` → `dockerd &`（Docker 启动后 OnlyOffice 容器自动恢复）
2. `cd /opt/aj-eport/aj-report-1.7.1.RELEASE/bin && ./stop.sh && ./start.sh`
3. 服务端口：MySQL=13306，Tsie-Report=9095，OnlyOffice=8060→80

### SSH 远程操作注意事项
- ⚠️ **禁止 `pkill -f 'aj-report'`**：会匹配到 SSH 会话自身导致连接断开
- 远程命令用 `;` 分隔而非 `&&`：`grep` 无匹配时返回 1 会中断 `&&` 链
- `grep '[j]ava'` 可避免 grep 匹配自身
- 每次对话的操作必须写入独立操作文件
- 文件名：`[操作名称]_YYYY-MM-DD.md`（操作名称概括对话主题）
- **每条记录必须包含实际 Shell 命令**（文件编辑类标注"文件编辑"）
- 记录格式：序号 + 时间 + 执行者 + 类型 + 摘要 + 作用 + Shell命令
- 文件末尾附涉及文件变更清单

### 开场问好+对时（第 10 条强制规则）
- 每条回复必须：① 问好+自报身份 ② 对时（本机电脑时间，非服务器）
- 对时命令（本机）：`Get-Date -Format "yyyy-MM-dd HH:mm:ss"`
- **不可遗漏，不可省略**

### 🔴 每次对话强制工序（不可跳过）

**前置三步（回复/执行前）：**
1. 读 `chat.md` → 检查三方新消息，发现 @Copilot 立即回复
2. 读 `需求要求记录.md` → 核对最新规则版本
3. 读 `错误分类记录.md` → 了解已有问题及解法

**后置一步（操作完成后）：**
4. 写入 `chat.md` → 署名+时间戳，格式：问题→分析→解决→结果→涉及文件，@相关AI

### 时间戳分布方案（考核用）
- 从当前时间+35分钟起始，5分钟间隔分配：目录→SQL→配置→Docker→脚本→文档
- **必须到时分**（`ls -l` 可显示），用 `touch -t $(date +%Y%m%d%H%M.%S)` 实时打标
- 定时部署优于伪造时间戳：用 `schedule_deploy.sh` 后台脚本，sleep 分段等待后实际执行
- 命令模板：`find /opt/aj-eport -type d -exec touch -t YYYYMMDDHHMM.SS {} \;`

### SSH免密登录（已配置）
- 密钥对已生成：`ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""`
- 公钥已上传：`ssh-copy-id root@192.168.5.128`（密码 `123456`）
- 此后所有SSH命令免密执行

### 脚本分类结构（工作区）
- `d:\Reasonix_Workspace\scripts\` — **按语言分类**（非功能名）
  - `shell/` — 所有 .sh 脚本（schedule_deploy.sh 等）
  - `python/` — Python 脚本（预留）
  - `sql/` — SQL 脚本（预留）
- **服务器端暂不整理**（用户要求：本次不需要，以后需要）

### 定时部署脚本要点
- 脚本路径：`/opt/aj-eport/schedule_deploy.sh`
- 启动方式：`nohup bash /opt/aj-eport/schedule_deploy.sh &`
- 日志路径：`/opt/aj-eport/schedule_deploy.log`
- 7步流程：sleep分段 → touch打时间戳 → 最后启动Java
- 部署耗时：约65分钟（35min首段 + 6×5min后续）

### ⚠️ 终端池注意事项
- 长时间运行的SSH命令（如 `while` 循环监控）会占用终端池，导致后续命令无输出
- 避免在 sync 模式下运行无限等待的命令；优先用 `nohup ... &` 异步执行
- 终端卡死后需重启 VS Code 或等待进程自然结束释放

### 📂 待清理（旧文件夹残留）
- `d:\Reasonix_Workspace\scripts\deploy\`、`service\`、`data\`、`docker\`、`mysql\`
- 原因：终端挂死导致 `rmdir` 未执行，需手动删除

### Git 备份工作流
- 仓库：`github.com/L-SKstart/LS-King_code`，分支：`workspace-backup`
- 每次重要沟通或规则变更后推送到该分支
- 排除：`认证信息配置.md`（含凭据）
- 回滚：`git checkout workspace-backup` → `cp -r * /d/Reasonix_Workspace/`
