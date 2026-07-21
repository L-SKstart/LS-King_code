-- ============================================================
-- SQL 1：dt_unit 匹配 — 获取 CIM_ID
-- 适用：MySQL 5.7+ / DataWorks
--
-- 匹配逻辑：
--   方式①：接入数据的 场站名+设备名 → dt_unit.UNIT_NAME
--          （仅用设备名匹配机组名称）
--   方式②：方式①没匹配到的 →
--           接入数据的 场站名+设备名 → dt_unit.PLANT_NAME + UNIT_NAME
--          （用场站名+设备名同时匹配）
--
-- 两种方式最终都通过 CIM_ID 关联 pmm_unit，但需要限制版本。
-- 版本过滤在 SQL 2 中处理，本 SQL 只负责从 dt_unit 获取 CIM_ID。
-- ============================================================

SELECT
    d.CIM_ID,
    d.UNIT_NAME,
    d.PLANT_NAME,
    d.PLANT_ID,
    CASE
        WHEN d.PLANT_NAME = '${plant_name}' AND d.UNIT_NAME = '${device_name}' THEN 1
        ELSE 2
    END AS match_way
FROM dt_unit d
WHERE (d.PLANT_NAME = '${plant_name}' AND d.UNIT_NAME = '${device_name}')  -- 方式②：精确匹配
   OR (d.UNIT_NAME = '${device_name}'
       AND NOT EXISTS (                        -- 方式①：仅配名称，且方式②没匹配到
           SELECT 1 FROM dt_unit d2
           WHERE d2.PLANT_NAME = '${plant_name}'
             AND d2.UNIT_NAME  = '${device_name}'
       ))
GROUP BY d.CIM_ID, d.UNIT_NAME, d.PLANT_NAME, d.PLANT_ID;
