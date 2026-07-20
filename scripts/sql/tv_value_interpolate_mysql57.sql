-- ============================================================
-- TV_VALUE JSON 数组补点 — 一键执行脚本 (MySQL 5.7)
-- 作者：🔷 DeepCode | 日期：2026-07-10
--
-- 用法：复制本文件全部内容 → 粘贴到 MySQL 客户端 → 回车执行
--       只需修改末尾三行参数：表名、ID列名、TV_VALUE列名
--       执行完自动清理，不留存储过程
-- ============================================================
-- 数据格式：[1.2, null, 3.5, null, null, 6.0, ...] 共96个时间点
-- 补点规则：
--   ① 单空（两侧有效） → 取平均
--   ② 连续空（两端有效）→ 线性插值均匀分布
--   ③ 首段null → 用第一个有效值回填
--   ④ 尾段null → 用最后一个有效值回填
--   ⑤ 整行全null → 跳过不处理
-- ============================================================

DELIMITER $$

-- ============================================================
-- 创建存储过程（用完即删）
-- ============================================================
DROP PROCEDURE IF EXISTS tv_value_interpolate$$

CREATE PROCEDURE tv_value_interpolate(
    IN p_table  VARCHAR(128),   -- 目标表名
    IN p_id_col VARCHAR(64),    -- 主键列名
    IN p_val_col VARCHAR(64)    -- JSON 数组列名
)
main: BEGIN
    -- ===================== 变量声明 =====================
    DECLARE v_done       INT DEFAULT FALSE;       -- 游标结束标记
    DECLARE v_row_id     BIGINT;                  -- 当前行主键
    DECLARE v_raw_json   VARCHAR(16384);          -- 当前行原始 JSON

    DECLARE v_i          INT;                     -- 循环计数器（1~96）
    DECLARE v_n          INT DEFAULT 96;          -- 96个时间点/天
    DECLARE v_token      VARCHAR(255);            -- 单个解析出的值

    DECLARE v_gap_start  INT;                     -- null段起始位置
    DECLARE v_gap_len    INT;                     -- null段长度
    DECLARE v_left       DOUBLE;                  -- null段左侧有效值
    DECLARE v_right      DOUBLE;                  -- null段右侧有效值
    DECLARE v_j          INT;                     -- 插值循环计数器
    DECLARE v_interp     DOUBLE;                  -- 线性插值结果

    DECLARE v_new_json   VARCHAR(16384);          -- 补点后 JSON
    DECLARE v_count      INT DEFAULT 0;           -- 处理行计数

    DECLARE v_sql        VARCHAR(16384);          -- 动态 SQL 缓冲区
    DECLARE v_backup     VARCHAR(200);            -- 备份表名

    -- 游标：仅取有数据的行
    DECLARE cur CURSOR FOR SELECT id, val FROM tmp_src;

    -- handler（必须在游标声明后）
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- 异常回滚 handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_src;
        DROP TEMPORARY TABLE IF EXISTS tmp_vals;
        DROP TEMPORARY TABLE IF EXISTS tmp_result;
        SELECT '❌ [失败] 事务已回滚，原表未受影响' AS result;
    END;

    -- ===================== Step 1：事务开始 =====================
    START TRANSACTION;
    SELECT '▶ 事务已开启...' AS step;

    -- Step 2：备份整表
    SET v_backup = CONCAT(p_table, '_bak_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));
    SET v_sql = CONCAT('CREATE TABLE ', v_backup, ' AS SELECT * FROM ', p_table);
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('▶ 备份完成: ', v_backup) AS step;

    -- Step 3：源数据临时表
    DROP TEMPORARY TABLE IF EXISTS tmp_src;
    SET v_sql = CONCAT(
        'CREATE TEMPORARY TABLE tmp_src AS SELECT ',
        p_id_col, ' AS id, ', p_val_col, ' AS val FROM ', p_table,
        ' WHERE ', p_val_col, ' IS NOT NULL'
    );
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('▶ 待处理: ', ROW_COUNT(), ' 行') AS step;

    -- Step 4：工作台（tmp_vals）和结果收集表（tmp_result）
    DROP TEMPORARY TABLE IF EXISTS tmp_result;
    CREATE TEMPORARY TABLE tmp_result (
        id       BIGINT PRIMARY KEY,
        new_json VARCHAR(16384) NOT NULL
    );

    DROP TEMPORARY TABLE IF EXISTS tmp_vals;
    CREATE TEMPORARY TABLE tmp_vals (
        idx INT PRIMARY KEY,
        val DOUBLE
    );

    -- 防 GROUP_CONCAT 截断（96个值 ≈ 2200字符，10000足够）
    SET SESSION group_concat_max_len = 10000;

    -- ===================== Step 5：逐行处理 =====================
    OPEN cur;

    row_loop: LOOP
        FETCH cur INTO v_row_id, v_raw_json;
        IF v_done THEN
            LEAVE row_loop;
        END IF;

        -- ---- 5.1 解析 JSON → tmp_vals ----
        TRUNCATE TABLE tmp_vals;
        SET v_i = 1;
        WHILE v_i <= v_n DO
            -- 双 SUBSTRING_INDEX 定位第 i 个逗号分隔的值
            SET v_token = TRIM(SUBSTRING_INDEX(
                SUBSTRING_INDEX(TRIM(BOTH '[] ' FROM v_raw_json), ',', v_i),
                ',', -1
            ));
            IF v_token = 'null' OR v_token = 'NULL' OR v_token = '' OR v_token IS NULL THEN
                INSERT INTO tmp_vals (idx, val) VALUES (v_i, NULL);
            ELSE
                INSERT INTO tmp_vals (idx, val) VALUES (v_i, CAST(v_token AS DOUBLE));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- ---- 5.2 扫描 null 段并填补 ----
        SET v_i = 1;
        WHILE v_i <= v_n DO

            IF (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL THEN
                SET v_gap_start = v_i;
                -- 找连续 null 末尾
                WHILE v_i <= v_n AND (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL DO
                    SET v_i = v_i + 1;
                END WHILE;
                SET v_gap_len = v_i - v_gap_start;

                -- 取左右边界有效值
                SET v_left  = (SELECT val FROM tmp_vals WHERE idx = v_gap_start - 1);
                SET v_right = (SELECT val FROM tmp_vals WHERE idx = v_i);

                -- ① 单空 → 取平均
                IF v_gap_len = 1 AND v_left IS NOT NULL AND v_right IS NOT NULL THEN
                    UPDATE tmp_vals SET val = (v_left + v_right) / 2 WHERE idx = v_gap_start;

                -- ② 连续空 → 线性插值
                ELSEIF v_left IS NOT NULL AND v_right IS NOT NULL THEN
                    SET v_j = 0;
                    WHILE v_j < v_gap_len DO
                        SET v_interp = v_left + (v_right - v_left) * (v_j + 1) / (v_gap_len + 1);
                        UPDATE tmp_vals SET val = v_interp WHERE idx = v_gap_start + v_j;
                        SET v_j = v_j + 1;
                    END WHILE;

                -- ③ 首段null → 用右侧第一个值回填
                ELSEIF v_left IS NULL AND v_right IS NOT NULL THEN
                    UPDATE tmp_vals SET val = v_right
                    WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

                -- ④ 尾段null → 用左侧最后一个值回填
                ELSEIF v_left IS NOT NULL AND v_right IS NULL THEN
                    UPDATE tmp_vals SET val = v_left
                    WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

                -- ⑤ 整行全null → 不管
                END IF;

            ELSE
                SET v_i = v_i + 1;
            END IF;
        END WHILE;

        -- ---- 5.3 从 tmp_vals 拼回 JSON 字符串 ----
        SELECT CONCAT('[', GROUP_CONCAT(
            CASE WHEN val IS NULL THEN 'null' ELSE CAST(val AS CHAR) END
            ORDER BY idx SEPARATOR ', '
        ), ']') INTO v_new_json
        FROM tmp_vals;

        -- ---- 5.4 收集到结果表（不立即 UPDATE） ----
        INSERT INTO tmp_result (id, new_json) VALUES (v_row_id, v_new_json);
        SET v_count = v_count + 1;

    END LOOP;

    CLOSE cur;

    -- ===================== Step 6：一次性批量 UPDATE =====================
    IF v_count > 0 THEN
        SET v_sql = CONCAT(
            'UPDATE ', p_table, ' t JOIN tmp_result r ON t.', p_id_col, ' = r.id',
            ' SET t.', p_val_col, ' = r.new_json'
        );
        SET @sql = v_sql;
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;

    -- 清理临时表
    DROP TEMPORARY TABLE IF EXISTS tmp_src;
    DROP TEMPORARY TABLE IF EXISTS tmp_vals;
    DROP TEMPORARY TABLE IF EXISTS tmp_result;

    -- 提交
    COMMIT;

    SELECT CONCAT('✅ 完成: ', v_count, ' 行已补点并提交') AS result;

END$$

DELIMITER ;

-- ============================================================
-- ★ 修改下面三个参数，然后复制整个文件到 MySQL 客户端执行 ★
-- ============================================================
CALL tv_value_interpolate('his_section_basic', 'ID', 'TV_VALUE');

-- ============================================================
-- 用完清理（不留存储过程）
-- ============================================================
DROP PROCEDURE IF EXISTS tv_value_interpolate;

-- ============================================================
-- 验证：检查还有没有 null
--   SELECT ID FROM his_section_basic WHERE TV_VALUE LIKE '%null%';
-- 
-- 回滚：
--   RENAME TABLE his_section_basic TO his_section_basic_bad;
--   RENAME TABLE his_section_basic_bak_XXXXXXXX_XXXXXX TO his_section_basic;
--   （备份表名执行时会打印）
-- ============================================================
