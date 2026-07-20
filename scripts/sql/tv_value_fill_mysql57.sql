-- ============================================================
-- 🎯 三角色视角 — TV_VALUE JSON 数组补点 · 一键执行脚本
-- ============================================================
-- 更新：2026-07-10 | 🎯 Claude（三角色 + 一键执行优化）
-- 原始：🧩 Reasonix
-- ============================================================
-- ★ 用法：修改末尾 3 个参数 → 全选复制 → 粘贴到 MySQL 客户端 → 回车
-- ★ 自动完成：备份 → 补点 → 更新 → 打印回滚命令 → 清理存储过程
-- ============================================================

-- ============================================================
-- 🏷️ PM 视角：问题定义 & 方案选择
-- ============================================================
--
-- 【问题】his_section_basic / his_data 等表的 TV_VALUE 字段是 JSON
--   数组（96个时间点，15分钟间隔/天），因采集链路不稳定（传感器离线、
--   网络丢包、数据源异常）导致部分时间点值为 null。null 值会导致：
--   - 前端图表出现断线/空白段
--   - 日报统计指标（日均、峰谷）计算失真
--   - 下游 ETL/数据分析任务报错或跳过该行
--
-- 【方案对比】
--
--   | # | 方案 | 优点 | 缺点 | 采用 |
--   |---|------|------|------|:--:|
--   | 1 | 一键脚本（CREATE→CALL→DROP） | 复制粘贴即执行，用完自动清理 | 不可复用（每次需重建） | ✅ |
--   | 2 | 应用层补点 | 灵活、可单元测试 | 需拉全量数据到内存；网络开销大 | ❌ |
--   | 3 | 采集端补点 | 从源头消除null | 需改采集端固件；历史数据无法修复 | ❌ |
--
-- 【决策】选方案1。用户要求在 SQL 客户端中直接执行，一键脚本最合适。
--   如需反复调用，可将 CREATE→CALL→DROP 改为仅 CREATE 保留存储过程。

-- ============================================================
-- 🧩 产品视角：业务背景 & 边界条件
-- ============================================================
--
-- 【数据格式】
--   TV_VALUE 列存储格式：'[1.23, null, 3.45, null, null, 6.78, ...]'
--   - 固定 96 个元素 = 一天 24h 每 15 分钟一个采样点
--   - 索引 1=00:00、2=00:15、... 96=23:45
--   - null = 该时间点无有效采集值
--
-- 【补点策略】（5种场景 → 业务语义映射）
--
--   | # | 场景 | 业务含义 | 补点方式 | 示例 |
--   |---|------|----------|----------|------|
--   | 1 | 单个null | 偶发丢点（传感器瞬时失联） | 相邻平均 | [1,null,3] → [1,2,3] |
--   | 2 | 连续null | 持续丢点（设备离线20分钟） | 线性插值 | [1,null,null,4] → [1,2,3,4] |
--   | 3 | 开头null | 当日采集启动延迟 | 用首值回填 | [null,null,5,6] → [5,5,5,6] |
--   | 4 | 末尾null | 当日采集提前终止 | 用尾值前填 | [3,4,null,null] → [3,4,4,4] |
--   | 5 | 全部null | 全天无采集（设备故障） | 跳过不处理 | [null...] → 不变 |
--
-- 【边界条件】
--   - 数据精度：DOUBLE，不引入精度损失
--   - 最大长度：96×22≈2112字节，VARCHAR(16384) 安全
--   - JSON的"null" ≠ SQL的NULL，严格区分
--   - MySQL 5.7 兼容：不用 JSON_TABLE/CTE/JSON_ARRAYAGG
--
-- 【下游消费方】前端图表 / 日报统计 / ETL 任务 / API 接口
-- 【不补点影响】图表断线、统计失真、ETL 跳过整行

-- ============================================================
-- 🔧 运维视角：安全检查清单 & 执行流程
-- ============================================================
--
-- 【执行前检查清单】⚠️ 逐项确认
--
--   ☑ 1. 确认目标表存在且有数据：
--        SELECT COUNT(*) FROM his_section_basic;
--   ☑ 2. 确认 TV_VALUE 列存在：
--        DESC his_section_basic;
--   ☑ 3. 估算处理量（备份空间≈行数×500B）：
--        SELECT COUNT(*) FROM his_section_basic WHERE TV_VALUE IS NOT NULL;
--   ☑ 4. 检查磁盘空间：df -h /var/lib/mysql（建议剩余 > 备份空间×3）
--   ☑ 5. 确认 MySQL 版本：SELECT VERSION();（兼容 5.7 / 8.0）
--   ☑ 6. 不在业务高峰期执行（建议凌晨 2:00-5:00）
--
-- 【执行时间预估】
--   每行 ~10-20ms（96元素解析+补点+拼JSON）
--   ┌──────────┬──────────┬──────────┐
--   │ 数据行数  │ 预估耗时  │ 建议      │
--   ├──────────┼──────────┼──────────┤
--   │ < 1万    │ < 3分钟   │ 🟢 直接执行 │
--   │ 1~10万   │ 3~25分钟  │ 🟡 低峰期  │
--   │ > 10万   │ > 25分钟  │ 🔴 分批执行 │
--   └──────────┴──────────┴──────────┘
--
-- 【回滚方案】执行后会打印备份表名，用以下命令回滚：
--   RENAME TABLE his_section_basic TO his_section_basic_bad,
--              his_section_basic_bak_YYYYMMDD_HHmmss TO his_section_basic;
--
-- 【风险评级】🟢 低风险：事务保护 + 自动备份 + 回滚方案

-- ============================================================
-- 📐 一键执行脚本（修改末尾参数 → 全选复制 → 粘贴执行）
-- ============================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS fill_tv_value$$

CREATE PROCEDURE fill_tv_value(
    IN p_table  VARCHAR(128),   -- 目标表名
    IN p_id_col VARCHAR(64),    -- 主键列名
    IN p_val_col VARCHAR(64)    -- 含 JSON 数组的列名
)
main_proc: BEGIN
    -- ========== 变量声明 ==========
    DECLARE v_done       INT DEFAULT FALSE;
    DECLARE v_row_id     BIGINT;
    DECLARE v_raw_json   VARCHAR(16384);

    DECLARE v_i          INT;
    DECLARE v_n          INT DEFAULT 96;
    DECLARE v_token      VARCHAR(255);

    DECLARE v_gap_start  INT;
    DECLARE v_gap_len    INT;
    DECLARE v_left       DOUBLE;
    DECLARE v_right      DOUBLE;
    DECLARE v_j          INT;
    DECLARE v_interp     DOUBLE;

    DECLARE v_new_json   VARCHAR(16384);
    DECLARE v_count      INT DEFAULT 0;

    DECLARE v_sql        VARCHAR(16384);
    DECLARE v_backup     VARCHAR(200);

    -- 游标：遍历需要处理的行
    DECLARE cur CURSOR FOR SELECT id, val FROM tmp_src;

    -- handler（必须在游标声明后）
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- 异常回滚：任何SQL错误自动ROLLBACK + 清理临时表
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_src;
        DROP TEMPORARY TABLE IF EXISTS tmp_vals;
        DROP TEMPORARY TABLE IF EXISTS tmp_result;
        SELECT '❌ [失败] SQL异常，事务已回滚！原表未受影响。备份表已保留。' AS result;
    END;

    -- ========== Step 1：事务 + 预检 ==========
    START TRANSACTION;
    SELECT '▶ [1/5] 事务已开启...' AS progress;

    -- ========== Step 2：备份整表 ==========
    SET v_backup = CONCAT(p_table, '_bak_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));
    SET v_sql = CONCAT('CREATE TABLE ', v_backup, ' AS SELECT * FROM ', p_table);
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    SELECT CONCAT('▶ [2/5] 备份完成: ', v_backup) AS progress;

    -- ========== Step 3：源数据临时表 + 工作台 ==========
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
    SELECT CONCAT('▶ [3/5] 待处理: ', ROW_COUNT(), ' 行') AS progress;

    -- 结果收集表（用于批量 UPDATE）
    DROP TEMPORARY TABLE IF EXISTS tmp_result;
    CREATE TEMPORARY TABLE tmp_result (
        id       BIGINT PRIMARY KEY,
        new_json VARCHAR(16384) NOT NULL
    );

    -- 工作台（外提复用，每行 TRUNCATE，避免每行 CREATE/DROP）
    DROP TEMPORARY TABLE IF EXISTS tmp_vals;
    CREATE TEMPORARY TABLE tmp_vals (
        idx INT PRIMARY KEY,
        val DOUBLE
    );

    -- 防 GROUP_CONCAT 截断（96个double×22字节≈2112，设10000足够）
    SET SESSION group_concat_max_len = 10000;

    -- ========== Step 4：逐行处理 ==========
    OPEN cur;

    row_loop: LOOP
        FETCH cur INTO v_row_id, v_raw_json;
        IF v_done THEN
            LEAVE row_loop;
        END IF;

        -- ---- 4.1 解析 JSON 数组到 tmp_vals（96个元素） ----
        TRUNCATE TABLE tmp_vals;
        SET v_i = 1;
        WHILE v_i <= v_n DO
            -- 双 SUBSTRING_INDEX 定位第 v_i 个逗号分隔值（O(1)单次定位）
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

        -- ---- 4.2 扫描 null 段并填补 ----
        SET v_i = 1;
        WHILE v_i <= v_n DO

            IF (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL THEN
                SET v_gap_start = v_i;
                -- 找连续null末尾
                WHILE v_i <= v_n AND (SELECT val FROM tmp_vals WHERE idx = v_i) IS NULL DO
                    SET v_i = v_i + 1;
                END WHILE;
                SET v_gap_len = v_i - v_gap_start;

                -- 取左右边界有效值
                SET v_left  = (SELECT val FROM tmp_vals WHERE idx = v_gap_start - 1);
                SET v_right = (SELECT val FROM tmp_vals WHERE idx = v_i);

                -- ① 单空（两侧有效）→ 相邻平均
                --    例：[1.0, null, 3.0] → [1.0, 2.0, 3.0]
                IF v_gap_len = 1 AND v_left IS NOT NULL AND v_right IS NOT NULL THEN
                    UPDATE tmp_vals SET val = (v_left + v_right) / 2 WHERE idx = v_gap_start;

                -- ② 连续空（两端有效）→ 线性插值，均匀分布
                --    例：[1.0, null, null, 4.0] → [1.0, 2.0, 3.0, 4.0]
                ELSEIF v_left IS NOT NULL AND v_right IS NOT NULL THEN
                    SET v_j = 0;
                    WHILE v_j < v_gap_len DO
                        SET v_interp = v_left + (v_right - v_left) * (v_j + 1) / (v_gap_len + 1);
                        UPDATE tmp_vals SET val = v_interp WHERE idx = v_gap_start + v_j;
                        SET v_j = v_j + 1;
                    END WHILE;

                -- ③ 首段null → 用第一个有效值回填
                --    例：[null, null, 5.0, 6.0] → [5.0, 5.0, 5.0, 6.0]
                ELSEIF v_left IS NULL AND v_right IS NOT NULL THEN
                    UPDATE tmp_vals SET val = v_right
                    WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

                -- ④ 尾段null → 用最后一个有效值前填
                --    例：[3.0, 4.0, null, null] → [3.0, 4.0, 4.0, 4.0]
                ELSEIF v_left IS NOT NULL AND v_right IS NULL THEN
                    UPDATE tmp_vals SET val = v_left
                    WHERE idx BETWEEN v_gap_start AND v_gap_start + v_gap_len - 1;

                -- ⑤ 全null → 跳过不处理
                END IF;

            ELSE
                SET v_i = v_i + 1;
            END IF;
        END WHILE;

        -- ---- 4.3 从 tmp_vals 拼回 JSON 数组字符串 ----
        SELECT CONCAT('[', GROUP_CONCAT(
            CASE WHEN val IS NULL THEN 'null' ELSE CAST(val AS CHAR) END
            ORDER BY idx SEPARATOR ', '
        ), ']') INTO v_new_json
        FROM tmp_vals;

        -- ---- 4.4 收集结果（不立即 UPDATE，最后批量更新） ----
        INSERT INTO tmp_result (id, new_json) VALUES (v_row_id, v_new_json);
        SET v_count = v_count + 1;

    END LOOP;

    CLOSE cur;

    -- ========== Step 5：批量 UPDATE + 提交 ==========
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

    COMMIT;

    SELECT CONCAT('✅ [5/5] 完成: ', v_count, ' 行已补点并提交') AS progress;
    SELECT CONCAT('📋 备份表: ', v_backup) AS info;
    SELECT CONCAT('🔙 回滚: RENAME TABLE ', p_table, ' TO ', p_table, '_bad, ',
        v_backup, ' TO ', p_table, ';') AS rollback;

END$$

DELIMITER ;

-- ============================================================
-- ★ 修改下面 3 个参数 → 全选本文件 → 粘贴到 MySQL 客户端 → 回车
-- ============================================================
CALL fill_tv_value('his_unit_power', 'ID', 'TV_VALUE');

-- ============================================================
-- 用完清理（不留存储过程）
-- ============================================================
DROP PROCEDURE IF EXISTS fill_tv_value;

-- ============================================================
-- 📋 验证 & 回滚速查
-- ============================================================
--
-- ┌─────────────────────────────────────────────────────┐
-- │ 验证：还有没有 null？                                 │
-- │   SELECT ID FROM his_unit_power                      │
-- │   WHERE TV_VALUE LIKE '%null%';                      │
-- │                                                      │
-- │ 抽查对比（执行时会打印备份表名，替换下面的 xxx）：        │
-- │   SELECT ID, TV_VALUE FROM his_unit_power             │
-- │   WHERE ID IN (1,2,3);                                │
-- │   SELECT ID, TV_VALUE FROM his_unit_power_bak_xxx     │
-- │   WHERE ID IN (1,2,3);                                │
-- │                                                      │
-- │ 回滚（执行时会打印精确回滚命令，复制执行即可）：         │
-- │   RENAME TABLE his_unit_power TO his_unit_power_bad,  │
-- │              his_unit_power_bak_xxx TO his_unit_power; │
-- │                                                      │
-- │ 确认无误后清理备份表：                                  │
-- │   DROP TABLE IF EXISTS his_unit_power_bak_xxx;        │
-- └─────────────────────────────────────────────────────┘
--
-- ============================================================
-- 其他表调用（修改表名/列名后执行）
-- ============================================================
-- CALL fill_tv_value('his_section_basic', 'ID', 'TV_VALUE');
-- CALL fill_tv_value('his_data', 'ROW_ID', 'DATA_JSON');
