---
name: diagnose
description: "Use when: troubleshooting deployment errors, diagnosing service failures, analyzing error logs on 192.168.5.128. One-click diagnosis workflow."
---

# 错误诊断 Skill

## 触发条件
- 用户贴错误日志
- 服务启动失败
- 端口不通

## 诊断流程（6 步）

1. **识别关键错误行** → 从日志中提取 ERROR/FATAL/Exception
2. **提取关键信息** → 文件:行号 / IP:端口 / 表名.字段
3. **读取相关配置文件** → `conf/bootstrap.yml`、`docker-compose.yml`
4. **分析根因给出方案** → 一句话根因 + 解决步骤
5. **告知"已修改需重新上传"** → 列出文件清单
6. **记录到错误分类文档** → `错误分类记录.md`

## 错误分类

| 类型 | 常见问题 |
|------|----------|
| MySQL | 密码不匹配、host封锁、PublicKeyRetrieval、DataTooLong |
| Docker | iptables、OnlyOffice私有IP、version过时 |
| Shell | 配置定位、命令语法 |
| Java | 端口占用、内存不足、Jar缺失 |

## 报错输出格式

```
**报错：** 具体错误信息
**位置：** 文件:行号 / IP:端口 / 表名.字段
**原因：** 一句话根因
**解决：** ① 命令 ② 修改文件 ③ 验证方法
```
