-- ============================================================
-- 名称：实际值全零修复 — 用预测值替换全零行（动态SQL优化版）
-- 说明：his_tilein_power（实际值）偶尔出现 96 点全为 0 的情况，
--       通过 TIELIN_ID + DATA_TIME 匹配 glb_plan_tilein_power（预测值），
--       将全零行的 96 个时间点替换为对应的预测值，
--       同时更新 T0000~T2345 列和 TV_VALUE JSON 字段。
-- 适用：MySQL 5.7+ | 离线服务器
-- 安全：事务 + 备份表 + 预览 + 无匹配行检测 + 五步确认
-- 优化：动态SQL自动生成96列，消除硬编码，含NULL处理
-- 生成时间：20260717
-- ============================================================

-- ========================================
-- 第0步：环境设置（关键！）
-- ========================================
-- 96列动态SQL约需 3500~5000 字符，默认 group_concat_max_len=1024 会截断
SET SESSION group_concat_max_len = 10240;

-- ========================================
-- 第1步：备份表
-- ========================================
DROP TABLE IF EXISTS his_tilein_power_bak_20260717;
CREATE TABLE his_tilein_power_bak_20260717 LIKE his_tilein_power;
INSERT INTO his_tilein_power_bak_20260717 SELECT * FROM his_tilein_power;
SELECT CONCAT('✅ 备份完成，共 ', COUNT(*), ' 行') AS 备份结果 FROM his_tilein_power_bak_20260717;

-- ========================================
-- 第2步：动态生成 96 列片段（一次生成，全程复用）
-- ========================================

-- 2a. SET 子句：h.T0000 = COALESCE(p.T0000, 0), h.T0015 = COALESCE(p.T0015, 0), ...
SELECT GROUP_CONCAT(
    CONCAT('h.`', COLUMN_NAME, '` = COALESCE(p.`', COLUMN_NAME, '`, 0)')
    ORDER BY COLUMN_NAME
    SEPARATOR ', '
) INTO @set_cols
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'his_tilein_power'
  AND COLUMN_NAME REGEXP '^T[0-9]{4}$';

-- 2b. WHERE 子句：COALESCE(h.T0000, 0) = 0 AND COALESCE(h.T0015, 0) = 0 AND ...
-- 使用 COALESCE 而非直接 = 0，确保 NULL 列也被识别为"零值"
SELECT GROUP_CONCAT(
    CONCAT('COALESCE(h.`', COLUMN_NAME, '`, 0) = 0')
    ORDER BY COLUMN_NAME
    SEPARATOR ' AND '
) INTO @where_cols
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'his_tilein_power'
  AND COLUMN_NAME REGEXP '^T[0-9]{4}$';

-- 2c. 校验列数（应该是96列 = 24h × 4点/h）
SELECT
    CHAR_LENGTH(@set_cols)   - CHAR_LENGTH(REPLACE(@set_cols,   ',', '')) + 1 AS 动态生成列数,
    CHAR_LENGTH(@where_cols) - CHAR_LENGTH(REPLACE(@where_cols, 'AND', '')) + 1 AS 条件列数;

-- ========================================
-- 第3步：预览影响范围
-- ========================================

-- 3a. 全零行总数
SET @sql = CONCAT('SELECT COUNT(*) AS 待修复全零行数 FROM his_tilein_power h WHERE ', @where_cols);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3b. 预览前10条（显示首/中/尾3个时间点 + TV_VALUE）
SET @sql = CONCAT(
    'SELECT h.ID, h.DATA_TIME, h.TIELIN_ID, ',
    'h.T0000 AS 实际_T0000, p.T0000 AS 预测_T0000, ',
    'h.T1200 AS 实际_T1200, p.T1200 AS 预测_T1200, ',
    'h.T2345 AS 实际_T2345, p.T2345 AS 预测_T2345, ',
    'h.TV_VALUE AS 实际_TV_VALUE, p.TV_VALUE AS 预测_TV_VALUE ',
    'FROM his_tilein_power h ',
    'JOIN glb_plan_tilein_power p ON h.TIELIN_ID = p.TIELIN_ID AND h.DATA_TIME = p.DATA_TIME ',
    'WHERE ', @where_cols, ' LIMIT 10'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 3c. 无匹配行统计（全零但在预测表中找不到对应记录，需人工处理）
SET @sql = CONCAT(
    'SELECT COUNT(*) AS 无匹配行数_需人工处理 ',
    'FROM his_tilein_power h ',
    'LEFT JOIN glb_plan_tilein_power p ON h.TIELIN_ID = p.TIELIN_ID AND h.DATA_TIME = p.DATA_TIME ',
    'WHERE (', @where_cols, ') AND p.TIELIN_ID IS NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ⚠️ 确认上述数据无误后再执行第4步 ⚠️

-- ========================================
-- 第4步：执行修复（事务内，可回滚）
-- ========================================
START TRANSACTION;

SET @sql = CONCAT(
    'UPDATE his_tilein_power h ',
    'JOIN glb_plan_tilein_power p ON h.TIELIN_ID = p.TIELIN_ID AND h.DATA_TIME = p.DATA_TIME ',
    'SET ', @set_cols, ', h.TV_VALUE = p.TV_VALUE ',
    'WHERE ', @where_cols
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT ROW_COUNT() AS 已修复行数;

-- ========================================
-- 第5步：验证（综合报告）
-- ========================================

-- 5a. 剩余全零行（应为0）
SET @sql = CONCAT('SELECT COUNT(*) AS 剩余全零行数 FROM his_tilein_power h WHERE ', @where_cols);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 5b. TV_VALUE 异常（应为0）
SELECT COUNT(*) AS TV_VALUE异常行数
FROM his_tilein_power h
WHERE h.TV_VALUE IS NULL OR h.TV_VALUE = '[]';

-- 👆 如果 5a 和 5b 两个结果都是 0 → 可以 COMMIT
-- 👆 如果任意一个 > 0           → 应该 ROLLBACK 排查

-- ------------------------------------------------
-- ✅ 确认无误：选中 COMMIT 执行
-- ❌ 数据有误：选中 ROLLBACK 执行
-- ------------------------------------------------
-- COMMIT;
-- ROLLBACK;

-- ========================================
-- 紧急回滚（如果 COMMIT 后发现错了）
-- ========================================
-- DROP TABLE IF EXISTS his_tilein_power;
-- RENAME TABLE his_tilein_power_bak_20260717 TO his_tilein_power;
