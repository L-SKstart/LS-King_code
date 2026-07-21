-- ============================================================
-- 更新 dm_non_market_unit_plan — 完整匹配逻辑 + 版本过滤
-- 适用：MySQL 5.7+
--
-- 匹配逻辑：
--   方式①：DEVICE_NAME → dt_unit.UNIT_NAME（仅用设备名）
--   方式②：方式①不存在时 → PLANT_NAME+DEVICE_NAME → PLANT_NAME+UNIT_NAME
--
-- 链路：dm_non → dt_unit(CIM_ID) → pmm_unit(版本过滤) → 更新 dm_non
-- 更新字段：DEVICE_ID、DEVICE_NAME、PLANT_ID、PLANT_NAME、UPDATE_TIME
-- 参数：${bizdate}
-- ============================================================

-- ========================================
-- 第1步：创建索引加速
-- ========================================
SET @db = DATABASE();
SET @idx_sql = 'SELECT ''SKIP''';

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_UNIT_NAME');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_UNIT_NAME (`UNIT_NAME`)', @idx_sql);
PREPARE s1 FROM @idx_sql; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_CIM_ID');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_CIM_ID (`CIM_ID`)', 'SELECT ''SKIP''');
PREPARE s2 FROM @idx_sql; EXECUTE s2; DEALLOCATE PREPARE s2;

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='tsie_max_version_of_day' AND index_name='IDX_HISTORY_DAY');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE tsie_max_version_of_day ADD INDEX IDX_HISTORY_DAY (`history_day`)', 'SELECT ''SKIP''');
PREPARE s3 FROM @idx_sql; EXECUTE s3; DEALLOCATE PREPARE s3;

-- ========================================
-- 第2步：执行更新
--        子查询中先匹配 dt_unit（方式①/②），再关联 pmm_unit 版本过滤
-- ========================================
UPDATE dm_non_market_unit_plan t
JOIN (
    SELECT
        p.PLANT_NAME AS src_plant,
        p.DEVICE_NAME AS src_device,
        u.DEVICE_ID   AS new_device_id,
        u.DEVICE_NAME AS new_device_name,
        u.PLANT_ID    AS new_plant_id,
        u.PLANT_NAME  AS new_plant_name
    FROM dm_non_market_unit_plan p
    -- 方式①/②：先尝试仅 UNIT_NAME 匹配；若该电厂下有精确匹配则用精确匹配
    JOIN dt_unit d
        ON (d.UNIT_NAME = p.DEVICE_NAME
            AND NOT EXISTS (
                SELECT 1 FROM dt_unit d2
                WHERE d2.PLANT_NAME = p.PLANT_NAME
                  AND d2.UNIT_NAME  = p.DEVICE_NAME
            ))
        OR (d.PLANT_NAME = p.PLANT_NAME
            AND d.UNIT_NAME = p.DEVICE_NAME)
    JOIN pmm_unit u ON u.CIM_ID = d.CIM_ID
    CROSS JOIN (
        SELECT version FROM tsie_max_version_of_day
        WHERE history_day <= '${bizdate}'
        ORDER BY history_day DESC
        LIMIT 1
    ) ver
    WHERE u.START_VERSION <= ver.version
      AND u.END_VERSION >= ver.version
      AND u.START_VERSION = (
          SELECT MAX(u2.START_VERSION)
          FROM pmm_unit u2
          WHERE u2.CIM_ID = u.CIM_ID
            AND u2.START_VERSION <= ver.version
            AND u2.END_VERSION >= ver.version
      )
    GROUP BY p.PLANT_NAME, p.DEVICE_NAME
) src ON t.PLANT_NAME = src.src_plant AND t.DEVICE_NAME = src.src_device
SET
    t.DEVICE_ID   = src.new_device_id,
    t.DEVICE_NAME = src.new_device_name,
    t.PLANT_ID    = src.new_plant_id,
    t.PLANT_NAME  = src.new_plant_name,
    t.UPDATE_TIME = NOW();
