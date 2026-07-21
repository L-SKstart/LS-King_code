-- ============================================================
-- SQL：pmm_unit 版本筛选 — 按版本号过滤获取全部信息
-- 适用：MySQL 5.7+ / DataWorks
-- 用途：从 tsie_max_version_of_day 取目标版本号，
--       筛选出 pmm_unit 中符合版本范围的记录。
--       输出所有需要的字段，不涉及其他表匹配。
-- 参数：${bizdate} → 调度日期，如 '2026-03-12'
-- ============================================================

SELECT
    u.DEVICE_ID,
    u.DEVICE_NAME,
    u.CIM_ID,
    u.CIM_NAME,
    u.PLANT_ID,
    u.PLANT_NAME,
    u.START_VERSION,
    u.END_VERSION,
    t.version AS target_version
FROM pmm_unit u
CROSS JOIN (
    SELECT version
    FROM tsie_max_version_of_day
    WHERE history_day <= '${bizdate}'
    ORDER BY history_day DESC
    LIMIT 1
) t
WHERE u.START_VERSION <= t.version
  AND u.END_VERSION >= t.version
ORDER BY u.PLANT_ID, u.DEVICE_NAME;
