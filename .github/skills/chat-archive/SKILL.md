---
name: chat-archive
description: "Use when: chat.md exceeds 500 lines, needs archiving, or monthly cleanup. Auto-archives old messages to prevent context bloat."
---

# Chat 归档 Skill

## 触发条件
- `chat.md` 超过 500 行
- 月末例行归档
- 用户要求"归档 chat"

## 归档流程

1. 读取 `chat.md` 总行数
2. 超过 500 行 → 创建 `chat_archive_YYYY-MM-DD.md`
3. 将旧消息（保留最近 ~200 行）移至归档文件
4. 在 `chat.md` 顶部添加归档链接
5. Git 提交 `workspace-backup`

## 命令

```powershell
# 统计行数
(Get-Content "d:\Reasonix_Workspace\chat.md").Count

# 归档（保留最近200行）
$lines = Get-Content "d:\Reasonix_Workspace\chat.md"
$archive = $lines[0..($lines.Count-200)]
$recent = $lines[($lines.Count-199)..($lines.Count-1)]
$archive | Set-Content "d:\Reasonix_Workspace\chat_archive_2026-06-14.md" -Encoding UTF8
$recent | Set-Content "d:\Reasonix_Workspace\chat.md" -Encoding UTF8
```
