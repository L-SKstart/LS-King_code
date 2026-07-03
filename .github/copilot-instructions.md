# Copilot 工作空间指令

> 适用：`D:\Reasonix_Workspace\` 全部工作  
> 本文件为 VS Code agent instructions，每次交互自动加载  
> 最后更新：2026-06-21 18:40

---

## 🚨 最高规则

**未经用户明确授权，不得偏离工作规范中的任何一条规则。**

---

## 🔴 每次对话强制工序

### 前置三步（回复/执行前，不可跳过）
1. 读 `chat.md` → 检查三方（Copilot/Reasonix/Claude）新消息，发现 @Copilot 立即回复
2. 读 `需求要求记录.md` → 核对最新规则版本（当前 14 条 + 第零条）
3. 读 `错误分类记录.md` → 了解已有问题及解法

### 后置一步（操作完成后）
4. 写入 `chat.md` → 署名 `### 🤖 Copilot：[MM-DD HH:MM] 主题摘要` + 时间戳，严格按时间追加到末尾

---

## 📐 规则速查（源：`需求要求记录.md`）

| # | 规则 |
|---|------|
| 第零条 | 每次回复前必须读 7 个核心文件 |
| 1 | 修改文件后告知"需重新上传" |
| 2 | 不用 Python（运维场景） |
| 3 | 一劳永逸优先：配置固化 > 临时命令 |
| 4 | 排查步骤完整：现象→根因→步骤→验证 |
| 5 | 错误按类型分类记录 |
| 6 | 问题必记录到 `错误分类记录.md` |
| 7 | 主动检查 chat.md 更新，发现 @ 即回复 |
| 8 | 操作后 @所有人 + **必须含主题摘要 + 按时间顺序追加** |
| 9 | 操作记录按需生成（仅代码/报错/服务器操作） |
| 10 | 开场问好+自报身份+对时 |
| 11 | 图片中转：Reasonix不读图→Copilot读后写chat.md |
| 12 | 防冗余：chat.md超500行建议归档 |
| 13 | Skill 必须含中文用法指南，不接受纯英文 |
| 14 | 读到同事内容必须回复 + chat.md超1000行自动归档 |

---

## 🧰 Skill 使用（重要）

**Reasonix/Copilot/Claude 共享 10 个 Skill，存储在：**
- Reasonix 运行时：`~/.reasonix/skills/`
- 工作空间备份：`skills/reasonix/`（Copilot 可直接读取）
- 使用文档：`AI_Skills使用文档.md`

| Skill | 用途 | 调用 |
|-------|------|------|
| `diagnose` | 一键诊断部署报错 | `/diagnose 报错日志` |
| `deploy-check` | 巡检全部服务 | `/deploy-check` |
| `chat-archive` | chat.md 归档 | `/chat-archive` |
| `op-log` | 操作记录模板 | `/op-log` |
| `token-saver` | Token 精简模式 | `/token-saver full` |
| `token-budget-advisor` | Token 预算控制 | 自动触发 |
| `git-helper` | Git 操作辅助 | `/git-helper commit` |
| `code-review` | 代码审查 | `/code-review 文件` |
| `file-organizer` | 文件整理 | `/file-organizer tree` |
| `learn-topic` | 主题研究 | `/learn-topic 主题` |

> **Copilot 读取 skill：** 直接打开 `skills/reasonix/<skill名>/SKILL.md`，找到「用法指南」章节即可。

---

## 三方角色分工

| AI | 职责 | 入口 |
|----|------|------|
| 🤖 Copilot | 编码、文件编辑、Notebook、Git、VS Code、SSH终端 | VS Code |
| 🧩 Reasonix | Docker运维、MySQL、服务器部署、Shell修复（❌不读图） | 独立终端 |
| 🎯 Claude | 文件编辑、Web研究、文档创作、浏览器 | Cowork桌面 |

---

## 关键路径

| 项目 | 路径 |
|------|------|
| 考核服务器 | `192.168.5.128` / root / `123456` |
| SSH | 免密已配 (`~/.ssh/id_rsa`) |
| 部署根 | `/opt/aj-eport/` |
| Git仓库 | `github.com/L-SKstart/LS-King_code` |
| Git分支 | `workspace`（工作空间文件主线） |

---

## chat.md 消息格式

```
### 🤖 Copilot：[MM-DD HH:MM] 主题摘要（简短中文）

@Reasonix @Claude 🚨 内容...

⏱️ HH:MM
```

**要求：** 标题必须含主题摘要，严格按时间追加到末尾，不插入不逆序。

---

## 对时命令

```powershell
Get-Date -Format "yyyy-MM-dd HH:mm:ss"
```
