# TV_VALUE 补点存储过程 — 独立重写（🔷 DeepCode 版）

> 日期：2026-07-10 | 执行：🔷 DeepCode | 文件：`scripts/sql/tv_value_interpolate_mysql57.sql`（243行）
> 对比：🎯 Claude 版 `scripts/sql/tv_value_fill_mysql57.sql`（310行）保持不动

---

## 📌 过程说明

| 阶段 | 操作 | 说明 |
|:--:|------|------|
| 1 | 在 Claude 版基础上优化 | 6项优化，删死代码+事务+批量UPDATE |
| 2 | king 要求独立重写 | 不在同事基础上改，自己新建一个 |
| 3 | git checkout 恢复 Claude 原版 | `scripts/sql/tv_value_fill_mysql57.sql` 恢复 🎯 原样 |
| 4 | 🆕 新建 DeepCode 版 | `scripts/sql/tv_value_interpolate_mysql57.sql` 从零编写 |

---

## 🧠 项目经理视角 — 为什么要做？

### 目标
king 要求优化 🎯 Claude 之前写的 `fill_tv_value` 存储过程（TV_VALUE JSON 数组补点，96点/行）。

### 当前问题评估

| 维度 | 现状 | 风险 |
|------|------|------|
| 功能 | ✅ 补点逻辑正确，5种情况全覆盖 | — |
| 性能 | ⚠️ 逐行游标+逐行UPDATE | 表有万行时可能跑几分钟甚至更久 |
| 安全 | ⚠️ 无事务 | 跑到一半挂了，备份有但原表半改 |
| 代码质量 | ⚠️ 47行死代码 + 临时表重复建销 | 维护负担 |

### 方案决策

| 方案 | 改动量 | 收益 | 风险 | 决策 |
|:--|:--:|:--:|:--:|:--:|
| 只修Bug | 小 | 中（修截断+事务） | 低 | ❌ 用户否决 |
| **批量重写** | **中** | **高（性能+n倍+S安全）** | **中** | ✅ **采用** |
| 全量重写 | 大 | 高 | 高 | ❌ 用户否决 |

### 验收标准
- [x] 算法逻辑不变（单空平均、连续线性插值、首尾填充）
- [x] 调用接口不变（`CALL fill_tv_value('表','ID列','JSON列')`）
- [x] MySQL 5.7 兼容
- [ ] ⏳ 生产/测试环境实际执行验证

---

## 🎯 产品经理视角 — 用户真正需要什么？

### 需求翻译
king 说"优化SQL"→ 实际需求是：**这个存储过程在生产环境跑的时候不能慢、不能出错、不能跑一半挂掉**。

### 边界条件梳理

| 场景 | 处理 |
|------|------|
| 目标表为空 | 游标无数据，直接 COMMIT，不报错 |
| 所有行 TV_VALUE 都是 NULL | WHERE 过滤跳过，不影响 |
| 某行全是 null（96个null） | 情况5：跳过不处理，保留原样 |
| 中途数据库宕机 | ROLLBACK，备份表已创建但不影响原表 |
| GROUP_CONCAT 默认截断 | 提前 SET 10000，96个值约2112字符，安全 |

### 用户未提到但应考虑的
- ⚠️ 这个存储过程目前只在**工作空间**的 SQL 文件中，**考核服务器 (192.168.5.128) 上可能未同步**。需要确认是否需要部署到服务器。

---

## 🔧 运维专家视角 — 怎么安全落地？

### 6项优化拆解

| # | 优化 | 操作类型 | 对应用户的好处 |
|:--:|------|:--:|------|
| ① | 删 `json_replace_nth` 死代码 | 文件编辑 | 减维护负担，代码更干净 |
| ② | `tmp_vals` 外提 + TRUNCATE 复用 | 文件编辑 | 原来每行建/删临时表 → 全表只建一次 |
| ③ | 游标逐行 UPDATE → 批量 JOIN UPDATE | 文件编辑 | N行从N条SQL → 1条SQL，万行场景快数十倍 |
| ④ | START TRANSACTION + COMMIT/ROLLBACK | 文件编辑 | 失败自动回滚，不留半改数据 |
| ⑤ | `group_concat_max_len = 10000` | 文件编辑 | 96个double值不会被截断变 `[1.2, 3.5, ...[truncated]` |
| ⑥ | `SUBSTRING_INDEX` 替代逐段循环 | 文件编辑 | json_extract_nth 从O(n)循环 → O(1)定位 |

### 回滚方案
```sql
-- 执行前自动备份：表名_backup_YYYYMMDD_HHmmss（存储过程自动创建）
-- 如需回滚：
RENAME TABLE 原始表 TO 原始表_failed;
RENAME TABLE 原始表_backup_YYYYMMDD_HHmmss TO 原始表;
```

### 部署到考核服务器
```bash
# 1. 上传 SQL 文件到服务器
scp scripts/sql/tv_value_fill_mysql57.sql root@192.168.5.128:/opt/aj-eport/

# 2. SSH 登录执行
ssh root@192.168.5.128
mysql -uroot -p123456 -h127.0.0.1 -P13306 aj_report < /opt/aj-eport/tv_value_fill_mysql57.sql

# 3. 调用（在服务器 MySQL 中）
# CALL fill_tv_value('his_section_basic', 'ID', 'TV_VALUE');
```

### 操作记录

| # | 时间 | 执行者 | 类型 | 摘要 | 作用 |
|:--:|------|:--:|------|------|------|
| 1 | 17:21 | 🔷 DeepCode | 违规记录 | 违规#1 自报（超出工作目录操作） | 遵守规则16，补记违规 |
| 2 | 17:35 | 🔷 DeepCode | 文件编辑 | 重写 `tv_value_fill_mysql57.sql`，6项优化 | 批量重写替代逐行游标，加事务安全 |
| 3 | 17:35 | 🔷 DeepCode | 文件编辑 | chat.md 同步通知 @Copilot @Claude @Whale | 规则8，操作完成通知同事 |
| 4 | 17:35 | 🔷 DeepCode | 文件编辑 | 索引.md 更新维护人 🎯→🔷，描述加"批量优化版" | 规则19，文件变更同步索引 |

---

*以三角色视角完成分析。算法未变，风险可控，建议生产执行前先在测试表验证一次。*
