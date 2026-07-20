-- ============================================================
-- 🎯 三角色视角 — his_section_basic 物理类型判定 UPDATE
-- ============================================================
-- 创建：2026-07-10 | 🎯 Claude
-- 🔧 2026-07-16 L-SKstart：重写全部 6 类判定规则 + WHERE 仅处理 NULL 行
-- 用法：复制整条 UPDATE 语句到 SQL 客户端直接执行即可
-- ============================================================

-- ============================================================
-- 🏷️ PM 视角：问题定义 & 方案选择
-- ============================================================
--
-- 【问题】his_section_basic 表的 PHYSICAL_TYPE 字段需要根据
--   6 类规则自动判定填充。
--
-- 【物理类型编号与含义】
--   | 编号 | 类型 | 判定能力 |
--   |:--:|------|:--:|
--   | 1 | 常规断面 | ✅ 文本匹配（desc 为空无设备 → 常规；desc 含"正常方式/正常运行"） |
--   | 2 | 运行方式控制 | ✅ 文本匹配（remark/desc 含 12 个关键词；开关+站；空设备+有 desc+非正常） |
--   | 3 | 机组开停控制 | ⚠️ 代理匹配（desc/remark 含"机组"+(开停/启停)）— 完整规则需设备表 |
--   | 4 | 机组出力/线路潮流控制 | ⚠️ 代理匹配（desc/remark 含"出力/潮流"）— 完整规则需设备表 |
--   | 5 | 运行方式+条件控制断面 | ⚠️ 需同时满足类型2+类型3/4，需设备表确认 |
--   | 6 | 机组开停+机组出力/线路潮流控制断面 | ⚠️ 需设备表确认 |
--
-- 【方案对比】
--   | # | 方案 | 优点 | 缺点 | 采用 |
--   |---|------|------|------|:--:|
--   | 1 | 一条 UPDATE + CASE WHEN | 直接复制执行，零依赖 | 复杂规则难维护 | ✅ |
--   | 2 | 存储过程 | 可复用、可传参 | 需 DELIMITER + CALL | ❌ |
--   | 3 | 应用层代码更新 | 灵活、可单元测试 | 需拉数据到应用层再写回 | ❌ |

-- ============================================================
-- 🧩 产品视角：业务规则 & 边界条件
-- ============================================================
--
-- 【6 类判定规则】（优先级从高到低，命中即停止）
--
--   | 优先级 | 类型 | 判定条件 | 数据来源 |
--   |:--:|:--:|------|------|
--   | 1 | 类型2 | remark/desc 含关键词（投入/退出/功能/运行/上网/合环/分母/开#/断开/措施/断环/分列） | REMARK, CONDITION_DESC |
--   | 2 | 类型2 | desc/remark 同时含"开关"+"站"（代理：条件设备全是 Breaker + station 含"站"） | REMARK, CONDITION_DESC |
--   | 3 | 类型2 | 条件设备为空 且 desc 非空 且 desc 不是"正常方式/正常运行" | CONDITION_DEF, CONDITION_DESC |
--   | 1 | 类型6 | 同时满足类型3代理 + 类型4代理（机组关键词 + 出力/潮流关键词） | REMARK, CONDITION_DESC |
--   | 2 | 类型5 | 满足类型2(关键词/开关+站) 且 (类型3代理 或 类型4代理) | REMARK, CONDITION_DESC |
--   | 3 | 类型2 | remark/desc 含关键词（投入/退出/功能/运行/上网/合环/分母/开#/断开/措施/断环/分列） | REMARK, CONDITION_DESC |
--   | 4 | 类型2 | desc/remark 同时含"开关"+"站"（代理：条件设备全是 Breaker + station 含"站"） | REMARK, CONDITION_DESC |
--   | 5 | 类型2 | 条件设备为空 且 desc 非空 且 desc 不是"正常方式/正常运行" | CONDITION_DEF, CONDITION_DESC |
--   | 6 | 类型3 | desc/remark 含"机组"+(开停/启停)（代理：dev_type=GeneratorUnit + meas_type=Pos） | REMARK, CONDITION_DESC |
--   | 7 | 类型4 | desc/remark 含"出力"或"潮流"（代理：dev_type∈设备集 + meas_type=P） | REMARK, CONDITION_DESC |
--   | 8 | 类型1 | Measurement 为空 且 desc 为空（代理：CONDITION_DEF 为空 + desc 为空） | CONDITION_DEF, CONDITION_DESC |
--   | 9 | 类型1 | desc 含"正常方式"或"正常运行" | CONDITION_DESC |
--   | 10 | 类型1 | 兜底：desc 有内容但无特殊标记 → 常规断面 | CONDITION_DESC |
--   | 11 | 类型1 | desc 和 remark 均为空 → 常规断面保底（🔧 2026-07-16） | CONDITION_DESC, REMARK |
--
-- 【边界条件】
--   - NULL 值：仅 PHYSICAL_TYPE IS NULL 的行会被处理
--   - 已分类行：PHYSICAL_TYPE 已有值（1~6）的行不会被覆盖
--   - 中文匹配：使用 LIKE '%关键词%'，确保编码一致（UTF-8）
--   - 大小写：中文无大小写问题 ❌ 不适用
--   - 空字符串：字段为 '' 的空串不会匹配 LIKE
--
-- 【类型 5/6 说明】
--   类型5 = 满足类型2 且 (满足类型3 或 类型4)，当前若行同时命中类型2+类型3/4
--   的代理规则，则优先判为类型2（因类型2优先级更高，且设备数据不完整无法确认）。
--   类型5/6 的精确判定需 CONDITION_DEF 中的 XML 设备信息或独立的设备关联表。
--
-- 【类型 3/4 代理规则说明】
--   完整规则需解析 XML 中 Measurement 的 @dev_type 和 @meas_type 属性。
--   当前 CONDITION_DEF 存的是数学表达式（如 y1==0 && y2==0），不含设备信息。
--   因此用 REMARK/condition_desc 中的中文关键词做代理判定。
--   后续若 CONDITION_DEF 恢复为 XML 格式或接入设备表，可替换为精确匹配。

-- ============================================================
-- 🔧 运维视角：安全检查 & 执行步骤
-- ============================================================
--
-- 【执行前检查清单】⚠️ 逐项确认后才能执行
--
--   ☑ 1. 确认目标表存在且有数据：
--        SELECT COUNT(*) FROM his_section_basic;
--        → 预期：> 0
--
--   ☑ 2. 确认 PHYSICAL_TYPE 列存在：
--        DESC his_section_basic;
--        → 确认有 PHYSICAL_TYPE 列（应为 TINYINT/INT 类型）
--
--   ☑ 3. 确认各文本列存在且有数据：
--        SELECT COUNT(*) FROM his_section_basic WHERE condition_desc IS NOT NULL;
--        SELECT COUNT(*) FROM his_section_basic WHERE REMARK IS NOT NULL;
--        SELECT COUNT(*) FROM his_section_basic WHERE CONDITION_DEF IS NOT NULL;
--
--   ☑ 4. 预览影响范围（执行前必看！）：
--        → 执行下方"Step 1: 预览"的 SELECT 语句
--        → 确认分类结果符合预期后，再执行 UPDATE
--
--   ☑ 5. 备份表（安全第一）：
--        CREATE TABLE his_section_basic_backup_20260716 AS SELECT * FROM his_section_basic;
--
-- 【执行步骤】
--   Step 1: 执行预览 SELECT（看分类结果，不修改数据）
--   Step 2: 确认无误后执行备份
--   Step 3: 执行 UPDATE
--   Step 4: 执行验证 SELECT（确认结果）
--   Step 5: 确认无误后删除备份表
--
-- 【回滚方案】
--   -- 如果备份表还在：
--   UPDATE his_section_basic t
--   JOIN his_section_basic_backup_20260716 b ON t.ID = b.ID
--   SET t.PHYSICAL_TYPE = b.PHYSICAL_TYPE;
--   -- 或直接恢复整表：
--   TRUNCATE TABLE his_section_basic;
--   INSERT INTO his_section_basic SELECT * FROM his_section_basic_backup_20260716;
--
-- 【风险评级】
--   🟡 中风险：类型2新增12个关键词，类型3/4为代理匹配（可能误判）
--   🟢 低风险：可先用 SELECT 预览，有备份 + 回滚方案

-- ============================================================
-- 📐 Step 1: 预览 SELECT（先执行这个！看分类结果，不会修改数据）
-- ============================================================

SELECT
    ID,
    CONDITION_DEF,
    condition_desc,
    REMARK,
    PHYSICAL_TYPE AS `当前值`,
    CASE
        -- ============================================================
        -- 优先级0-1：类型 5/6 — 组合断面（需在单一类型之前检查）
        -- ============================================================

        -- 类型 6：机组开停+机组出力/线路潮流控制断面
        -- （代理：同时满足类型3代理 + 类型4代理）
        -- 完整规则：既有GeneratorUnit+Pos，又有线路/直流/机组类设备的P
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            AND (condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN 6

        -- 类型 5：运行方式+条件控制断面
        -- （代理：满足类型2关键词 + (类型3代理 或 类型4代理)）
        -- 完整规则：同时满足类型2 + (类型3 或 类型4)
        WHEN (REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
                OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
                OR REMARK LIKE '%分母%' OR REMARK LIKE '%断开%'
                OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
                OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
                OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%断开%'
                OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                OR ((condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
                    AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')))
            AND ((condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
                 AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                      OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
                 OR condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN 5

        -- ============================================================
        -- 优先级2-3：类型 2 — 运行方式控制断面
        -- ============================================================

        -- 子规则 2a：remark 或 desc 含运行方式关键词
        WHEN REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
            OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
            OR REMARK LIKE '%分母%' OR REMARK LIKE '%开#%' OR REMARK LIKE '%断开%'
            OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                       OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
            OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
            OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%开#%' OR condition_desc LIKE '%断开%'
            OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                       THEN 2

        -- 子规则 2b：条件设备全是 Breaker 且 station 含"站"
        -- （代理：desc/remark 同时含"开关"+"站"）
        WHEN (condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
            AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')
            THEN 2

        -- 子规则 2c：条件设备为空 且 desc 非空 且不是正常方式
        -- （代理：CONDITION_DEF 为空 + desc 有内容 + 不含"正常方式/正常运行"）
        WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
            AND (condition_desc IS NOT NULL AND condition_desc != '')
            AND condition_desc NOT LIKE '%正常方式%'
            AND condition_desc NOT LIKE '%正常运行%'
            THEN 2

        -- ============================================================
        -- 优先级4：类型 3 — 机组开停控制断面
        -- （代理：desc/remark 含"机组"+(开停/启停)）
        -- 完整规则：全部设备 dev_type=GeneratorUnit AND meas_type=Pos
        -- ============================================================
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            THEN 3

        -- ============================================================
        -- 优先级5：类型 4 — 机组出力/线路潮流控制断面
        -- （代理：desc/remark 含"出力"或"潮流"）
        -- 完整规则：全部设备 dev_type∈{Line,ACLineSegmentDot,DCLineSegmentDot,
        --          DCLineSegment,DCPole,GeneratorUnit} AND meas_type=P
        -- ============================================================
        WHEN condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
            OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%'
            THEN 4

        -- ============================================================
        -- 优先级6-8：类型 1 — 常规断面
        -- ============================================================

        -- 子规则 1a：Measurement 为空 且 desc 为空
        -- （代理：CONDITION_DEF 为空 + desc 为空）
        WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
            AND (condition_desc IS NULL OR condition_desc = '')
            THEN 1

        -- 子规则 1b：desc 含"正常方式"或"正常运行"
        WHEN condition_desc LIKE '%正常方式%' OR condition_desc LIKE '%正常运行%'
            THEN 1

        -- 子规则 1c：兜底 — desc 有内容但无特殊标记 → 常规断面
        WHEN condition_desc IS NOT NULL AND condition_desc != ''
            THEN 1

        -- 子规则 1d：desc 和 remark 均为空 → 常规断面保底
        -- 🔧 2026-07-16 L-SKstart：若都为空则使用常规断面保底
        WHEN (condition_desc IS NULL OR condition_desc = '')
            AND (REMARK IS NULL OR REMARK = '')
            THEN 1

        -- 无法判定：保持原值
        ELSE PHYSICAL_TYPE
    END AS `新值`,
    CASE
        -- 类型6 判定依据
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            AND (condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN '类型6-机组开停+出力/潮流(代理匹配)'
        -- 类型5 判定依据
        WHEN (REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
                OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
                OR REMARK LIKE '%分母%' OR REMARK LIKE '%断开%'
                OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
                OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
                OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%断开%'
                OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                OR ((condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
                    AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')))
            AND ((condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
                 AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                      OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
                 OR condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN '类型5-运行方式+条件控制(代理匹配)'
        -- 类型2 判定依据
        WHEN REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
            OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
            OR REMARK LIKE '%分母%' OR REMARK LIKE '%开#%' OR REMARK LIKE '%断开%'
            OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                       OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
            OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
            OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%开#%' OR condition_desc LIKE '%断开%'
            OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                       THEN '类型2-运行方式控制(关键词匹配)'
        WHEN (condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
            AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')
            THEN '类型2-运行方式控制(开关+站)'
        WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
            AND (condition_desc IS NOT NULL AND condition_desc != '')
            AND condition_desc NOT LIKE '%正常方式%'
            AND condition_desc NOT LIKE '%正常运行%'
            THEN '类型2-运行方式控制(空设备+有desc+非正常)'
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            THEN '类型3-机组开停控制(代理匹配)'
        WHEN condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
            OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%'
            THEN '类型4-出力/潮流控制(代理匹配)'
        WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
            AND (condition_desc IS NULL OR condition_desc = '')
            THEN '类型1-常规断面(空设备+空desc)'
        WHEN condition_desc LIKE '%正常方式%' OR condition_desc LIKE '%正常运行%'
            THEN '类型1-常规断面(关键词匹配)'
        WHEN condition_desc IS NOT NULL AND condition_desc != ''
            THEN '类型1-常规断面(兜底)'
        WHEN (condition_desc IS NULL OR condition_desc = '')
            AND (REMARK IS NULL OR REMARK = '')
            THEN '类型1-常规断面(都为空保底)'
        ELSE '无法判定(保持NULL)'
    END AS `判定依据`
FROM his_section_basic
WHERE PHYSICAL_TYPE IS NULL   -- 🔧 2026-07-16 L-SKstart：仅预览未分类行
ORDER BY
    CASE
        -- 类型6排最前
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            AND (condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN 0
        -- 类型5其次
        WHEN (REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
                OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
                OR REMARK LIKE '%分母%' OR REMARK LIKE '%断开%'
                OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
                OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
                OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%断开%'
                OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                OR ((condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
                    AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')))
            AND ((condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
                 AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                      OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
                 OR condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
                 OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
            THEN 1
        -- 类型2
        WHEN REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
            OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
            OR REMARK LIKE '%分母%' OR REMARK LIKE '%开#%' OR REMARK LIKE '%断开%'
            OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
                       OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
            OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
            OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%开#%' OR condition_desc LIKE '%断开%'
            OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
                       OR ((condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
                AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%'))
            OR ((CONDITION_DEF IS NULL OR CONDITION_DEF = '')
                AND (condition_desc IS NOT NULL AND condition_desc != '')
                AND condition_desc NOT LIKE '%正常方式%'
                AND condition_desc NOT LIKE '%正常运行%')
            THEN 1
        WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
            AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                 OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
            THEN 2
        WHEN condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
            OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%'
            THEN 3
        ELSE 4
    END,
    ID;

-- ============================================================
-- 📐 Step 2: 备份表（执行 UPDATE 之前必须备份！）
-- ============================================================

-- CREATE TABLE his_section_basic_backup_20260716 AS SELECT * FROM his_section_basic;
-- SELECT CONCAT('[OK] 备份完成，行数：', COUNT(*)) FROM his_section_basic_backup_20260716;

-- ============================================================
-- 📐 Step 3: 执行 UPDATE（确认预览结果无误后再执行）
-- ============================================================

UPDATE his_section_basic
SET PHYSICAL_TYPE = CASE
    -- ============================================================
    -- 优先级0-1：类型 5/6 — 组合断面（必须在单一类型之前检查）
    -- ============================================================

    -- 类型 6：机组开停+机组出力/线路潮流控制断面
    -- （代理：同时满足类型3代理 + 类型4代理）
    -- 完整规则：既有GeneratorUnit+Pos，又有线路/直流/机组类设备的P
    WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
        AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
             OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
        AND (condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
             OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
        THEN 6

    -- 类型 5：运行方式+条件控制断面
    -- （代理：满足类型2关键词 + (类型3代理 或 类型4代理)）
    -- 完整规则：同时满足类型2 + (类型3 或 类型4)
    WHEN (REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
            OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
            OR REMARK LIKE '%分母%' OR REMARK LIKE '%断开%'
            OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
            OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
            OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
            OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%断开%'
            OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
            OR ((condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
                AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')))
        AND ((condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
             AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
                  OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
             OR condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
             OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%')
        THEN 5

    -- ============================================================
    -- 优先级2-3：类型 2 — 运行方式控制断面
    -- ============================================================

    -- 子规则 2a：remark 或 desc 含运行方式关键词
    WHEN REMARK LIKE '%投入%' OR REMARK LIKE '%退出%' OR REMARK LIKE '%功能%'
        OR REMARK LIKE '%运行%' OR REMARK LIKE '%上网%' OR REMARK LIKE '%合环%'
        OR REMARK LIKE '%分母%' OR REMARK LIKE '%开#%' OR REMARK LIKE '%断开%'
        OR REMARK LIKE '%措施%' OR REMARK LIKE '%断环%' OR REMARK LIKE '%分列%'
               OR condition_desc LIKE '%投入%' OR condition_desc LIKE '%退出%' OR condition_desc LIKE '%功能%'
        OR condition_desc LIKE '%运行%' OR condition_desc LIKE '%上网%' OR condition_desc LIKE '%合环%'
        OR condition_desc LIKE '%分母%' OR condition_desc LIKE '%开#%' OR condition_desc LIKE '%断开%'
        OR condition_desc LIKE '%措施%' OR condition_desc LIKE '%断环%' OR condition_desc LIKE '%分列%'
               THEN 2

    -- 子规则 2b：条件设备全是 Breaker 且 station 含"站"
    -- （代理：desc/remark 同时含"开关"+"站"）
    WHEN (condition_desc LIKE '%开关%' OR REMARK LIKE '%开关%')
        AND (condition_desc LIKE '%站%' OR REMARK LIKE '%站%')
        THEN 2

    -- 子规则 2c：条件设备为空 且 desc 非空 且不是正常方式
    -- （代理：CONDITION_DEF 为空 + desc 有内容 + 不含"正常方式/正常运行"）
    WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
        AND (condition_desc IS NOT NULL AND condition_desc != '')
        AND condition_desc NOT LIKE '%正常方式%'
        AND condition_desc NOT LIKE '%正常运行%'
        THEN 2

    -- ============================================================
    -- 优先级4：类型 3 — 机组开停控制断面
    -- （代理：desc/remark 含"机组"+(开停/启停)）
    -- ⚠️ 完整规则：全部设备 dev_type=GeneratorUnit AND meas_type=Pos
    -- ============================================================
    WHEN (condition_desc LIKE '%机组%' OR REMARK LIKE '%机组%')
        AND (condition_desc LIKE '%开停%' OR REMARK LIKE '%开停%'
             OR condition_desc LIKE '%启停%' OR REMARK LIKE '%启停%')
        THEN 3

    -- ============================================================
    -- 优先级5：类型 4 — 机组出力/线路潮流控制断面
    -- （代理：desc/remark 含"出力"或"潮流"）
    -- ⚠️ 完整规则：全部设备 dev_type∈{Line,ACLineSegmentDot,DCLineSegmentDot,
    --            DCLineSegment,DCPole,GeneratorUnit} AND meas_type=P
    -- ============================================================
    WHEN condition_desc LIKE '%出力%' OR REMARK LIKE '%出力%'
        OR condition_desc LIKE '%潮流%' OR REMARK LIKE '%潮流%'
        THEN 4

    -- ============================================================
    -- 优先级6-8：类型 1 — 常规断面
    -- ============================================================

    -- 子规则 1a：Measurement 为空 且 desc 为空
    -- （代理：CONDITION_DEF 为空 + desc 为空）
    WHEN (CONDITION_DEF IS NULL OR CONDITION_DEF = '')
        AND (condition_desc IS NULL OR condition_desc = '')
        THEN 1

    -- 子规则 1b：desc 含"正常方式"或"正常运行"
    WHEN condition_desc LIKE '%正常方式%' OR condition_desc LIKE '%正常运行%'
        THEN 1

    -- 子规则 1c：兜底 — desc 有内容但无特殊标记 → 常规断面
    WHEN condition_desc IS NOT NULL AND condition_desc != ''
        THEN 1

    -- 子规则 1d：desc 和 remark 均为空 → 常规断面保底
    -- 🔧 2026-07-16 L-SKstart：若都为空则使用常规断面保底
    WHEN (condition_desc IS NULL OR condition_desc = '')
        AND (REMARK IS NULL OR REMARK = '')
        THEN 1

    -- 无法判定：保持原值（NULL）
    ELSE PHYSICAL_TYPE
END
WHERE PHYSICAL_TYPE IS NULL;   -- 🔧 2026-07-16 L-SKstart：只处理未分类行，保护已有分类数据

-- ============================================================
-- 📐 Step 4: 验证结果
-- ============================================================

-- 统计各类型数量
SELECT
    PHYSICAL_TYPE AS `物理类型`,
    CASE PHYSICAL_TYPE
        WHEN 1 THEN '常规断面'
        WHEN 2 THEN '运行方式控制断面'
        WHEN 3 THEN '机组开停控制断面'
        WHEN 4 THEN '机组出力/线路潮流控制断面'
        WHEN 5 THEN '运行方式+条件控制断面'
        WHEN 6 THEN '机组开停+机组出力/线路潮流控制断面'
        ELSE 'NULL/未知'
    END AS `类型名称`,
    COUNT(*) AS `行数`
FROM his_section_basic
GROUP BY PHYSICAL_TYPE
ORDER BY PHYSICAL_TYPE;

-- 抽查：各类型随机看几条
-- SELECT ID, CONDITION_DEF, condition_desc, REMARK, PHYSICAL_TYPE
-- FROM his_section_basic WHERE PHYSICAL_TYPE = 1 LIMIT 5;
-- SELECT ID, CONDITION_DEF, condition_desc, REMARK, PHYSICAL_TYPE
-- FROM his_section_basic WHERE PHYSICAL_TYPE = 2 LIMIT 5;
-- SELECT ID, CONDITION_DEF, condition_desc, REMARK, PHYSICAL_TYPE
-- FROM his_section_basic WHERE PHYSICAL_TYPE = 3 LIMIT 5;
-- SELECT ID, CONDITION_DEF, condition_desc, REMARK, PHYSICAL_TYPE
-- FROM his_section_basic WHERE PHYSICAL_TYPE = 4 LIMIT 5;

-- ============================================================
-- 📐 Step 5: 确认无误后清理备份
-- ============================================================

-- DROP TABLE IF EXISTS his_section_basic_backup_20260716;

-- ============================================================
-- 📋 后续 TODO（PM 追踪）
-- ============================================================
-- [ ] 类型5/6：需 CONDITION_DEF 恢复 XML 格式或接入设备关联表后实现精确判定
-- [ ] 类型3/4：当前为 REMARK/desc 关键词代理，确认误判率后可调整为精确匹配
-- [ ] 确认"开#"在实际数据中的含义（# 是通配符还是字面量）
-- [ ] 与业务确认：无 condition_desc 且无 CONDITION_DEF 的行（如 001998850/851）最终如何分类
