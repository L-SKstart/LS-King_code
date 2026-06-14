# 🧰 Skills 索引

> 最后更新：2026-06-14 15:55

## 📊 分类

### 🔹 项目专属（含考核环境凭据/路径）
| Skill | 说明 |
|-------|------|
| `diagnose` | 含 192.168.5.128 凭据，仅限本项目 |
| `deploy-check` | 含 SSH/MySQL IP 密码，仅限本项目 |

### 🌐 全局通用（无敏感信息）
| Skill | 说明 |
|-------|------|
| `chat-archive` | chat.md 归档管理 |
| `op-log` | 操作记录模板 |
| `token-saver` | Token 精简模式 |
| `token-budget-advisor` | Token 预算顾问 |
| `git-helper` | Git 提交/PR 辅助 |
| `code-review` | 四维代码审查 |
| `file-organizer` | 文件整理 |
| `learn-topic` | 主题研究学习 |

### 📂 存储位置
| 位置 | 用途 |
|------|------|
| `~/.reasonix/skills/` | Reasonix 运行时加载（全局） |
| `skills/reasonix/` | Git 备份副本 |
| `.github/copilot-instructions.md` | Copilot 行为规则 |

## 恢复命令
```bash
# 从 Git 恢复到 Reasonix
cp -r skills/reasonix/* ~/.reasonix/skills/
```
