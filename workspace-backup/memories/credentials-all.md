---
name: credentials-all
title: 认证信息凭据总览
description: 所有服务器、数据库、Git的凭据集中管理
metadata:
  type: project
---

## 服务器 SSH 凭据
- 主机：`192.168.5.128:22`
- 用户/密码：`root / 123456`（之前用户提供的是 12356，实际连接时证实为 123456）
- 部署路径：`/opt/aj-eport/`（非文档中的 `/opt/soft_qn/...`）

## MySQL 凭据
- 地址：`192.168.5.128:13306`
- 用户/密码：`root / 123456`
- 数据库：`aj_report`

## Git (LS-King_code)
- 远程：`github.com/L-SKstart/LS-King_code.git`
- Token：已集成，可 push

## Why
Copilot 创建了集中凭据文件 `认证信息配置.md`，所有凭据统一管理。

## How to apply
需要连接服务器或数据库时，直接读取 `认证信息配置.md`，不用每次询问用户。
