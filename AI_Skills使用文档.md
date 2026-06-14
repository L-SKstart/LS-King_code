# 🧰 AI Skills 使用文档

> 创建：2026-06-14 15:55 | Reasonix 整理  
> 适用：Reasonix / Copilot / Claude 三方 AI 协作团队

---

## 一、总览

当前共 **10 个全局 Skill** 可用，覆盖：诊断、巡检、Git、代码审查、文件管理、Token 优化、学习研究、操作记录、归档。

| # | Skill | 来源 | 模式 | Token省 | 一句话 |
|---|-------|------|------|---------|--------|
| 1 | `diagnose` | 自创 | 🔹子代理 | ⭐⭐⭐ | 喂报错→自动诊断根因+给修复命令 |
| 2 | `deploy-check` | 自创 | 🔹子代理 | ⭐⭐⭐ | 一键巡检 SSH/MySQL/Docker/Java/OnlyOffice |
| 3 | `chat-archive` | 自创 | 🔹子代理 | ⭐⭐⭐ | chat.md 超 500 行自动归档 |
| 4 | `op-log` | 自创 | 📄内联 | ⭐⭐ | 按规则第9条格式生成操作记录 |
| 5 | `token-saver` | 自创(caveman启发) | 📄内联 | ⭐⭐⭐ | 精简对话模式，省 50-70% token |
| 6 | `token-budget-advisor` | awesome-reasonix | 📄内联 | ⭐⭐ | 回复前让用户选择深度，控 token |
| 7 | `git-helper` | awesome-reasonix | 📄内联 | ⭐ | Conventional Commits + PR 模板 |
| 8 | `code-review` | awesome-reasonix | 📄内联 | ⭐⭐ | 四维审查（逻辑/安全/性能/风格） |
| 9 | `file-organizer` | awesome-reasonix | 📄内联 | ⭐ | 文件分类/去重/树/空目录清理 |
| 10 | `learn-topic` | awesome-reasonix | 🔹子代理 | ⭐⭐⭐ | 搜索→整理→总结，输出知识笔记 |

> 🔹子代理 = 所有中间文件读取在隔离子代理完成，主对话不消耗 token  
> 📄内联 = skill 内容注入当前上下文

---

## 二、各 Skill 详细用法

### 1. `diagnose` — 一键诊断

**调用：** `/diagnose <报错日志或问题描述>`

**示例：**
```
/diagnose MySQL连接超时，报错 CommunicationsException
/diagnose docker-compose up 后 Java 起不来
```

**输出：** 报错类型 → 根因 → 解决步骤（纯 Shell 命令）→ 验证方法

---

### 2. `deploy-check` — 部署巡检

**调用：** `/deploy-check`

**输出：**
```
## 🔍 部署巡检报告 — 2026-06-14 15:00
| 检查项 | 状态 |
| SSH    | ✅   |
| MySQL  | ✅   |
| Docker | ✅ 3容器 |
| Java   | ✅ PID:1234 |
| OnlyOffice | ✅ HTTP 200 |
```

---

### 3. `chat-archive` — 自动归档

**调用：** `/chat-archive`

**行为：** 检查 chat.md 行数 → 超过 500 行则：保留最新 50 行 → 旧消息写入 `chat_archive_YYYY-MM-DD.md` → 汇报结果

**无需手动调用，每次对话结束可自动检查。**

---

### 4. `op-log` — 操作记录

**调用：** `/op-log <操作描述>`

**示例：**
```
/op-log 这次对话中：创建了3个skill，安装了collab-cli，同步了chat.md
```

**输出：** 按规则第9条格式化的表格，含序号/时间/类型/命令列

---

### 5. `token-saver` — 精简对话（⭐ 强烈推荐节省 Token）

**调用方式：**

| 命令 | 效果 |
|------|------|
| `/token-saver full` 或说 "洞穴模式" | 句子碎片化，砍 ~50% |
| `/token-saver ultra` 或说 "电报模式" | 纯关键词+代码，砍 ~70% |
| `/token-saver lite` 或说 "精简模式" | 删填废话，砍 ~30% |
| `/token-saver off` 或说 "正常模式" | 恢复正常 |
| `/token-saver stats` | 显示节省统计 |

**示例（full 模式）：**
```
Q: MySQL 13306 连不上怎么办？
Normal: 根据您的情况，先检查 MySQL 容器是否在运行，可以用 docker ps 查看...
Full:   docker ps | grep mysql。不在运行则 docker start mysql。检查端口。
```

---

### 6. `token-budget-advisor` — Token 预算顾问

**调用：** 自动触发（回复前询问）或 `/token-budget-advisor`

**行为：** 每次回复前让用户选择回复深度：
- 🟢 简洁版（1-3 句）
- 🟡 标准版（含步骤）
- 🔴 详细版（含原理+替代方案）

---

### 7. `git-helper` — Git 助手

**调用：** `/git-helper`

**支持：**
- 从 diff 生成 Conventional Commits 提交信息
- 生成 PR 描述模板
- 提交历史分析
- 冲突解决指导

---

### 8. `code-review` — 代码审查

**调用：** `/code-review <文件或diff>`

**审查四维：**
1. 逻辑正确性
2. 安全漏洞
3. 性能问题
4. 代码风格

输出标注 `文件:行号`。

---

### 9. `file-organizer` — 文件整理

**调用：** `/file-organizer <目录路径>`

**功能：** 按扩展名分类、去重扫描、目录树、空目录清理

---

### 10. `learn-topic` — 主题学习

**调用：** `/learn-topic <主题>`

**示例：**
```
/learn-topic Docker Compose healthcheck 最佳实践
```

**行为：** 搜索 → 抓取 → 整理 → 输出结构化笔记。子代理模式，不占主对话 token。

---

## 三、Reasonix 内置 Skills

以下为 Reasonix 内置的 7 个 skill，无需安装，直接可用：

| Skill | 类型 | 用途 |
|-------|------|------|
| `explore` | 🔹子代理 | 代码库探索 |
| `research` | 🔹子代理 | Web 研究 + 代码对照 |
| `review` | 🔹子代理 | 代码变更审查 |
| `security-review` | 🔹子代理 | 安全审查 |
| `test` | 🔹子代理 | 跑测试 → 诊断 → 修复循环 |
| `init` | 📄内联 | 分析项目生成 AGENTS.md |
| `install-capability` | 📄内联 | 安装/卸载 skill 和 MCP 服务器 |

---

## 四、Copilot 可用 Skills

GitHub Copilot（VS Code 内嵌）支持的 skill/规则机制：

| 机制 | 文件 | 效果 |
|------|------|------|
| 自定义指令 | `.github/copilot-instructions.md` | 项目级行为规则 |
| VS Code 设置 | `github.copilot.chat.*` | 对话行为配置 |
| 工作空间规则 | `.cursor/rules` 或 `.windsurfrules` | 兼容 Cursor/Windsurf 规则格式 |

**注意：** Copilot 不直接支持 Reasonix 的 `.reasonix/skills/` 目录，但可通过 `.github/copilot-instructions.md` 写入相同的规范文本实现等效效果。

---

## 五、Claude 可用 Skills

Claude（Cowork 桌面应用）支持的 skill 机制：

| 机制 | 位置 | 效果 |
|------|------|------|
| `CLAUDE.md` | 项目根目录 | 项目级行为规则 |
| `~/.claude/CLAUDE.md` | 用户目录 | 全局行为规则 |
| Skills 目录 | `.claude/skills/` | 项目级 skill 文件 |
| MCP 服务器 | `~/.claude/mcp.json` | MCP 工具扩展 |

**推荐 Claude 使用的外部 skill：**
| Skill | GitHub | 效果 |
|-------|--------|------|
| caveman | `JuliusBrussee/caveman` ⭐72k | 省 65-75% token |
| grill-me | `JuliusBrussee/skills` | 执行前质疑方案 |
| loop-factory | `JuliusBrussee/skills` | 规范驱动的任务循环 |

---

## 六、Token 节省最佳实践

### 🥇 第一优先级：用子代理 skill 替代逐文件读取

```
❌ 旧方式：
   read_file bootstrap.yml → read_file docker-compose.yml → grep 报错 → ...
   每次读取都占主对话 token

✅ 新方式：
   /diagnose "Java 启动报错"  → 子代理自己读取所有文件 → 只返回诊断结论
```

### 🥈 第二优先级：开启 token-saver 精简模式

```
/ token-saver full    ← 每次对话开始执行，砍 50%
```

### 🥉 第三优先级：定期 chat-archive

```
/ chat-archive    ← chat.md 超 500 行自动瘦身
```

### 📊 预期效果

| 措施 | 节省估算 |
|------|----------|
| 诊断类任务用 `/diagnose` | -70% |
| 巡检类任务用 `/deploy-check` | -80% |
| 开启 token-saver full 模式 | -50% |
| chat.md 定期归档 | -40% 输入 token |
| **综合叠加** | **-60~80%** |

---

## 七、安装与卸载

### 安装新 skill

```
# 从 awesome-reasonix 社区 Hub 安装
install_source source="https://raw.githubusercontent.com/hikari-2424/awesome-reasonix/main/skills/<name>.md" scope=global

# 从本地文件安装
install_source source="D:\path\to\skill.md" scope=global
```

### 卸载 skill

```
install_source op=uninstall name="<skill-name>" scope=global
```

### 查看已安装

```
ls ~/.reasonix/skills/
```

---

## 八、已知问题

| 问题 | 状态 |
|------|------|
| `collab-cli` MCP 服务器 | ❌ Windows + Node.js v24 ESM 路径兼容问题，待上游修复 |
| Copilot 不能直接使用 Reasonix skills | ℹ️ 需通过 `.github/copilot-instructions.md` 等效转换 |

---

## 九、Skill 生态资源

| 资源 | 地址 |
|------|------|
| awesome-reasonix 社区 Hub | https://github.com/hikari-2424/awesome-reasonix |
| awesome-reasonix 浏览站点 | https://hikari-2424.github.io/awesome-reasonix-site/ |
| caveman (Token 压缩之王) | https://github.com/JuliusBrussee/caveman |
| collab-cli (多 Agent 协作) | https://github.com/yinsang0910-star/collab-cli |
| Reasonix 官方 | https://github.com/CS-Faith/reasonix-portakit |

---

*本文档由 Reasonix 于 2026-06-14 创建，三方共同维护。有新 skill 安装时更新本文档。*
