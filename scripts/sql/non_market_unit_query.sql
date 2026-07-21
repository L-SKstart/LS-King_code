-- ============================================================
-- 非市场化机组发电计划 — 版本匹配 + 台账映射检索
-- 适用：MySQL 5.7+（无 CTE、无窗口函数）
-- 用途：供 DataWorks 工作流调用，查询结果用于后续对比入库
-- 逻辑：
--   1. 从 tsie_max_version_of_day 取目标版本
--   2. 方式①：dm_non_market_unit_plan(站名+机组名) → dt_unit.unit_name
--   3. 方式②：方式①未匹配的 → dt_unit.plant_name + unit_name
--   4. 关联 pmm_unit 限制版本 (start_version ≤ ver ≤ end_version)
-- ============================================================

-- ===== 参数（在 DataWorks 中替换为调度参数） =====
-- @query_date := '${bizdate}'  或指定日期如 '2026-07-20'
SET @query_date = '2026-07-20';

-- ===== Step 1：获取目标版本号 =====
SET @target_version = (
    SELECT version FROM tsie_max_version_of_day
    WHERE history_day <= @query_date
    ORDER BY history_day DESC
    LIMIT 1
);

-- ===== Step 2：方式① — 站名+机组名 → dt_unit.unit_name =====
-- 用临时表存方式①匹配结果
DROP TEMPORARY TABLE IF EXISTS tmp_match_1;
CREATE TEMPORARY TABLE tmp_match_1 AS
SELECT
    p.station_code,
    p.station_name,
    p.unit_code,
    p.unit_name,
    d.CIM_ID,
    d.UNIT_NAME AS dt_unit_name,
    d.PLANT_NAME AS dt_plant_name,
    1 AS match_way
FROM dm_non_market_unit_plan p
JOIN dt_unit d
    ON d.UNIT_NAME = p.unit_name
    AND d.PLANT_NAME = p.station_name
WHERE @target_version IS NOT NULL
GROUP BY p.station_code, p.station_name, p.unit_code, p.unit_name;
-- GROUP BY 去重，防止 dt_unit 中同一机组多条记录

-- ===== Step 3：方式② — 方式①未匹配的走这里 =====
DROP TEMPORARY TABLE IF EXISTS tmp_match_2;
CREATE TEMPORARY TABLE tmp_match_2 AS
SELECT
    p.station_code,
    p.station_name,
    p.unit_code,
    p.unit_name,
    d.CIM_ID,
    d.UNIT_NAME AS dt_unit_name,
    d.PLANT_NAME AS dt_plant_name,
    2 AS match_way
FROM dm_non_market_unit_plan p
JOIN dt_unit d
    ON d.UNIT_NAME = p.unit_name
    AND d.PLANT_NAME = p.station_name
WHERE @target_version IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM tmp_match_1 m1
      WHERE m1.station_code = p.station_code
        AND m1.unit_code = p.unit_code
  )
GROUP BY p.station_code, p.station_name, p.unit_code, p.unit_name;

-- ===== Step 4：合并结果 + 关联台账限制版本 =====
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
    @target_version AS target_version
FROM (
    SELECT * FROM tmp_match_1
    UNION ALL
    SELECT * FROM tmp_match_2
) combined
JOIN pmm_unit u
    ON u.CIM_ID = combined.CIM_ID
    AND u.start_version <= @target_version
    AND u.end_version >= @target_version
ORDER BY combined.station_code, combined.unit_code;

-- ===== 清理临时表 =====
DROP TEMPORARY TABLE IF EXISTS tmp_match_1;
DROP TEMPORARY TABLE IF EXISTS tmp_match_2;
