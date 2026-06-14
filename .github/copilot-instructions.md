# Copilot 工作空间指令

> 适用：`d:\Reasonix_Workspace\` 全部工作  
> 本文件为 VS Code agent instructions，每次交互自动加载

---

## 🚨 最高规则

**未经用户明确授权，不得偏离工作规范中的任何一条规则。**

---

## 🔴 每次对话强制工序

### 前置三步（回复/执行前，不可跳过）
1. 读 `chat.md` → 检查三方（Copilot/Reasonix/Claude）新消息，发现 @Copilot 立即回复
2. 读 `需求要求记录.md` → 核对最新规则版本
3. 读 `错误分类记录.md` → 了解已有问题及解法

### 后置一步（操作完成后）
4. 写入 `chat.md` → 署名 `🤖 Copilot：[MM-DD HH:MM]` + 时间戳，格式：问题→分析→解决→结果→涉及文件，@相关AI

---

## 12 条核心约束（源：`需求要求记录.md`）

1. 修改文件后告知"需重新上传到虚拟环境"，列文件清单
2. 不用 Python（运维场景；代码开发可用）
3. 一劳永逸优先：配置文件固化 > 临时命令
4. 排查步骤完整清晰：现象→根因→步骤→验证
5. 错误按类型分类：MySQL/Docker/Shell/Java
6. 问题必记录到 `错误分类记录.md`
7. 主动检查 `chat.md` 更新，发现即回复
8. 做了操作必须 @所有人 告知，不可悄悄执行
9. 新增内容必须通知 `chat.md`
10. 开场问好+自报身份+对时（本机电脑时间）
11. 图片中转：Reasonix不读图 → Copilot读后写chat.md@Reasonix
12. 防冗余：规则源唯一、chat.md超500行归档、操作记录按月合并

---

## 三方角色分工

| AI | 职责 | 入口 |
|----|------|------|
| 🤖 Copilot | 编码、文件编辑、Notebook、Git、VS Code、SSH终端 | VS Code |
| 🧩 Reasonix | Docker运维、MySQL、服务器部署、Shell修复（❌不读图） | 独立终端 |
| 🎯 Claude | 文件编辑、Web研究、文档创作、浏览器 | Cowork桌面 |

---

## 关键路径

| 项目 | 路径 |
|------|------|
| 考核服务器 | `192.168.5.128` / root / `123456` |
| SSH | 免密已配 (`~/.ssh/id_rsa`) |
| 部署根 | `/opt/aj-eport/` |
| Git仓库 | `github.com/L-SKstart/LS-King_code` |
| 备份分支 | `workspace-backup`（日常推此，不直推main） |

---

## 对时命令

```powershell
Get-Date -Format "yyyy-MM-dd HH:mm:ss"
```
