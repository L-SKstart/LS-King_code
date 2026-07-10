-- ============================================================
-- fill_tv_value() — TV_VALUE JSON 数组补点存储过程 (MySQL 5.7)
-- 用途：将 JSON 数组中 null 值用插值填补
-- 数据格式：[1.2, null, 3.5, ...] 共96个时间点（15分钟间隔/天）
-- 补点逻辑：
--   单空(null)        → 相邻两有效值取平均
--   连续空(null,null) → 首尾有效值之间线性插值（均匀分布）
--   首段为null        → 用第一个有效值填充
--   尾段为null        → 用最后一个有效值填充
-- 兼容：MySQL 5.7（不用 JSON_TABLE / CTE / JSON_ARRAYAGG）
-- 安全：执行前自动备份目标表
-- ============================================================

DELIMITER $$

-- ============================================================
-- 辅助函数：从 JSON 数组字符串中提取第 pos 个元素（1-based）
-- 例：json_extract_nth('[1.2, null, 3.5]', 2) → 'null'
-- ============================================================
DROP FUNCTION IF EXISTS json_extract_nth$$

CREATE FUNCTION json_extract_nth(
    p_json VARCHAR(16384),  -- JSON 数组字符串
    p_pos  INT              -- 位置（1-based）
) RETURNS VARCHAR(255)
    DETERMINISTIC
    READS SQL DATA
BEGIN
    DECLARE v_trimmed VARCHAR(16384);   -- 去首尾[]后的内容
    DECLARE v_result  VARCHAR(255);
    DECLARE v_i       INT DEFAULT 1;
    DECLARE v_cur     VARCHAR(16384);

    -- 去首尾空格和 []
    SET v_trimmed = TRIM(BOTH '[] ' FROM p_json);
    SET v_cur = v_trimmed;

    -- 逐段截取（按逗号分隔）
    WHILE v_i < p_pos AND v_cur != '' DO
        -- 找到下一个逗号位置
        IF LOCATE(',', v_cur) > 0 THEN
            SET v_cur = SUBSTRING(v_cur, LOCATE(',', v_cur) + 1);
        ELSE
            SET v_cur = '';
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    -- 提取当前段
    IF LOCATE(',', v_cur) > 0 THEN
        SET v_result = TRIM(SUBSTRING(v_cur, 1, LOCATE(',', v_cur) - 1));
    ELSE
        SET v_result = TRIM(v_cur);
    END IF;

    RETURN v_result;
END$$

-- ============================================================
-- 辅助函数：将 JSON 数组第 pos 个元素替换为新值，返回新 JSON 字符串
-- ============================================================
DROP FUNCTION IF EXISTS json_replace_nth$$

CREATE FUNCTION json_replace_nth(
    p_json   VARCHAR(16384),  -- 原始 JSON 数组
    p_pos    INT,             -- 位置（1-based）
    p_newval VARCHAR(255)     -- 新值（数值或 'null'）
) RETURNS VARCHAR(16384)
    DETERMINISTIC
    READS SQL DATA
BEGIN
    DECLARE v_result  VARCHAR(16384) DEFAULT '';
    DECLARE v_i       INT DEFAULT 1;
    DECLARE v_part    VARCHAR(255);
    DECLARE v_work    VARCHAR(16384);
    DECLARE v_comma   INT;

    -- 去首尾 []
    SET v_work = TRIM(BOTH '[] ' FROM p_json);

    -- 遍历重组
    WHILE v_i <= 96 DO
        -- 提取当前位置的值
        IF LOCATE(',', v_work) > 0 THEN
            SET v_comma = LOCATE(',', v_work);
            SET v_part = TRIM(SUBSTRING(v_work, 1, v_comma - 1));
            SET v_work = SUBSTRING(v_work, v_comma + 1);
        ELSE
            SET v_part = TRIM(v_work);
            SET v_work = '';
        END IF;

        -- 追加到结果
        IF v_i > 1 THEN
            SET v_result = CONCAT(v_result, ', ');
        END IF;

        IF v_i = p_pos THEN
            SET v_result = CONCAT(v_result, p_newval);
        ELSE
            SET v_result = CONCAT(v_result, IF(v_part = '' OR v_part IS NULL, 'null', v_part));
        END IF;

        SET v_i = v_i + 1;
    END WHILE;

    RETURN CONCAT('[', v_result, ']');
END$$

-- ============================================================
-- 主存储过程：遍历表，对每行 JSON 数组做补点
-- ============================================================
DROP PROCEDURE IF EXISTS fill_tv_value$$

CREATE PROCEDURE fill_tv_value(
    IN p_table_name VARCHAR(128),   -- 目标表名
    IN p_id_col     VARCHAR(64),    -- 主键列名
    IN p_val_col    VARCHAR(64)     -- 含 JSON 数组的列名
)
main_proc: BEGIN
    DECLARE done      INT DEFAULT FALSE;
    DECLARE v_id_val  BIGINT;
    DECLARE v_json_str VARCHAR(16384);
    DECLARE v_new_json VARCHAR(16384);
    DECLARE v_table_backup VARCHAR(200);
    DECLARE v_sql     VARCHAR(16384);

    -- 用于遍历每行的游标（只取有数据的行）
    DECLARE cur CURSOR FOR
        SELECT `id`, `val`
        FROM tmp_tv_rows;

    -- MySQL 5.7 游标必须在所有声明之后，NOT FOUND handler 在最后
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- === 安全第一步：备份整个表 ===
    SET v_table_backup = CONCAT(p_table_name, '_backup_',
        DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));
    SET v_sql = CONCAT('CREATE TABLE ', v_table_backup,
        ' AS SELECT * FROM ', p_table_name);
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('[OK] Backup created: ', v_table_backup) AS msg;

    -- === 准备临时表：筛选需要处理的行 ===
    DROP TEMPORARY TABLE IF EXISTS tmp_tv_rows;
    SET v_sql = CONCAT(
        'CREATE TEMPORARY TABLE tmp_tv_rows AS SELECT ',
        p_id_col, ' AS id, ', p_val_col, ' AS val FROM ', p_table_name,
        ' WHERE ', p_val_col, ' IS NOT NULL'
    );
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- === 遍历每一行 ===
    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_id_val, v_json_str;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- 调用补点核心逻辑（内联处理）
        CALL fill_one_row(v_json_str, v_new_json);

        -- 更新原表
        SET v_sql = CONCAT(
            'UPDATE ', p_table_name,
            ' SET ', p_val_col, ' = ''', v_new_json, '''',
            ' WHERE ', p_id_col, ' = ', v_id_val
        );
        SET @sql = v_sql;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    END LOOP;

    CLOSE cur;
    DROP TEMPORARY TABLE IF EXISTS tmp_tv_rows;

    SELECT CONCAT('[DONE] All rows processed via fill_tv_value') AS msg;
END$$

-- ============================================================
-- 核心：对单行 JSON 数组字符串做补点
-- IN:  [1.2, null, 3.5, null, null, 6.0, ...]
-- OUT: [1.2, 2.35, 3.5, 4.33, 5.17, 6.0, ...]
-- ============================================================
DROP PROCEDURE IF EXISTS fill_one_row$$

CREATE PROCEDURE fill_one_row(
    IN  p_input  VARCHAR(16384),   -- 原始 JSON 数组
    OUT p_output VARCHAR(16384)    -- 补点后的 JSON 数组
)
BEGIN
    DECLARE v_i      INT DEFAULT 1;
    DECLARE v_j      INT;
    DECLARE v_n      INT DEFAULT 96;
    DECLARE v_val    DOUBLE;
    DECLARE v_str    VARCHAR(255);
    DECLARE v_left   DOUBLE;        -- 连续null段左侧有效值
    DECLARE v_right  DOUBLE;        -- 连续null段右侧有效值
    DECLARE v_gap_start INT;        -- null段起始位置
    DECLARE v_gap_len   INT;        -- null段长度
    DECLARE v_interp  DOUBLE;       -- 插值结果

    -- 临时存储96个位置的值（用临时表）
    DROP TEMPORARY TABLE IF EXISTS tmp_vals;
    CREATE TEMPORARY TABLE tmp_vals (
        idx INT PRIMARY KEY,
        val DOUBLE
    );

    -- 解析 JSON 数组到临时表
    SET v_i = 1;
    WHILE v_i <= v_n DO
        SET v_str = json_extract_nth(p_input, v_i);
        IF v_str = 'null' OR v_str = 'NULL' OR v_str IS NULL OR v_str = '' THEN
            INSERT INTO tmp_vals (idx, val) VALUES (v_i, NULL);
        ELSE
            SET v_val = CAST(v_str AS DOUBLE);
            INSERT INTO tmp_vals (idx, val) VALUES (v_i, v_val);
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    -- 补点逻辑：扫描找null段
    SET v_i = 1;
    WHILE v_i <= v_n DO

        -- 当前为null → 找到连续null段
        IF (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL THEN
            SET v_gap_start = v_i;

            -- 找到连续null末尾
            WHILE v_i <= v_n AND (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL DO
                SET v_i = v_i + 1;
            END WHILE;
            SET v_gap_len = v_i - v_gap_start;

            -- 取左边界
            IF v_gap_start > 1 THEN
                SELECT val INTO v_left FROM tmp_vals WHERE idx = v_gap_start - 1;
            ELSE
                SET v_left = NULL;
            END IF;

            -- 取右边界
            IF v_i <= v_n THEN
                SELECT val INTO v_right FROM tmp_vals WHERE idx = v_i;
            ELSE
                SET v_right = NULL;
            END IF;

            -- 情况1：单空 → 相邻平均
            IF v_gap_len = 1 AND v_left IS NOT NULL AND v_right IS NOT NULL THEN
                UPDATE tmp_vals SET val = (v_left + v_right) / 2 WHERE idx = v_gap_start;

            -- 情况2：连续空 → 线性插值
            ELSEIF v_gap_len >= 1 AND v_left IS NOT NULL AND v_right IS NOT NULL THEN
                SET v_j = 0;
                WHILE v_j < v_gap_len DO
                    SET v_interp = v_left + (v_right - v_left) * (v_j + 1) / (v_gap_len + 1);
                    UPDATE tmp_vals SET val = v_interp WHERE idx = v_gap_start + v_j;
                    SET v_j = v_j + 1;
                END WHILE;

            -- 情况3：首段null → 用第一个有效值填充
            ELSEIF v_left IS NULL AND v_right IS NOT NULL THEN
                UPDATE tmp_vals SET val = v_right WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

            -- 情况4：尾段null → 用最后一个有效值填充
            ELSEIF v_left IS NOT NULL AND v_right IS NULL THEN
                UPDATE tmp_vals SET val = v_left WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

            -- 情况5：全是null（整行都null）→ 跳过不处理
            END IF;

        ELSE
            SET v_i = v_i + 1;
        END IF;
    END WHILE;

    -- 从临时表重新拼 JSON 数组字符串
    SELECT CONCAT('[', GROUP_CONCAT(
        CASE WHEN val IS NULL THEN 'null'
             ELSE CAST(val AS CHAR)
        END
        ORDER BY idx SEPARATOR ', '
    ), ']') INTO p_output
    FROM tmp_vals;

    DROP TEMPORARY TABLE IF EXISTS tmp_vals;

END$$

DELIMITER ;

-- ============================================================
-- 调用示例
-- ============================================================
-- CALL fill_tv_value('his_section_basic', 'ID', 'TV_VALUE');
-- CALL fill_tv_value('his_data', 'ROW_ID', 'DATA_JSON');
