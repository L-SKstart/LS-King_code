-- ============================================================
-- 更新 dm_non_market_unit_plan — 5级完整匹配逻辑 + 版本过滤
-- 适用：MySQL 5.7+
--
-- 🔧 2026-07-22 Claude：重写为 COALESCE+LEFT JOIN 结构
--   新增第3/5级（直匹配 pmm_unit，不经过 dt_unit）
--   原版仅支持第1/2/4级（均需经 dt_unit→CIM_ID→pmm_unit）
--
-- 匹配优先级（5级，COALESCE 依次取首个成功）：
--   第1级：DEVICE_NAME → dt_unit.UNIT_NAME（仅设备名）
--   第2级：DEVICE_ID(CODE) → dt_unit.CODE
--   第3级：PLANT_NAME → pmm_unit.DEVICE_NAME（直匹配台账，不经过 dt_unit）
--   第4级：PLANT_NAME+DEVICE_NAME → dt_unit.PLANT_NAME+UNIT_NAME（精确匹配）
--   第5级：DEVICE_NAME → pmm_unit.DEVICE_NAME（直匹配台账，不经过 dt_unit）
--
-- 链路(1/2/4级)：dm_non → dt_unit(CIM_ID) → pmm_unit(版本过滤) → 更新
-- 链路(3/5级)：dm_non → pmm_unit(直匹配+版本过滤) → 更新
--
-- 更新字段：DEVICE_ID、DEVICE_NAME、PLANT_ID、PLANT_NAME、UPDATE_TIME
-- 参数：${bizdate} — 业务日期（如 2026-07-22），替换为实际日期
-- ============================================================

-- ========================================
-- 第1步：创建索引加速（按需创建，已存在则跳过）
-- ========================================
SET @db = DATABASE();
SET @idx_sql = 'SELECT ''SKIP''';

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_CODE');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_CODE (`CODE`)', 'SELECT ''SKIP''');
PREPARE s0 FROM @idx_sql; EXECUTE s0; DEALLOCATE PREPARE s0;

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_UNIT_NAME');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_UNIT_NAME (`UNIT_NAME`)', @idx_sql);
PREPARE s1 FROM @idx_sql; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_CIM_ID');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_CIM_ID (`CIM_ID`)', 'SELECT ''SKIP''');
PREPARE s2 FROM @idx_sql; EXECUTE s2; DEALLOCATE PREPARE s2;

SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='tsie_max_version_of_day' AND index_name='IDX_HISTORY_DAY');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE tsie_max_version_of_day ADD INDEX IDX_HISTORY_DAY (`history_day`)', 'SELECT ''SKIP''');
PREPARE s3 FROM @idx_sql; EXECUTE s3; DEALLOCATE PREPARE s3;

-- 🔧 2026-07-22 Claude：新增 pmm_unit.DEVICE_NAME 索引（第3/5级直匹配需要）
SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='pmm_unit' AND index_name='IDX_DEVICE_NAME');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE pmm_unit ADD INDEX IDX_DEVICE_NAME (`DEVICE_NAME`)', 'SELECT ''SKIP''');
PREPARE s4 FROM @idx_sql; EXECUTE s4; DEALLOCATE PREPARE s4;

-- 🔧 2026-07-22 Claude：新增 dt_unit 联合索引（第4级 PLANT_NAME+UNIT_NAME 精确匹配需要）
SET @exists = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema=@db AND table_name='dt_unit' AND index_name='IDX_PLANT_UNIT');
SET @idx_sql = IF(@exists = 0, 'ALTER TABLE dt_unit ADD INDEX IDX_PLANT_UNIT (`PLANT_NAME`, `UNIT_NAME`)', 'SELECT ''SKIP''');
PREPARE s5 FROM @idx_sql; EXECUTE s5; DEALLOCATE PREPARE s5;

-- ========================================
-- 第2步：执行更新
--   核心思路：COALESCE 按优先级 1→5 依次取值，首个非 NULL 即匹配成功
--   每个级别独立 LEFT JOIN，互不依赖
-- ========================================
UPDATE dm_non_market_unit_plan t
JOIN (
    SELECT
        p.PLANT_NAME,
        p.DEVICE_NAME,
        -- COALESCE 实现 5 级优先级：第1级 → 第2级 → 第3级 → 第4级 → 第5级
        COALESCE(
            u1.DEVICE_ID, u2.DEVICE_ID, u3.DEVICE_ID, u4.DEVICE_ID, u5.DEVICE_ID
        ) AS new_device_id,
        COALESCE(
            u1.DEVICE_NAME, u2.DEVICE_NAME, u3.DEVICE_NAME, u4.DEVICE_NAME, u5.DEVICE_NAME
        ) AS new_device_name,
        COALESCE(
            u1.PLANT_ID, u2.PLANT_ID, u3.PLANT_ID, u4.PLANT_ID, u5.PLANT_ID
        ) AS new_plant_id,
        COALESCE(
            u1.PLANT_NAME, u2.PLANT_NAME, u3.PLANT_NAME, u4.PLANT_NAME, u5.PLANT_NAME
        ) AS new_plant_name
    FROM dm_non_market_unit_plan p

    -- 版本号只查一次，所有级别共用（避免重复子查询）
    CROSS JOIN (
        SELECT version FROM tsie_max_version_of_day
        WHERE history_day <= '${bizdate}'
        ORDER BY history_day DESC
        LIMIT 1
    ) ver

    -- ================================================================
    -- 第1级：DEVICE_NAME 匹配 dt_unit.UNIT_NAME（方式①，仅设备名）
    --   链路：dm_non.DEVICE_NAME → dt_unit.UNIT_NAME → CIM_ID → pmm_unit
    -- ================================================================
    LEFT JOIN dt_unit d1 ON d1.UNIT_NAME = p.DEVICE_NAME
    LEFT JOIN pmm_unit u1 ON u1.CIM_ID = d1.CIM_ID
        AND u1.START_VERSION <= ver.version
        AND u1.END_VERSION   >= ver.version
        -- 同一 CIM_ID 取最新版本（START_VERSION 最大）
        AND u1.START_VERSION = (
            SELECT MAX(u_inner.START_VERSION)
            FROM pmm_unit u_inner
            WHERE u_inner.CIM_ID = u1.CIM_ID
              AND u_inner.START_VERSION <= ver.version
              AND u_inner.END_VERSION   >= ver.version
        )

    -- ================================================================
    -- 第2级：DEVICE_ID(CODE) 匹配 dt_unit.CODE
    --   链路：dm_non.DEVICE_ID → dt_unit.CODE → CIM_ID → pmm_unit
    -- ================================================================
    LEFT JOIN dt_unit d2 ON d2.CODE = p.DEVICE_ID
    LEFT JOIN pmm_unit u2 ON u2.CIM_ID = d2.CIM_ID
        AND u2.START_VERSION <= ver.version
        AND u2.END_VERSION   >= ver.version
        AND u2.START_VERSION = (
            SELECT MAX(u_inner.START_VERSION)
            FROM pmm_unit u_inner
            WHERE u_inner.CIM_ID = u2.CIM_ID
              AND u_inner.START_VERSION <= ver.version
              AND u_inner.END_VERSION   >= ver.version
        )

    -- ================================================================
    -- 第3级：PLANT_NAME 直匹配 pmm_unit.DEVICE_NAME（🆕 不经过 dt_unit）
    --   链路：dm_non.PLANT_NAME → pmm_unit.DEVICE_NAME（直接）
    -- ================================================================
    LEFT JOIN pmm_unit u3 ON u3.DEVICE_NAME = p.PLANT_NAME
        AND u3.START_VERSION <= ver.version
        AND u3.END_VERSION   >= ver.version
        AND u3.START_VERSION = (
            SELECT MAX(u_inner.START_VERSION)
            FROM pmm_unit u_inner
            WHERE u_inner.CIM_ID = u3.CIM_ID
              AND u_inner.START_VERSION <= ver.version
              AND u_inner.END_VERSION   >= ver.version
        )

    -- ================================================================
    -- 第4级：PLANT_NAME+DEVICE_NAME 精确匹配 dt_unit（方式②）
    --   链路：dm_non.(PLANT_NAME+DEVICE_NAME) → dt_unit.(PLANT_NAME+UNIT_NAME) → CIM_ID → pmm_unit
    -- ================================================================
    LEFT JOIN dt_unit d4 ON d4.PLANT_NAME = p.PLANT_NAME
                        AND d4.UNIT_NAME  = p.DEVICE_NAME
    LEFT JOIN pmm_unit u4 ON u4.CIM_ID = d4.CIM_ID
        AND u4.START_VERSION <= ver.version
        AND u4.END_VERSION   >= ver.version
        AND u4.START_VERSION = (
            SELECT MAX(u_inner.START_VERSION)
            FROM pmm_unit u_inner
            WHERE u_inner.CIM_ID = u4.CIM_ID
              AND u_inner.START_VERSION <= ver.version
              AND u_inner.END_VERSION   >= ver.version
        )

    -- ================================================================
    -- 第5级：DEVICE_NAME 直匹配 pmm_unit.DEVICE_NAME（🆕 不经过 dt_unit）
    --   链路：dm_non.DEVICE_NAME → pmm_unit.DEVICE_NAME（直接）
    -- ================================================================
    LEFT JOIN pmm_unit u5 ON u5.DEVICE_NAME = p.DEVICE_NAME
        AND u5.START_VERSION <= ver.version
        AND u5.END_VERSION   >= ver.version
        AND u5.START_VERSION = (
            SELECT MAX(u_inner.START_VERSION)
            FROM pmm_unit u_inner
            WHERE u_inner.CIM_ID = u5.CIM_ID
              AND u_inner.START_VERSION <= ver.version
              AND u_inner.END_VERSION   >= ver.version
        )

    -- 至少一级匹配成功才保留（全 NULL = 5 级均未命中，跳过）
    WHERE COALESCE(
        u1.DEVICE_ID, u2.DEVICE_ID, u3.DEVICE_ID, u4.DEVICE_ID, u5.DEVICE_ID
    ) IS NOT NULL

) src ON t.PLANT_NAME = src.PLANT_NAME AND t.DEVICE_NAME = src.DEVICE_NAME

SET
    t.DEVICE_ID   = src.new_device_id,
    t.DEVICE_NAME = src.new_device_name,
    t.PLANT_ID    = src.new_plant_id,
    t.PLANT_NAME  = src.new_plant_name,
    t.UPDATE_TIME = NOW();

-- ========================================
-- 第3步（可选）：查看未匹配的行（5级均未命中）
-- ========================================
-- SELECT PLANT_NAME, DEVICE_NAME, DEVICE_ID
-- FROM dm_non_market_unit_plan
-- WHERE DEVICE_ID IS NULL
--    OR DEVICE_ID = ''
--    OR UPDATE_TIME < DATE_SUB(NOW(), INTERVAL 1 MINUTE);
