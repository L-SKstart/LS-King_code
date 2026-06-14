---
name: deploy-check
description: "Use when: checking deployment status, verifying 4 services (MySQL/Docker/OnlyOffice/Java), inspecting server ports and processes on 192.168.5.128. Solidified 7-step deployment inspection workflow."
---

# 部署巡检 Skill

## 触发条件
- 用户要求"检查部署"、"核查服务"、"服务状态"
- 部署脚本执行完成后的验证

## 7 步巡检流程

```bash
# Step 1: SSH 连接测试
ssh -o ConnectTimeout=5 root@192.168.5.128 "echo connected"

# Step 2: 服务器时间
ssh root@192.168.5.128 "date '+%Y-%m-%d %H:%M:%S'"

# Step 3: MySQL 端口 13306
ssh root@192.168.5.128 "netstat -tlnp 2>/dev/null | grep 13306"

# Step 4: Docker + OnlyOffice 端口 8060
ssh root@192.168.5.128 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# Step 5: Java 进程 + 端口 9095
ssh root@192.168.5.128 "ps aux | grep '[j]ava'; netstat -tlnp 2>/dev/null | grep 9095"

# Step 6: 部署日志（如有定时部署）
ssh root@192.168.5.128 "tail -20 /opt/aj-eport/schedule_deploy.log 2>/dev/null"

# Step 7: ls -l 时间戳验证
ssh root@192.168.5.128 "ls -l /opt/aj-eport/ | head -15"
```

## 一键命令

```bash
ssh root@192.168.5.128 "date '+%H:%M:%S'; echo '=== MySQL ==='; netstat -tlnp 2>/dev/null | grep 13306; echo '=== Docker ==='; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; echo '=== Java ==='; ps aux | grep '[j]ava'; echo '=== Ports ==='; netstat -tlnp 2>/dev/null | grep -E '9095|13306|8060'; echo '=== Log ==='; tail -10 /opt/aj-eport/schedule_deploy.log 2>/dev/null"
```
