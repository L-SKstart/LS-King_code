-- ============================================================
-- 更新 dm_non_market_unit_plan — 通过 CODE 匹配重新赋值
-- 适用：MySQL 5.7+（单条 UPDATE，兼容严格模式）
--
-- 匹配链路：
--   dm_non.DEVICE_ID（旧值）→ dt_unit.CODE
--   → dt_unit.CIM_ID → pmm_unit.CIM_ID
--   → 取版本范围内最新一条 → 更新 dm_non
--
-- 更新字段：DEVICE_ID、DEVICE_NAME、PLANT_ID、PLANT_NAME、UPDATE_TIME
-- 参数：${bizdate} → 查询版本的日期
-- ============================================================

UPDATE dm_non_market_unit_plan t
JOIN (
    SELECT
        d.CODE  AS old_code,
        u.DEVICE_ID,
        u.DEVICE_NAME,
        u.PLANT_ID,
        u.PLANT_NAME
    FROM dt_unit d
    JOIN pmm_unit u ON u.CIM_ID = d.CIM_ID
    CROSS JOIN (
        SELECT version FROM tsie_max_version_of_day
        WHERE history_day <= '${bizdate}'
        ORDER BY history_day DESC
        LIMIT 1
    ) ver
    WHERE u.START_VERSION <= ver.version
      AND u.END_VERSION >= ver.version
      -- 取同一 CIM_ID 下 START_VERSION 最大的那条（最新版本）
      AND u.START_VERSION = (
          SELECT MAX(u2.START_VERSION)
          FROM pmm_unit u2
          WHERE u2.CIM_ID = u.CIM_ID
            AND u2.START_VERSION <= ver.version
            AND u2.END_VERSION >= ver.version
      )
) src ON t.DEVICE_ID = src.old_code
SET
    t.DEVICE_ID   = src.DEVICE_ID,
    t.DEVICE_NAME = src.DEVICE_NAME,
    t.PLANT_ID    = src.PLANT_ID,
    t.PLANT_NAME  = src.PLANT_NAME,
    t.UPDATE_TIME = NOW();
