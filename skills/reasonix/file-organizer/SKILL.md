---
name: file-organizer
description: 按规则整理文件：分类、去重、清理、生成目录结构。
---
# file-organizer

整理指定目录下的文件。

## 支持的操作

### classify（分类）
按扩展名归类到子目录：
```
images/   → .jpg .png .gif .svg .webp
docs/     → .pdf .doc .docx .xls .xlsx .ppt .pptx .txt .md
archives/ → .zip .rar .7z .tar .gz
code/     → .py .js .ts .go .rs .java .html .css .json .yaml
media/    → .mp4 .mp3 .avi .mov .wav
其他      → others/
```

### deduplicate（去重）
- 对比文件名+大小，标记疑似重复
- 不自动删除，只列出建议

### tree（目录树）
- 生成可读的目录结构，标注文件数量和总大小

### clean-empty（清理空目录）
- 递归查找空目录，列出后询问是否删除

## 规则
- 所有破坏性操作先展示计划，经确认后执行
- 不操作隐藏文件和系统目录

## 用法指南

**一句话：** 整理指定目录文件：按扩展名分类、查找重复、生成目录树、清理空目录。

**调用方式：** `/file-organizer <操作> <目录路径>`

**示例：**
```
/file-organizer classify D:\下载\杂乱文件夹    → 按类型归类到子目录
/file-organizer deduplicate D:\照片           → 查找疑似重复文件（不自动删除）
/file-organizer tree D:\Reasonix_Workspace    → 生成目录结构+文件统计
/file-organizer clean-empty D:\项目           → 找出空目录，确认后删除
```

**输入：** 目录路径 + 操作类型（classify/deduplicate/tree/clean-empty）  
**输出：** 操作计划预览（先展示后执行），破坏性操作需二次确认。不操作隐藏文件和系统目录。
