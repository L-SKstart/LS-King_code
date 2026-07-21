-- ============================================================
-- 非市场化机组发电计划 — 版本匹配 + 台账映射检索
-- 用途：供 DataWorks 工作流调用，查询结果用于后续对比入库
-- 逻辑：
--   1. 从 tsie_max_version_of_day 取目标版本
--   2. 方式①：dm_non_market_unit_plan(站名+机组名) → dt_unit.unit_name
--   3. 方式②：方式①未匹配的 → dt_unit.plant_name + unit_name
--   4. 关联 pmm_unit 限制版本 (start_version ≤ ver ≤ end_version)
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
-- 第2步：方式① — 站名+机组名 → dt_unit.unit_name
-- ========================================
match_way1 AS (
    SELECT
        p.station_code,
        p.station_name,
        p.unit_code,
        p.unit_name,
        d.CIM_ID,
        d.UNIT_NAME AS dt_unit_name,
        d.PLANT_NAME AS dt_plant_name,
        d.PLANT_ID   AS dt_plant_id,
        1 AS match_way,
        ROW_NUMBER() OVER (
            PARTITION BY p.station_code, p.unit_code
            ORDER BY d.ID
        ) AS rn
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON d.UNIT_NAME = p.unit_name
        AND d.PLANT_NAME = p.station_name
    CROSS JOIN target_version t
    WHERE t.version IS NOT NULL
),

-- ========================================
-- 第3步：方式② — 站名+机组名 → dt_unit.plant_name + unit_name
--          （方式①没匹配到的走这个）
-- ========================================
match_way2 AS (
    SELECT
        p.station_code,
        p.station_name,
        p.unit_code,
        p.unit_name,
        d.CIM_ID,
        d.UNIT_NAME AS dt_unit_name,
        d.PLANT_NAME AS dt_plant_name,
        d.PLANT_ID   AS dt_plant_id,
        2 AS match_way,
        ROW_NUMBER() OVER (
            PARTITION BY p.station_code, p.unit_code
            ORDER BY d.ID
        ) AS rn
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON d.PLANT_NAME = p.station_name
        AND d.UNIT_NAME = p.unit_name
    CROSS JOIN target_version t
    WHERE t.version IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM dt_unit d2
          WHERE d2.UNIT_NAME = p.unit_name
            AND d2.PLANT_NAME = p.station_name
      )
)

-- ========================================
-- 第4步：合并结果 + 关联台账限制版本
-- ========================================
SELECT
    combined.station_code,
    combined.station_name,
    combined.unit_code,
    combined.unit_name,
    combined.CIM_ID,
    combined.match_way,
    combined.dt_unit_name,
    combined.dt_plant_name,
    u.unit_code    AS pmm_unit_code,
    u.unit_name    AS pmm_unit_name,
    u.plant_code   AS pmm_plant_code,
    u.plant_name   AS pmm_plant_name,
    u.start_version,
    u.end_version,
    t.version      AS target_version
FROM (
    -- 方式①匹配结果
    SELECT * FROM match_way1 WHERE rn = 1
    -- 方式②匹配结果（排除已匹配方式①的）
    UNION ALL
    SELECT * FROM match_way2 WHERE rn = 1
      AND NOT EXISTS (
          SELECT 1 FROM match_way1 m1
          WHERE m1.station_code = match_way2.station_code
            AND m1.unit_code = match_way2.unit_code
      )
) combined
JOIN pmm_unit u
    ON u.CIM_ID = combined.CIM_ID
    AND u.start_version <= (SELECT version FROM target_version)
    AND u.end_version >= (SELECT version FROM target_version)
CROSS JOIN target_version t
ORDER BY combined.station_code, combined.unit_code;
