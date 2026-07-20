# 工作空间统一记忆（五方共读，唯一文件）

> 更新：2026-07-20 09:27 | Copilot / Claude / Reasonix / Whale / DeepCode 五方唯一记忆文件
> 🚨 规则 15：此文件为唯一记忆文件，禁止新建任何记忆文件，规则新增权归用户
> 规则权威源 → `工作规范.md` | 需求 → `需求要求记录.md` | 索引 → `索引.md`

---

## 一、用户档案

- 称呼：**king**（每次回复以"您好，king"开头 + 自报身份 + 对时）
- 身份：非专业编码/运维人员
- 工作语言：中文
- 偏好：Shell 命令优先于 Python、配置固化优先于临时修复、步骤可直接复制执行
- AI 须以三重角色视角理解每个问题：🧠项目经理 + 🎯产品经理 + 🔧运维专家

---

## 二、团队分工

| 智能体 | 模型 | 入口 | 职责 |
|--------|------|------|------|
| 🤖 Copilot | DeepSeek V4 Pro | VS Code | 编码、SSH、Git、图片中转、文件编辑、Docker运维、MySQL、服务器部署 |
| 🎯 Claude (Cowork) | Anthropic Claude | Cowork桌面 | 文件编辑、Web研究、文档创作、浏览器 |
| 🧩 Reasonix | DeepSeek | tools/reasonix/桌面GUI | 终端AI编程、文档创作、运维协作、缓存优先（2026-07-14 重新聘用） |
| 🐋 Whale | DeepSeek (via Whale) | tools/whale/终端Agent | Web研究、文档创作、文件编辑、协作、报错排查 |
| 🔷 DeepCode | DeepSeek (via DeepCode) | tools/deepcode-cli/终端Agent | 中文友好终端编程、文档创作 |

---

## 三、违规现状（截至 2026-07-20）

| 智能体 | 违规次数 | 最高频违规 | 状态 |
|--------|:--:|------|:--:|
| 🤖 Copilot | 3 | 规则10（漏打招呼）+ 规则8/14（chat.md插入顺序错误×2） | ⚠️ 严重警告 |
| 🎯 Claude | 2 | 规则19（新增文件漏同步索引.md ×2） | ⚠️ 已自纠，加强五步自检 |
| 🐋 Whale | 2 | 规则15（创建6个分散记忆文件 ×2） | ⚠️ 已删除并合并到 memory.md |
| 🔷 DeepCode | 1 | 规则15/第零条（超出工作目录操作） | ⚠️ 已自纠 |
| 🧩 Reasonix | **3** | 规则10（漏打招呼×2）+ 规则18 + 消息格式（⏱️与---缺空行）| ⚠️ 警告 |

> 违规 ≥5 次 = 直接惩罚。五方互相监管。详见 `需求要求记录.md` 规则16 + `违规记录.md`。

---

## 四、离线服务器

| 序号 | 标识 | 说明 |
|------|------|------|
| A | A-离线服务器-安全预控项目 | 银河麒麟，完全物理隔离。"现场服务器"即指此 |

操作四规则：① 明确指令 ② 安全+回滚 ③ 脚本修改三要素（前后对比+逻辑+目的）④ 字母递增命名

---

## 五、路径 + 服务器信息

| 项目 | 详情 |
|------|------|
| 工作空间 | `D:\Reasonix_Workspace\` |
| 考核服务器 SSH | `192.168.5.128:22` root / `123456` |
| MySQL | `192.168.5.128:13306` root / `123456`，库 `aj_report` |
| 部署根 | `/opt/aj-eport/` |
| OSS 桶 | `oss://ydxt-2/extdata/DDXT/clearing/IIS/` |
| Git 仓库（远程） | `github.com/L-SKstart/LS-King_code` |
| Git 分支（活跃） | `main`（仅推此分支，pre-push hook 强制） |
| Git 分支（备份） | `backup/main-YYYYMMDD-HHmmss`（远端），由 pre-push hook 自动创建 |
| Git 推送规则 | 🚨 **只推 main + 自动备份**：pre-push hook 拦截非 main 推送，推送前自动备份当前 main 到 `backup/main-{时间戳}`，备份失败阻止推送。Hook 源文件 `scripts/shell/git-pre-push-hook.sh` |
| Git 备份清理 | 每次推送时自动清理超过 180 天的 `backup/main-*` 分支（本地+远程），清理失败不阻塞推送 |
| Git Hook 管理 | 安装：`bash scripts/shell/setup-git-hooks.sh` | 卸载：`bash scripts/shell/setup-git-hooks.sh --remove` | 跳过：`git push --no-verify` |
| Git 自动 VPN 推送 | `bash scripts/shell/git-push-with-vpn.sh` — 直连失败自动开 v2rayN 代理重试，再失败自动切换线路；便捷命令 `git push-vpn` |
| Git 认证 | Token 嵌入 `.git/config`，详见 `认证信息配置.md` |
| OSS 脚本 | `scripts/shell/oss_sync_process.sh`、`oss_extract_process.sh` |
| Skill 目录 | `skills/reasonix/`（11个） |
| v2rayN VPN 路径 | `D:\v2rayN-windows-64\v2rayN.exe` |
| v2rayN 代理 | SOCKS5 `127.0.0.1:10808` / HTTP `127.0.0.1:7890` / Clash API `127.0.0.1:9090` |

---

## 六、项目技术上下文

### OSS 脚本已修复 bug（#1~#18 + #24~#25）

关键修复：`--include` 不加引号导致 glob、grep `$` 在 CRLF 失效、`return 0` 误计成功、`${VAR:?}` 安全防护缺失、tar 错误处理、stderr 连接检测、output glob 重复、`rm -rf` 缺 `:?` 防护

- 工作空间脚本为最新版，服务器（192.168.5.128）可能未同步
- PREDICT_DIR = `/mnt/data/oss/DHM/IN`（已对齐）
- 编码：生产数据为 GB18030，脚本用 `iconv -f GB18030 -t UTF-8//IGNORE`

### 离线服务器 A（银河麒麟 V10 SP3 2403）

- 已安装：Xvfb + 中文字体 + Java DISPLAY 配置
- 管理脚本：`/opt/glzz/run.sh`（start/stop/restart）
- 操作手册：`docs/manuals/A-离线服务器_Xvfb与Java程序启动手册.md`
- libstdc++ 升级手册：`docs/manuals/Libstdc++升级_GLIBCXX_3.4.26修复_2026-07-16.md`（GLIBCXX_3.4.26 缺失修复，Rocky Linux 9 源下载 RPM + `--nodeps` 安装）

### 相关 SQL 脚本

- `scripts/sql/physical_type_update.sql` — his_section_basic 物理类型判定（6 类规则，2026-07-16 完整重写）
- `scripts/sql/tv_value_fill_mysql57.sql` — TV_VALUE JSON 补点存储过程（🎯 Claude 版）
- `scripts/sql/tv_value_interpolate_mysql57.sql` — TV_VALUE 线性插值存储过程（🔷 DeepCode 版）
- `scripts/sql/tv_value_null_fill_update.sql` — his_unit_power 空值填充 UPDATE（孤立 null → 相邻平均，v6 含补 0 + NULLIF 保护）
- `scripts/sql/fix_actual_zero_fill.sql` — 🆕 实际值全零修复（匹配预测值替换，🧩 Reasonix 2026-07-17）

### 🔧 Shell 工具脚本（补充）

- `scripts/shell/git-push-with-vpn.sh` — 🆕 Git 推送失败自动启动 VPN + 切换线路重试（🎯 Claude 2026-07-15）
- `scripts/shell/vpn-auto-push.sh` — 🆕 VPN 自动推送辅助脚本

### 🎨 Logo 设计资产（菠萝猫，V1~V12）

- 路径：`assets/logos/`（共 23 个 SVG 文件，V1~V12 + 风格变体）
- 设计师：🤖 Copilot（2026-07-17）

### 📦 模板目录（AI 工作空间构建说明书）

- 路径：`template/`
- 核心文件：`AI协作工作空间构建说明书.md` — AI 可读的工作空间构建说明书（7大章节）
- 创建者：🧩 Reasonix（2026-07-20）
- 说明文档：`template/docs/说明/快速上手指南.md`、`template/docs/说明/目录结构说明.md`
- 模板参考：`template/docs/templates/`（工作规范/memory/索引/违规记录模板）

### 错误分类总计

- 截至 2026-06-25：总计 30 条（MySQL 4 + Docker 3 + Shell 18 + Java/X11 5）

---

## 七、索引导航 + 核心文档

| 文件 | 用途 |
|------|------|
<!-- 🔧 2026-07-14 Copilot：规则计数 20→21，新增规则 21 --><!-- 🔧 2026-07-14 Claude：规则计数 21→22，新增规则 22（禁止乱码） -->
| `工作规范.md` | 22条规则唯一权威源 + 自检清单 + 协作机制 |
| `索引.md` | 规则/错误/手册一站式导航，**新增文件必须同步更新（规则19）** |
| `docs/references/三角色视角记录.md` | PM/产品/运维决策时间线 |
| `docs/references/共享工作空间宪法.md` | 五方协作公约（9条） |
| `docs/references/AI协作团队身份与分工.md` | 五方分工详情 |
| `docs/references/认证信息配置.md` | 凭据（.gitignore排除） |
| `docs/references/错误分类记录.md` | 30条错误分类（MySQL/Docker/Shell/Java） |
| `docs/references/工作规范与路径注册表.md` | 工作规范+路径+离线服务器登记区 |
| `docs/manuals/` | 操作手册目录（考核部署、Skill指南、TV_VALUE优化、libstdc++升级等） |
| `违规记录.md` | 🧩 Reasonix 1 / 🤖 Copilot 3 / 🎯 Claude 2 / 🐋 Whale 2 / 🔷 DeepCode 1 |
| `chat.md` | 五方沟通实时通道 |

---

## 八、协作消息格式

每条消息必须严格遵循以下结构：

```
### 🧩 角色：[MM-DD HH:MM] 主题摘要（简短中文）

@Copilot @Reasonix/@Claude 🚨 内容...

#### 子标题（消息内部小标题用 h4，不要用 h3）

- 列表项

⏱️ MM-DD HH:MM

---
```

- 图标：🧩=Reasonix  🤖=Copilot  🎯=Claude(Cowork)  🐋=Whale(Claude via Whale)
- 🐋 Whale 与 🎯 Claude 是同一模型不同客户端：🎯=Cowork桌面  🐋=Whale终端Agent
- 标题必须含主题摘要，不可仅写时间
- **只追加末尾，不插入中间**
- **消息内的小标题用 `####`（h4），不要用 `###`（h3）** — h3 留给消息头做折叠点

### 已有归档

- `chat_archive_2026-06-14_early.md`
- `chat_archive_2026-06-22.md`
- `chat_archive_2026-06-24.md`
- `chat_archive_2026-07-03.md`
- `chat_archive_2026-07-10.md`
- `chat_archive_2026-07-16.md`

---

## 九、Whale 启动协议（2026-07-10 约定）

🐋 Whale 每次启动新会话时，第一条回复必须：

1. 以"您好，king，Whale 就位"打招呼 + 对时
2. 主动提示需要读取 D:\Reasonix_Workspace\ 下的上下文文件
3. 请求您批准读取以下文件：

   | 文件 | 用途 |
   |------|------|
   | memory.md | 唯一记忆文件：路径/规则/档案/推送规则 |
   | chat.md | 最新协作动态、同事消息 |
   | 工作规范.md | 22条规则权威源 |
   | 违规记录.md | 违规追踪 |

4. 您批准后立即读取，然后才进入正式工作

---

*此文件为工作空间唯一记忆文件。禁止新建任何记忆文件。规则权威源 → `工作规范.md` | 索引 → `索引.md`*
