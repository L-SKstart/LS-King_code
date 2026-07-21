-- ============================================================
-- SQL 1：dt_unit 全量数据 — 供 DataWorks 匹配用
-- 适用：MySQL 5.7+
-- 用途：输出 dt_unit 所有机组信息，DataWorks 工作流
--       自行通过 UNIT_NAME/PLANT_NAME 等字段匹配接入数据，
--       匹配成功后拿到 CIM_ID，传给 SQL 2
-- ============================================================

SELECT
    CIM_ID,
    UNIT_NAME,
    PLANT_NAME,
    PLANT_ID
FROM dt_unit
GROUP BY CIM_ID, UNIT_NAME, PLANT_NAME, PLANT_ID
ORDER BY PLANT_ID, UNIT_NAME;
