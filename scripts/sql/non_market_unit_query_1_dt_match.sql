-- ============================================================
-- SQL 1：dt_unit 匹配 — 获取 CIM_ID（三级匹配）
-- 适用：MySQL 5.7+ / DataWorks
--
-- 匹配优先级：
--   第1级：CODE 匹配 — DEVICE_ID → dt_unit.CODE
--   第2级：方式① — DEVICE_NAME → dt_unit.UNIT_NAME（仅设备名）
--   第3级：方式② — PLANT_NAME+DEVICE_NAME → dt_unit.PLANT_NAME+UNIT_NAME
--
-- 三种方式最终都通过 CIM_ID 关联 pmm_unit。
-- 版本过滤在 SQL 2 中处理，本 SQL 只负责从 dt_unit 获取 CIM_ID。
-- ============================================================

SELECT
    d.CIM_ID,
    d.UNIT_NAME,
    d.PLANT_NAME,
    d.PLANT_ID,
    CASE
        WHEN d.CODE = '${device_id}' THEN 0
        WHEN d.UNIT_NAME = '${device_name}'
             AND NOT EXISTS (
                 SELECT 1 FROM dt_unit
                 WHERE PLANT_NAME = '${plant_name}'
                   AND UNIT_NAME  = '${device_name}'
             )
        THEN 1
        ELSE 2
    END AS match_level
FROM dt_unit d
WHERE d.CODE = '${device_id}'                           -- 第1级：CODE 匹配
   OR (d.UNIT_NAME = '${device_name}'                    -- 第2级：方式①
       AND NOT EXISTS (
           SELECT 1 FROM dt_unit
           WHERE PLANT_NAME = '${plant_name}'
             AND UNIT_NAME  = '${device_name}'
       )
       AND NOT EXISTS (
           SELECT 1 FROM dt_unit
           WHERE CODE = '${device_id}'
       ))
   OR (d.PLANT_NAME = '${plant_name}'                    -- 第3级：方式②
       AND d.UNIT_NAME = '${device_name}'
       AND NOT EXISTS (SELECT 1 FROM dt_unit WHERE CODE = '${device_id}'))
GROUP BY d.CIM_ID, d.UNIT_NAME, d.PLANT_NAME, d.PLANT_ID
ORDER BY match_level ASC
LIMIT 1;
