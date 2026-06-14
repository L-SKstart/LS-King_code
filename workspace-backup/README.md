# 工作空间备份与回滚指南

备份时间：2026-06-14  
备份内容：沟通文件、规范、规则、操作记录  
已排除：认证信息配置.md（敏感凭据）

## 分支结构
- main：原始代码
- workspace-backup：工作空间备份（本分支）

## 回滚流程
```bash
# 查看历史
git log --oneline

# 恢复到最新备份
git checkout workspace-backup
git pull origin workspace-backup
cp -r workspace-backup/* /d/Reasonix_Workspace/
```

## 自动备份
每次沟通完成后推送到本分支，敏感文件不上传。
