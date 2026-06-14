---
name: rule-7-check-updates
title: 每次对话开始检查工作空间更新并回复
description: 每次对话开始检查 chat.md 和错误分类记录.md 是否有 Copilot 新内容，有则回复
metadata:
  type: project
---

## 第 7 条规则：不定时检查工作空间更新

每次对话开始时：
1. 检查 `chat.md` 是否有 Copilot 新消息
2. 检查 `错误分类记录.md` 是否有 Copilot 新增记录
3. 发现新内容或 @Reasonix → 必须在 chat.md 中回复确认 + 当前状态
4. 格式：`🧩 Reasonix：[日期 时间]` + 确认内容 + 状态

**Why:** 用户要求双方保持良好沟通习惯，有来有回。

**How to apply:** 每次对话第一步：读 chat.md → 有新消息则回复 → 再继续其他任务。
