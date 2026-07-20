-- ============================================================
-- 非市场化机组发电计划检索 SQL
-- 版本匹配规则 + 机组匹配（先精确再模糊）
-- ============================================================

-- 替换以下变量为实际值：
-- @query_date     → 查询日期（如 '2026-07-20'）
-- 【接入数据表】  → 接入数据的实际表名（存场站+机组名称的源表）

-- ========================================
-- 第1步：获取目标版本号
-- ========================================
SET @target_version = (
    SELECT version FROM tsie_max_version_of_day
    WHERE history_day <= @query_date
    ORDER BY history_day DESC
    LIMIT 1
);

-- ========================================
-- 第2步：给接入数据打匹配标记（先方式1再方式2）
-- ========================================
DROP TEMPORARY TABLE IF EXISTS tmp_unit_matched;
CREATE TEMPORARY TABLE tmp_unit_matched AS
WITH matched AS (
    -- 方式1：站+机组名 → dt_unit.unit_name
    SELECT
        src.*,
        d.CIM_ID AS cim_id_1,
        NULL AS cim_id_2,
        1 AS match_way
    FROM 【接入数据表】 src
    JOIN dt_unit d
        ON src.station = d.plant_name
        AND src.unit_name = d.unit_name

    UNION

    -- 方式2：站+机组名 → dt_unit.plant_name + unit_name（排除已匹配方式1的）
    SELECT
        src.*,
        NULL AS cim_id_1,
        d.CIM_ID AS cim_id_2,
        2 AS match_way
    FROM 【接入数据表】 src
    JOIN dt_unit d
        ON src.station = d.plant_name
        AND src.unit_name = d.unit_name
    WHERE NOT EXISTS (
        SELECT 1 FROM dt_unit d2
        WHERE d2.plant_name = src.station
          AND d2.unit_name = src.unit_name
    )
)
SELECT * FROM matched;

-- ========================================
-- 第3步：关联台账表，限制版本，返回最终数据
-- ========================================
SELECT
    m.*,
    u.unit_code,
    u.unit_name    AS pmm_unit_name,
    u.plant_code,
    u.plant_name   AS pmm_plant_name,
    u.start_version,
    u.end_version,
    u.CIM_ID,
    @target_version AS query_version
FROM tmp_unit_matched m
JOIN pmm_unit u
    ON u.CIM_ID = COALESCE(m.cim_id_1, m.cim_id_2)
    AND u.start_version <= @target_version
    AND u.end_version >= @target_version;
