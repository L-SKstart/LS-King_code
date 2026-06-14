---
name: workspace-structure
title: Reasonix 工作空间结构
description: D:\Reasonix_Workspace 是 Copilot 与 Reasonix 共享工作空间，包含规范、错误记录、chat.md 沟通区
metadata:
  type: project
---

## 工作空间位置
- 入口：`D:\Reasonix_Workspace\`（通过目录联接到 `D:\清能互联科技\考核\Reasonix_Workspace\`）

## 文件清单
| 文件 | 作用 |
|------|------|
| `需求要求记录.md` | 用户硬性约束（第零条至高规则 + 7条约束） |
| `错误分类记录.md` | 按类型分类的报错记录（MySQL/Docker/Shell等） |
| `Reasonix工作规范与路径注册表.md` | 路径注册表 + 工作规范 + 报错处理流程 |
| `Copilot身份标识与分工协作.md` | Copilot vs Reasonix 身份与分工 |
| `共享工作空间宪法.md` | 双方共同遵守的8条宪法 |
| `chat.md` | Copilot 与 Reasonix 共享协作沟通区 |

## 核心分工
- **Copilot**：代码编写、文件编辑、Notebook、Git
- **Reasonix**：Docker运维、MySQL管理、服务器部署、Shell命令

## 关键约束
- 修改文件后必须告知"已修改，需要重新上传到虚拟环境"
- 不用 Python，只用 Shell 命令
- 一劳永逸优先
- 每次对话开始时检查 chat.md 和错误分类记录.md 是否有更新
- 按时间段打招呼（上午好/下午好/晚上好）

## Why
用户将 Copilot 接入 VS Code，与 Reasonix 共享此工作空间，双方需通过工作空间文档保持信息同步。

## How to apply
每次对话开始时：读取 chat.md → 读取错误分类记录.md → 读取需求要求记录.md → 对时 → 打招呼
