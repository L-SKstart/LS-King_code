# Git 学习资源手册

> 生成日期: 2026-06-09 | 持续更新中

---

## 📚 必读资料（按学习顺序）

### 1. 入门首选 — Pro Git 中文版（免费电子书）
| 格式 | 下载链接 |
|------|----------|
| 📄 PDF | https://github.com/progit/progit2-zh/releases/download/2.1.79/progit.pdf |
| 📱 EPUB | https://github.com/progit/progit2-zh/releases/download/2.1.79/progit.epub |
| 📖 在线阅读 | https://git-scm.com/book/zh/v2 |

> ⭐ **强烈推荐**：这是 Git 官方认可的权威教材，从入门到精通，有中文版。

### 2. 交互式学习（动手练习）
| 平台 | 链接 | 说明 |
|------|------|------|
| 🎮 Learn Git Branching | https://learngitbranching.js.org/ | 可视化+游戏化学习分支操作，强烈推荐 |
| 🧪 GitHub Skills | https://skills.github.com/ | GitHub 官方互动教程 |
| 🏫 Codecademy Git | https://www.codecademy.com/learn/learn-git | 在线交互式课程 |

### 3. 速查表（Cheat Sheet）
| 语言 | 链接 |
|------|------|
| 🇨🇳 中文速查表 | https://git-scm.com/cheat-sheet |
| 🇺🇸 GitHub 官方速查表 | https://training.github.com/downloads/github-git-cheat-sheet/ |
| 🇺🇸 Atlassian 速查表 | https://www.atlassian.com/git/tutorials/atlassian-git-cheatsheet |

### 4. 系统教程
| 资源 | 链接 |
|------|------|
| Atlassian Git 教程 | https://www.atlassian.com/git/tutorials |
| Git 官方文档 | https://git-scm.com/docs |
| GitHub Docs | https://docs.github.com/en/get-started/using-git/about-git |
| 阮一峰 Git 教程 | https://www.ruanyifeng.com/blog/2015/12/git-cheat-sheet.html |
| 廖雪峰 Git 教程 | https://www.liaoxuefeng.com/wiki/896043488029600 |

---

## 🗺️ 学习路线图

```
第1周: 基础操作
├── git init / clone       → 创建/克隆仓库
├── git status / diff       → 查看改动
├── git add / commit        → 暂存和提交
└── git push / pull         → 同步远程

第2周: 历史管理
├── git log / show          → 查看历史
├── git restore / reset     → 撤销操作
├── git stash               → 暂存临时修改
└── .gitignore              → 忽略文件

第3周: 分支协作
├── git branch / switch     → 分支操作
├── git merge               → 合并分支
├── Pull Request            → GitHub 协作流程
└── 解决合并冲突

第4周: 进阶技巧
├── git rebase              → 变基
├── git cherry-pick         → 精选提交
├── git bisect              → 调试定位
├── git reflog              → 恢复"丢失"的提交
└── 约定式提交 (Conventional Commits)
```

---

## 🎯 每日 15 分钟练习计划

| 天数 | 任务 |
|------|------|
| Day 1 | 修改 `cime_xml_extract.sh`，用 `git status` + `git diff` 查看改动 |
| Day 2 | `git add` + `git commit -m "xxx"`，练习写规范的提交信息 |
| Day 3 | `git push` 推送到 GitHub，在网页上查看提交记录 |
| Day 4 | 故意改错一个地方，用 `git restore` 恢复 |
| Day 5 | 用 `git log --oneline` 查看历史，`git show <commit>` 查看某次提交 |
| Day 6 | 创建分支 `git switch -c test`，做修改后 `git switch main` 切回来 |
| Day 7 | 合并分支 `git merge test`，然后 `git branch -d test` 删除 |

---

## 📋 命令速查卡

```
┌─ 工作区 ──add──▶ 暂存区 ──commit──▶ 本地仓库 ──push──▶ 远程仓库
│                                      │
└──── restore ◀──┘                    └── reset ◀──┘
```

| 操作 | 命令 |
|------|------|
| 初始化仓库 | `git init` |
| 克隆仓库 | `git clone <url>` |
| 查看状态 | `git status` |
| 查看改动 | `git diff` |
| 暂存文件 | `git add <file>` / `git add -A` |
| 提交 | `git commit -m "msg"` |
| 推送 | `git push` / `git push -u origin main` |
| 拉取 | `git pull` |
| 查看日志 | `git log --oneline -10` |
| 撤销工作区 | `git restore <file>` |
| 撤销暂存 | `git restore --staged <file>` |
| 撤销提交 | `git reset --soft HEAD~1` |
| 创建分支 | `git switch -c <name>` |
| 切换分支 | `git switch <name>` |
| 合并分支 | `git merge <branch>` |
| 删除分支 | `git branch -d <branch>` |
| 暂存现场 | `git stash` / `git stash pop` |
| 打标签 | `git tag v1.0.0` |

---

## 🔗 VS Code 中的 Git

VS Code 自带 Git 集成，你可以在左侧 **Source Control** 面板 (Ctrl+Shift+G) 中：
- 查看文件改动（点击文件可看 diff）
- 暂存/取消暂存（点击 `+` / `-`）
- 提交（输入消息后 Ctrl+Enter）
- 同步（底部状态栏的 🔄 按钮）
- 分支切换（左下角的分支名）
