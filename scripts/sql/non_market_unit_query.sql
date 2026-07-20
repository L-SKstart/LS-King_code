-- ============================================================
-- 非市场化机组发电计划 — 版本匹配 + 台账映射检索
-- 用途：供 DataWorks 工作流调用，查询结果用于后续对比入库
-- 逻辑：
--   1. 从 tsie_max_version_of_day 取目标版本
--   2. 方式①：接入数据(站+机组) → dt_unit.unit_name
--   3. 方式②：方式①未匹配的 → dt_unit.plant_name + unit_name
--   4. 关联 pmm_unit 限制版本
-- ============================================================

-- ===== 参数（在 DataWorks 中替换为调度参数） =====
-- @query_date := '${bizdate}'  或指定日期如 '2026-07-20'

-- ========================================
-- 第1步：获取目标版本号
-- ========================================
WITH target_version AS (
    SELECT version
    FROM tsie_max_version_of_day
    WHERE history_day <= @query_date
    ORDER BY history_day DESC
    LIMIT 1
),

-- ========================================
-- 第2步：接入数据关联 dt_unit（方式①）
-- ========================================
match_way1 AS (
    SELECT
        p.*,
        d.CIM_ID,
        d.unit_name  AS dt_unit_name,
        d.plant_name AS dt_plant_name,
        1 AS match_way,
        ROW_NUMBER() OVER (
            PARTITION BY p.场站字段, p.机组名字段
            ORDER BY d.CIM_ID
        ) AS rn
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON p.场站字段 = d.plant_name
        AND p.机组名字段 = d.unit_name
    CROSS JOIN target_version t
    WHERE t.version IS NOT NULL
),

-- ========================================
-- 第3步：方式①未匹配的走方式②
-- ========================================
match_way2 AS (
    SELECT
        p.*,
        d.CIM_ID,
        d.unit_name  AS dt_unit_name,
        d.plant_name AS dt_plant_name,
        2 AS match_way,
        ROW_NUMBER() OVER (
            PARTITION BY p.场站字段, p.机组名字段
            ORDER BY d.CIM_ID
        ) AS rn
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON p.场站字段 = d.plant_name
        AND p.机组名字段 = d.unit_name
    CROSS JOIN target_version t
    WHERE t.version IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dt_unit d2
          WHERE d2.plant_name = p.场站字段
            AND d2.unit_name = p.机组名字段
      )
)

-- ========================================
-- 第4步：合并结果 + 关联台账限制版本
-- ========================================
SELECT
    COALESCE(m1.场站字段, m2.场站字段) AS station,
    COALESCE(m1.机组名字段, m2.机组名字段) AS unit_name,
    COALESCE(m1.CIM_ID, m2.CIM_ID) AS CIM_ID,
    COALESCE(m1.match_way, m2.match_way) AS match_way,
    u.unit_code,
    u.unit_name     AS pmm_unit_name,
    u.plant_code,
    u.plant_name    AS pmm_plant_name,
    u.start_version,
    u.end_version,
    t.version       AS target_version
FROM (
    SELECT * FROM match_way1 WHERE rn = 1
    UNION ALL
    SELECT * FROM match_way2 WHERE rn = 1
      AND NOT EXISTS (
          SELECT 1 FROM match_way1 m1_1
          WHERE m1_1.场站字段 = match_way2.场站字段
            AND m1_1.机组名字段 = match_way2.机组名字段
      )
) combined
JOIN pmm_unit u
    ON u.CIM_ID = combined.CIM_ID
    AND u.start_version <= (SELECT version FROM target_version)
    AND u.end_version >= (SELECT version FROM target_version)
CROSS JOIN target_version t;
