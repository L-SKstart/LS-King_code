-- ============================================================
-- 非市场化机组发电计划 — dt_unit → pmm_unit 匹配查询
-- 适用：MySQL 5.7+ / DataWorks
-- 用途：供 DataWorks 工作流调用，根据输入的场站+设备名
--       匹配 dt_unit 获取 CIM_ID，再关联 pmm_unit 限制版本
-- 参数：${plant_name} → DataWorks 输入的场站名
--       ${device_name} → DataWorks 输入的设备名
--       ${bizdate} → 调度日期，如 '2026-03-12'
-- 匹配逻辑：
--   方式①：精确匹配 PLANT_NAME + UNIT_NAME
--   方式②：方式①未命中时，仅匹配 UNIT_NAME（宽松）
--   版本限制：pmm_unit.START_VERSION ≤ target_version ≤ END_VERSION
-- ============================================================

SELECT
    m.CIM_ID,
    m.UNIT_NAME,
    m.PLANT_NAME,
    m.PLANT_ID,
    m.match_way,
    u.START_VERSION,
    u.END_VERSION,
    t.version AS target_version
FROM (
    -- 方式①：精确匹配（电厂名+设备名 → 电厂名+机组名）
    SELECT
        d.CIM_ID,
        d.UNIT_NAME,
        d.PLANT_NAME,
        d.PLANT_ID,
        1 AS match_way
    FROM dt_unit d
    WHERE d.PLANT_NAME = '${plant_name}'
      AND d.UNIT_NAME  = '${device_name}'
    GROUP BY d.CIM_ID, d.UNIT_NAME, d.PLANT_NAME, d.PLANT_ID

    UNION ALL

    -- 方式②：宽松匹配（方式①未命中时，仅用设备名）
    SELECT
        d.CIM_ID,
        d.UNIT_NAME,
        d.PLANT_NAME,
        d.PLANT_ID,
        2 AS match_way
    FROM dt_unit d
    WHERE d.UNIT_NAME = '${device_name}'
      AND NOT EXISTS (
          SELECT 1 FROM dt_unit d2
          WHERE d2.PLANT_NAME = '${plant_name}'
            AND d2.UNIT_NAME  = '${device_name}'
      )
    GROUP BY d.CIM_ID, d.UNIT_NAME, d.PLANT_NAME, d.PLANT_ID
) m
JOIN pmm_unit u
    ON u.CIM_ID = m.CIM_ID
CROSS JOIN (
    SELECT version
    FROM tsie_max_version_of_day
    WHERE history_day <= '${bizdate}'
    ORDER BY history_day DESC
    LIMIT 1
) t
WHERE u.START_VERSION <= t.version
  AND u.END_VERSION >= t.version;
