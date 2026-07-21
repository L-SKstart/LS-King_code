-- ============================================================
-- 非市场化机组发电计划 — 符合版本的机组台账信息
-- 适用：MySQL 5.7+ / DataWorks
-- 用途：从 dt_unit + pmm_unit 中筛选出符合版本要求的
--       全部机组信息，供 DataWorks 工作流做匹配关联
-- 参数：${bizdate} → 调度日期，如 '2026-03-12'
-- 输出：dt_unit 的 CIM_ID/UNIT_NAME/PLANT_NAME/PLANT_ID
--       pmm_unit 的 START_VERSION/END_VERSION
--       以及目标版本号 target_version
-- ============================================================

SELECT
    d.CIM_ID,
    d.UNIT_NAME,
    d.PLANT_NAME,
    d.PLANT_ID,
    u.START_VERSION,
    u.END_VERSION,
    t.version AS target_version
FROM dt_unit d
JOIN pmm_unit u
    ON u.CIM_ID = d.CIM_ID
CROSS JOIN (
    SELECT version
    FROM tsie_max_version_of_day
    WHERE history_day <= '${bizdate}'
    ORDER BY history_day DESC
    LIMIT 1
) t
WHERE u.START_VERSION <= t.version
  AND u.END_VERSION >= t.version
ORDER BY d.PLANT_ID, d.UNIT_NAME;
