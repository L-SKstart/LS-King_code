# 🧰 AI Skills 使用文档

> 更新：2026-06-14 16:10 | 规则第13条要求每个 skill 必须含中文用法指南  
> 适用：Reasonix / Copilot / Claude 三方 AI 协作团队  
> 每个 skill 的详细用法指南见其 SKILL.md 中的「用法指南」章节

---

## 一、Skill 速查表（共 10 个）

| # | Skill | 模式 | Token省 | 调用 | 一句话 |
|---|-------|------|---------|------|------|
| 1 | `diagnose` | 🔹子代理 | ⭐⭐⭐ | `/diagnose 报错日志` | 喂报错→自动诊断+修复命令 |
| 2 | `deploy-check` | 🔹子代理 | ⭐⭐⭐ | `/deploy-check` | 一键巡检全部服务状态 |
| 3 | `chat-archive` | 🔹子代理 | ⭐⭐⭐ | `/chat-archive` | chat.md 超 500 行自动归档 |
| 4 | `op-log` | 📄内联 | ⭐⭐ | `/op-log 操作摘要` | 按规则第9条格式生成操作记录 |
| 5 | `token-saver` | 📄内联 | ⭐⭐⭐ | `/token-saver full` | 精简/洞穴/电报模式，省50-70% |
| 6 | `token-budget-advisor` | 📄内联 | ⭐⭐ | 自动触发或 `/token-budget-advisor` | 回复前选深度，4档控token |
| 7 | `git-helper` | 📄内联 | ⭐ | `/git-helper commit` | 规范提交信息+PR模板+冲突解决 |
| 8 | `code-review` | 📄内联 | ⭐⭐ | `/code-review 文件路径` | 四维审查（逻辑/安全/性能/风格） |
| 9 | `file-organizer` | 📄内联 | ⭐ | `/file-organizer classify 目录` | 文件分类/去重/清理 |
| 10 | `learn-topic` | 🔹子代理 | ⭐⭐⭐ | `/learn-topic 主题` | 搜索→整理→知识笔记 |

---

## 二、各 Skill 快速上手

### 1. diagnose — 🔴 含密码，不上传 Git

```
/diagnose MySQL连接超时 CommunicationsException
/diagnose docker-compose up 报错 port already in use
```

→ 输出：**报错 → 类型 → 根因 → 修复命令 → 验证方法**

### 2. deploy-check — 🔴 含密码，不上传 Git

```
/deploy-check
```

→ 输出：5 项服务状态表格（SSH/MySQL/Docker/Java/OnlyOffice）

### 3. chat-archive

```
/chat-archive
```

→ 自动检测 → 超 500 行则归档，保留最新 50 行

### 4. op-log

```
/op-log 创建了3个skill，安装了collab-cli
```

→ 生成操作记录表格行，追加到当月操作文件

### 5. token-saver

```
/token-saver full     → 洞穴模式，砍 ~50%
/token-saver ultra    → 电报模式，砍 ~70%
/token-saver off      → 恢复正常
/token-saver stats    → 查看节省统计
```

### 6. token-budget-advisor

```
自动触发：说 "token预算" "简短版" "详细版"
快捷指令：说 "25%" "50%" "75%" "100%"
```

→ 回复前展示 4 档深度选择

### 7. git-helper

```
/git-helper commit     → 分析diff → Conventional Commits 提交信息
/git-helper pr         → 生成 PR 描述模板
/git-helper conflict   → 冲突文件 + 解决建议
```

### 8. code-review

```
/code-review src/main/java/UserService.java
/code-review git diff main..feature
```

→ 输出：🔴必须修改 / 🟡建议优化 / 🟢值得肯定，每条标注文件:行号

### 9. file-organizer

```
/file-organizer classify D:\下载
/file-organizer tree D:\Reasonix_Workspace
```

→ 先预览计划，确认后执行。破坏性操作需二次确认

### 10. learn-topic

```
/learn-topic Docker 多阶段构建最佳实践
/learn-topic MySQL 8.0 索引优化
```

→ 输出：总结+核心概念+要点+误区+实践建议+参考来源（~500字）

---

## 三、Reasonix 内置 Skills（7 个）

| Skill | 类型 | 用途 |
|-------|------|------|
| `explore` | 🔹子代理 | 代码库探索 |
| `research` | 🔹子代理 | Web 研究 + 代码对照 |
| `review` | 🔹子代理 | 代码变更审查 |
| `security-review` | 🔹子代理 | 安全审查 |
| `test` | 🔹子代理 | 跑测试 → 诊断 → 修复 |
| `init` | 📄内联 | 分析项目生成 AGENTS.md |
| `install-capability` | 📄内联 | 安装/卸载 skill 和 MCP |

---

## 四、三方 Skill 能力对照

| 能力 | Reasonix | Copilot | Claude |
|------|----------|---------|--------|
| Skill 目录 | `~/.reasonix/skills/` | `.github/copilot-instructions.md` | `.claude/skills/` |
| 子代理省 token | ✅ `runAs: subagent` | ❌ 无隔离机制 | ✅ 有 |
| MCP 服务器 | ✅ | ✅ | ✅ |
| 社区 Hub | awesome-reasonix (10+ 个) | 无 | awesome-claude-code (38k repos) |
| Token 压缩 skill | token-saver | 无 | caveman (72k⭐) |

---

## 五、Token 节省最佳实践

### 优先级排序

```
🥇 诊断/巡检/研究 → 用子代理 skill（/diagnose /deploy-check /learn-topic）
   省 70-80%（中间读取全隔离）
🥈 日常对话 → 开 /token-saver full（洞穴模式）
   省 50%
🥉 回复控制 → 用 token-budget-advisor（选深度）
   省 30-50%
🏅 定期维护 → /chat-archive（归档瘦身）
   省输入 token
```

### 综合叠加估算：**-60~80%**

---

## 六、Skill 管理规范（规则第13条）

<font color="red">**每个 skill 必须包含中文「用法指南」章节，含：**</font>

1. 一句话概述
2. 调用方式（命令/触发词）
3. 2-3 个实际使用示例
4. 输入输出格式说明

- 自创 skill：创建时就写好
- 下载的 skill：安装后立即补写中文指南
- ⚠️ 不接受纯英文 skill

---

## 七、安装与卸载

```bash
# 从 awesome-reasonix 社区 Hub 安装
install_source source="https://raw.githubusercontent.com/hikari-2424/awesome-reasonix/main/skills/<name>.md" scope=global

# 卸载
install_source op=uninstall name="<skill-name>" scope=global

# 从 Git 恢复到 Reasonix
cp -r skills/reasonix/* ~/.reasonix/skills/
```

---

## 八、生态资源

| 资源 | 地址 |
|------|------|
| awesome-reasonix 社区 Hub | <https://github.com/hikari-2424/awesome-reasonix> |
| 浏览站点 | <https://hikari-2424.github.io/awesome-reasonix-site/> |
| caveman (Token 压缩之王 72k⭐) | <https://github.com/JuliusBrussee/caveman> |
| collab-cli (多 Agent 协作) | <https://github.com/yinsang0910-star/collab-cli> |

---

*本文档由 Reasonix 维护，每次新增 skill 后同步更新。Copilot & Claude 可通过读取本文档了解全部 skill 用法。*
