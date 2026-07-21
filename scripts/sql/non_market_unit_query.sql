-- ============================================================
-- 非市场化机组发电计划 — 版本匹配 + 台账映射检索
-- 适用：MySQL 5.7+ / DataWorks（无 SET 变量，无多语句）
-- 用途：供 DataWorks 工作流调用，查询结果用于后续对比入库
-- 参数：${bizdate} → DataWorks 调度日期，如 '2026-03-12'
-- 匹配字段：dm_non_market_unit_plan.PLANT_NAME + DEVICE_NAME
--            → dt_unit.PLANT_NAME + UNIT_NAME
-- 逻辑：
--   1. 子查询取目标版本号
--   2. 方式①：PLANT_NAME+DEVICE_NAME → dt_unit.UNIT_NAME
--   3. 方式②：方式①未匹配的走 PLANT_NAME+DEVICE_NAME → PLANT_NAME+UNIT_NAME
--   4. 关联 pmm_unit 限制版本 (start_version ≤ ver ≤ end_version)
-- ============================================================

SELECT
    combined.DEVICE_ID,
    combined.DEVICE_NAME,
    combined.PLANT_ID,
    combined.PLANT_NAME,
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
    t.target_version
FROM (
    -- 方式①：设备名 → dt_unit.UNIT_NAME
    SELECT
        p.DEVICE_ID,
        p.DEVICE_NAME,
        p.PLANT_ID,
        p.PLANT_NAME,
        d.CIM_ID,
        d.UNIT_NAME AS dt_unit_name,
        d.PLANT_NAME AS dt_plant_name,
        1 AS match_way
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON d.UNIT_NAME = p.DEVICE_NAME
        AND d.PLANT_NAME = p.PLANT_NAME
    GROUP BY p.DEVICE_ID, p.DEVICE_NAME, p.PLANT_ID, p.PLANT_NAME

    UNION ALL

    -- 方式②：方式①没匹配到的走这里
    SELECT
        p.DEVICE_ID,
        p.DEVICE_NAME,
        p.PLANT_ID,
        p.PLANT_NAME,
        d.CIM_ID,
        d.UNIT_NAME AS dt_unit_name,
        d.PLANT_NAME AS dt_plant_name,
        2 AS match_way
    FROM dm_non_market_unit_plan p
    JOIN dt_unit d
        ON d.UNIT_NAME = p.DEVICE_NAME
        AND d.PLANT_NAME = p.PLANT_NAME
    WHERE NOT EXISTS (
        SELECT 1 FROM dt_unit d2
        WHERE d2.UNIT_NAME = p.DEVICE_NAME
          AND d2.PLANT_NAME = p.PLANT_NAME
    )
    GROUP BY p.DEVICE_ID, p.DEVICE_NAME, p.PLANT_ID, p.PLANT_NAME
) combined
JOIN pmm_unit u
    ON u.CIM_ID = combined.CIM_ID
CROSS JOIN (
    SELECT version AS target_version
    FROM tsie_max_version_of_day
    WHERE history_day <= '${bizdate}'
    ORDER BY history_day DESC
    LIMIT 1
) t
WHERE u.start_version <= t.target_version
  AND u.end_version >= t.target_version
ORDER BY combined.PLANT_ID, combined.DEVICE_ID;
