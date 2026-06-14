# 🧰 Skill 操作指南 — 快速上手

> 创建：2026-06-14 | 适用：Reasonix / Copilot / Claude 三方用户

---

## 一、最简单的方式：跟 Reasonix 说话就行

你现在就在跟 Reasonix 对话。直接用下面的命令：

| 你想做什么 | 输入什么 |
|------------|----------|
| 排查报错 | `/diagnose` + 粘贴报错日志 |
| 检查服务器状态 | `/deploy-check` |
| 整理聊天记录 | `/chat-archive` |
| 分析一段代码 | `/code-review` + 粘贴代码 |
| 研究一个技术 | `/learn-topic Docker 怎么用` |
| 让 AI 说话简洁点 | `/token-saver full` |
| 恢复正常语气 | `/token-saver off` |

**示例：**
```
你：/diagnose MySQL 连不上了，报错 Connection refused

Reasonix：自动诊断 → 告诉你原因和修复命令
```

---

## 二、Copilot（VS Code 里的 AI）怎么用 Skill

Copilot 不能直接调 `/diagnose`，但可以**读取 skill 文件照着做**：

### 步骤：
1. 在 VS Code 里打开文件：`skills/reasonix/diagnose/SKILL.md`
2. 找到 `## 用法指南` 章节
3. 按里面的流程操作

### 常用 Skill 文件位置：

| Skill | VS Code 打开路径 |
|-------|-----------------|
| 诊断报错 | `skills/reasonix/diagnose/SKILL.md` |
| 巡检服务 | `skills/reasonix/deploy-check/SKILL.md` |
| 代码审查 | `skills/reasonix/code-review/SKILL.md` |
| Git 辅助 | `skills/reasonix/git-helper/SKILL.md` |
| Token 精简 | `skills/reasonix/token-saver/SKILL.md` |
| 全部列表 | `AI_Skills使用文档.md` |

---

## 三、Claude（Cowork 桌面应用）怎么用 Skill

同样，Claude 可以读取工作空间里的 skill 文件：

1. 告诉 Claude："读一下 `skills/reasonix/diagnose/SKILL.md`，按里面的流程帮我排查"
2. Claude 会按照 skill 的指导操作

---

## 四、Skill 完整清单（10 个）

| # | Skill | 一句话 | 谁用 |
|---|-------|--------|------|
| 1 | diagnose | 喂报错→自动诊断 | Reasonix 直接调 |
| 2 | deploy-check | 一键巡检服务器 | Reasonix 直接调 |
| 3 | chat-archive | 聊天记录归档 | Reasonix 直接调 |
| 4 | op-log | 操作记录模板 | Reasonix 直接调 |
| 5 | token-saver | 让 AI 说话简洁 | Reasonix 直接调 |
| 6 | token-budget-advisor | 控制回复长度 | 自动触发 |
| 7 | git-helper | Git 提交/PR 辅助 | 三方都可读 |
| 8 | code-review | 代码四维审查 | 三方都可读 |
| 9 | file-organizer | 文件分类整理 | 三方都可读 |
| 10 | learn-topic | 搜索学习主题 | Reasonix 直接调 |

---

## 五、常见问题

**Q: 我输入了 `/diagnose` 但没反应？**
A: 只有跟 Reasonix 对话时这些命令才生效。在 VS Code 里跟 Copilot 说话不行。

**Q: Copilot 怎么用 diagnose？**
A: 对 Copilot 说："读 skills/reasonix/diagnose/SKILL.md，按里面的方法帮我排查这个报错：[粘贴报错]"

**Q: 这些 Skill 在哪里？**
A: 两个地方：
- Reasonix 的：`C:\Users\52909\.reasonix\skills\`（你不用管）
- 工作空间备份：`D:\Reasonix_Workspace\skills\reasonix\`（Copilot/Claude 读这里）

**Q: 怎么安装新 Skill？**
A: 告诉 Reasonix："从 awesome-reasonix 安装 xxx skill"，我会自动下载+写中文指南。

---

*有问题随时问 Reasonix。*
