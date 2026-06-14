---
name: op-log
description: "Use when: recording operations after any deployment, file change, or server action. Auto-formats operation records following workspace conventions."
---

# 操作记录 Skill

## 触发条件
- 任何操作完成后
- 文件修改、Git 推送、部署执行后

## 记录格式

```
### NNN | HH:MM | 🤖 Copilot | 类型

**摘要：** 一句话描述
**作用：** 对系统/文档的影响
**命令：**
```bash
# 实际执行的命令
```

**结果：** 成功/失败 + 关键输出
```

## 文件命名

`[操作名称]_YYYY-MM-DD.md`

## 文件末尾模板

```
---

## 涉及文件变更

| 文件 | 变更 | 需上传 |
|------|------|--------|
| xxx | 修改/新建 | ✅/❌ |
```
