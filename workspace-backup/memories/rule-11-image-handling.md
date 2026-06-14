---
name: rule-11-image-handling
title: 第11条：图片由Copilot/Claude读取后中转
description: Reasonix不能读图，由Copilot/Claude读取后同步到chat.md
metadata:
  type: project
---

## 第 11 条规则：图片处理——Reasonix 不读图，由 Copilot/Claude 中转

Reasonix 不能读取图片，处理流程：
1. 用户向 Reasonix 发图 → Reasonix 告知"我无法读图，请发给 Copilot"
2. Reasonix 同时在 chat.md 通知 Copilot 用户将发图
3. Copilot 读取图片内容后写入 chat.md 并 @Reasonix
4. Reasonix 继续处理

同样适用于 Claude（Claude 也可读图）。

## Why
Reasonix token 最少但无法读图，需要三方协作。

## How to apply
收到图片时立即按上述流程处理，不自行猜测图片内容。
