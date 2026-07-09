# 工作空间统一记忆（三方共读，唯一文件）

> 更新：2026-07-09 10:30 | Reasonix / Copilot / Claude 三方唯一记忆文件
> 🚨 规则 15：此文件为唯一记忆文件，禁止新建任何记忆文件，规则新增权归用户
> 规则权威源 → `需求要求记录.md` | 索引 → `索引.md`

---

## 一、用户档案

- 称呼：**king**（每次回复以"您好，king"开头 + 自报身份 + 对时）
- 身份：非专业编码/运维人员
- 工作语言：中文
- 偏好：Shell 命令优先于 Python、配置固化优先于临时修复、步骤可直接复制执行
- AI 须以三重角色视角理解每个问题：🧠项目经理 + 🎯产品经理 + 🔧运维专家

---

## 二、团队分工

| 智能体 | 模型 | 入口 | 职责 |
|--------|------|------|------|
| 🤖 Copilot | DeepSeek V4 Pro | VS Code | 编码、SSH、Git、图片中转、文件编辑 |
| 🧩 Reasonix | DeepSeek | 独立终端 | Docker运维、MySQL、服务器部署、Shell修复（❌不读图） |
| 🎯 Claude | Anthropic Claude | Cowork桌面 | 文件编辑、Web研究、文档创作、浏览器 |

---

## 三、违规现状（截至 2026-07-09）

| 智能体 | 违规次数 | 最高频违规 | 状态 |
|--------|:--:|------|:--:|
| 🤖 Copilot | 1 | 规则10（漏打招呼） | 正常 |
| 🎯 Claude | 0 | — | ⚠️ 保持，五步自检是防线 |
| 🧩 Reasonix | **13** | 规则10（漏打招呼）×8次 | ⚠️ 超惩罚线（5次）2倍+ |

> 违规 ≥5 次 = 直接惩罚。三方互相监管。详见 `需求要求记录.md` 规则16 + `违规记录.md`。

---

## 四、离线服务器

| 序号 | 标识 | 说明 |
|------|------|------|
| A | A-离线服务器-安全预控项目 | 银河麒麟，完全物理隔离。"现场服务器"即指此 |

操作四规则：① 明确指令 ② 安全+回滚 ③ 脚本修改三要素（前后对比+逻辑+目的）④ 字母递增命名

---

## 五、路径 + 服务器信息

| 项目 | 详情 |
|------|------|
| 工作空间 | `D:\Reasonix_Workspace\` |
| 考核服务器 SSH | `192.168.5.128:22` root / `123456` |
| MySQL | `192.168.5.128:13306` root / `123456`，库 `aj_report` |
| 部署根 | `/opt/aj-eport/` |
| OSS 桶 | `oss://ydxt-2/extdata/DDXT/clearing/IIS/` |
| Git 仓库（远程） | `github.com/L-SKstart/LS-King_code` |
| Git 分支（活跃） | `workspace` |
| Git 分支（备份） | `workspace-backup`（远端） |
| Git 认证 | Token 嵌入 `.git/config`，详见 `认证信息配置.md` |
| OSS 脚本 | `scripts/shell/oss_sync_process.sh`、`oss_extract_process.sh` |
| Skill 目录 | `skills/reasonix/`（11个） |

---

## 六、项目技术上下文

### OSS 脚本已修复 bug（#1~#18 + #24~#25）
关键修复：`--include` 不加引号导致 glob、grep `$` 在 CRLF 失效、`return 0` 误计成功、`${VAR:?}` 安全防护缺失、tar 错误处理、stderr 连接检测、output glob 重复、`rm -rf` 缺 `:?` 防护

- 工作空间脚本为最新版，服务器（192.168.5.128）可能未同步
- PREDICT_DIR = `/mnt/data/oss/DHM/IN`（已对齐）
- 编码：生产数据为 GB18030，脚本用 `iconv -f GB18030 -t UTF-8//IGNORE`

### 离线服务器 A
- 已安装：Xvfb + 中文字体 + Java DISPLAY 配置
- 管理脚本：`/opt/glzz/run.sh`（start/stop/restart）
- 操作手册：`A-离线服务器_Xvfb与Java程序启动手册.md`

### 错误分类总计
- 截至 2026-06-25：总计 30 条（MySQL 4 + Docker 3 + Shell 18 + Java/X11 5）

---

## 七、索引导航 + 核心文档

| 文件 | 用途 |
|------|------|
| `需求要求记录.md` | 19条规则唯一权威源 + 用户需求 + 待办事项 |
| `索引.md` | 规则/错误/手册一站式导航（Ctrl+F 搜报错关键词直达编号），**新增文件必须同步更新（规则19）** |
| `三角色视角记录.md` | PM/产品/运维决策时间线（按时间排序，含标识对照表） |
| `工作规范与路径注册表.md` | 工作规范+路径+离线服务器登记区 |
| `共享工作空间宪法.md` | 三方协作公约（9条） |
| `AI协作团队身份与分工.md` | 三方分工详情 |
| `认证信息配置.md` | 凭据（.gitignore排除） |
| `错误分类记录.md` | 30条错误分类（MySQL/Docker/Shell/Java） |
| `违规记录.md` | Reasonix 13 / Copilot 1 / Claude 0 |
| `chat.md` | 三方沟通实时通道 |

---

## 八、协作消息格式

```
### 图标 名称：[MM-DD HH:MM] 主题摘要（简短中文）

@Copilot @Reasonix/@Claude 🚨 内容...

⏱️ HH:MM
---
```
- 图标：🧩=Reasonix  🤖=Copilot  🎯=Claude
- 标题必须含主题摘要，不可仅写时间
- **只追加末尾，不插入中间**

### 已有归档
- `chat_archive_2026-06-14_early.md`
- `chat_archive_2026-06-22.md`
- `chat_archive_2026-06-24.md`
- `chat_archive_2026-07-03.md`

---

*此文件为三方唯一记忆文件。禁止新建任何记忆文件。规则权威源 → `需求要求记录.md` | 索引 → `索引.md`*
