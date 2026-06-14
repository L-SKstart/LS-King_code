# 工作空间速查

> 更新：2026-06-14 16:56 | 单文件替代 MEMORY.md / MEMORY_CORE.md / MEMORY_RULES.md

---

## 团队

| 智能体 | 入口 | 职责 |
|--------|------|------|
| 🤖 Copilot | VS Code | 编码、SSH、Git |
| 🧩 Reasonix | 外部对话 | Docker/MySQL/运维 |
| 🎯 Claude | Cowork | 文件编辑/Web研究 |

---

## 规则 14 条（源：`需求要求记录.md`）

| # | 核心 |
|---|------|
| 第零条 | 回复前读核心文件（同会话不变不反复读） |
| 1 | 改文件告知"需重新上传" |
| 2 | 不用Python（运维用Shell） |
| 3 | 一劳永逸：配置固化>临时命令 |
| 4 | 排查：现象→根因→步骤→验证 |
| 5 | 错误按类型分类记录 |
| 6 | 问题必记`错误分类记录.md` |
| 7 | 检查chat.md，@即回复 |
| 8 | 操作后@所有人+主题摘要+按时间追加 |
| 9 | 操作记录按需（仅代码/报错/服务器） |
| 10 | 开场问好+对时 |
| 11 | 图片中转：Reasonix不读图→Copilot |
| 12 | 防冗余：chat.md>500建议归档 |
| 13 | Skill须含中文用法指南 |
| 14 | 读到必回+chat.md>1000强制归档 |

---

## 路径

| 项目 | 路径 |
|------|------|
| 工作空间 | `D:\Reasonix_Workspace\` |
| Tsie-Report | `D:\清能互联科技\考核\自动报告生成\aj-eport\aj-report-1.7.1.RELEASE\` |
| Git仓库 | `D:\Reasonix_Workspace\`（分支`workspace`） |
| Skill | `skills/reasonix/`（11个） |

---

## 凭据（详见`认证信息配置.md`）

- 服务器：`192.168.5.128:22` root/123456
- MySQL：`:13306` root/123456 库`aj_report`
- GitHub：`L-SKstart/LS-King_code`

---

## 11 个 Skill

| Skill | 一句话 |
|-------|--------|
| context-optimizer | 自动体检上下文防膨胀 |
| diagnose | 诊断部署报错（含密码） |
| deploy-check | 巡检服务（含密码） |
| chat-archive | chat.md归档 |
| token-saver | Token精简50-70% |
| token-budget-advisor | 回复深度四档（默认开启） |
| git-helper | Git提交/PR |
| code-review | 代码审查 |
| file-organizer | 文件整理 |
| op-log | 操作记录 |
| learn-topic | 主题研究 |

---

## 会话启动流程

1. `date` 对时 → 问好
2. 读`chat.md`检查@消息 → 回复
3. 读`需求要求记录.md`核对规则
4. 读`错误分类记录.md`
5. 处理任务 → 操作后chat.md通知
