-- ============================================================
-- SQL 2：pmm_unit 版本过滤 — 根据 CIM_ID 获取新 DEVICE_ID
-- 适用：MySQL 5.7+ / DataWorks
-- 用途：SQL 1 匹配拿到 CIM_ID 后，由 DataWorks 工作流
--       组织好 CIM_ID 列表，传给本 SQL 过滤版本后
--       获取最新的 DEVICE_ID（设备ID）
-- 参数：${bizdate} → 调度日期，如 '2026-03-12'
-- 注意：CIM_ID 列表需要在 DataWorks 中拼接为 IN 条件
--       示例：WHERE u.CIM_ID IN ('id1', 'id2', ...)
-- ============================================================

SELECT
    u.CIM_ID,
    u.DEVICE_ID  AS pmm_device_id,
    u.DEVICE_NAME,
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
  -- AND u.CIM_ID IN (?)  ← DataWorks 在此拼接 CIM_ID 列表
ORDER BY u.PLANT_ID, u.DEVICE_NAME;
