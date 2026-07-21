-- ============================================================
-- 更新 dm_non_market_unit_plan — 完整版（含索引加速）
-- 适用：MySQL 5.7+
--
-- 匹配链路：
--   dm_non.DEVICE_ID（旧值）→ dt_unit.CODE
--   → dt_unit.CIM_ID → pmm_unit.CIM_ID
--   → 版本过滤 + 取最新 → 更新 dm_non
--
-- 更新字段：DEVICE_ID、DEVICE_NAME、PLANT_ID、PLANT_NAME、UPDATE_TIME
-- 参数：${bizdate} → 查询版本的日期
-- ============================================================

-- ========================================
-- 第1步：创建索引加速（仅首次执行，已有则跳过）
-- ========================================
-- dm_non：DEVICE_ID 用于关联 dt_unit.CODE
ALTER TABLE dm_non_market_unit_plan ADD INDEX IDX_DEVICE_ID (`DEVICE_ID`) USING BTREE;

-- dt_unit：CODE 和 CIM_ID 是关键关联字段
ALTER TABLE dt_unit ADD INDEX IDX_CODE (`CODE`) USING BTREE;
ALTER TABLE dt_unit ADD INDEX IDX_CIM_ID (`CIM_ID`) USING BTREE;

-- tsie_max_version_of_day：history_day 用于查版本
ALTER TABLE tsie_max_version_of_day ADD INDEX IDX_HISTORY_DAY (`history_day`) USING BTREE;

-- ========================================
-- 第2步：执行更新
-- ========================================
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
      -- 同一 CIM_ID 可能有多条版本记录，取 START_VERSION 最大的
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
