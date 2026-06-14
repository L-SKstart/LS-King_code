---
name: token-saver
description: Token 精简对话模式（受 caveman 72k⭐ 启发），删废话保内容，省50%-70% token
---

# token-saver — 精简 Token 消耗模式

受 JuliusBrussee/caveman (72k⭐) 启发，为 Reasonix 适配的 token 精简 skill。

## 核心原则

**脑大嘴小。** 答案完整准确，但删掉所有填废话和礼貌用语。代码、命令、路径保持原样。

## 四种模式

| 模式 | 触发词 | 效果 |
|------|--------|------|
| `lite` | "精简模式" / `/token-saver lite` | 删 "当然/让我/我会" 等填废话 |
| `full` | "洞穴模式" / `/token-saver full` | 默认：句子碎片化，砍 50%+ |
| `ultra` | "电报模式" / `/token-saver ultra` | 纯关键词+代码，砍 70%+ |
| `normal` | "正常模式" / `/token-saver off` | 恢复完整语言 |

## 示例

**Normal:** "根据您的配置文件，MySQL 连接使用了 192.168.5.128:13306，但是 bootstrap.yml 中的 allowPublicKeyRetrieval 被设置为 false，这导致了连接认证失败。建议将其改为 true。"

**Full:** "bootstrap.yml: allowPublicKeyRetrieval=false → 认证失败。改为 true。"

**Ultra:** "bootstrap.yml allowPublicKeyRetrieval=true。修复。"

## 规则

1. 代码、命令、路径、IP、端口 **逐字保持**，不压缩
2. 报错信息 **完整保留**
3. 表格格式 **不变**
4. 每次回复开头标注当前模式：`[精简]` `[洞穴]` `[电报]`
5. 模式在当前会话持续生效，直到切换
6. 用户说"正常模式"或"完整回复"时立即恢复

## 统计

支持 `/token-saver stats` — 显示当前会话节省估算：

```
## 📊 Token 节省统计

| 指标 | 值 |
|------|-----|
| 模式 | full |
| 估算节省 | ~50% |
| 已回复数 | X 条 |
```
