-- ============================================================
-- 名称：his_unit_power 机组功率 JSON 数组补点（null + 孤立 0 填充）
-- 说明：将 TV_VALUE JSON 数组中孤立的 null / 突变为 0 的值替换为相邻值的平均数
--       适用于 15 分钟间隔的功率数据（全天 96 个点）
-- 业务背景：每小时全量读取文件重录，滞后时刻点存 null（前端显示为 0），
--           或个别时刻点突变为 0（测量异常），需用相邻值平均补回真实出力值
-- 逻辑：
--   ① 末尾点（23:45）为 null → 用前一个非零值回填
--   ② 内部点（非首尾）为 null → 相邻平均值（前后值均有效且非零）
--   ③ 内部点（非首尾）孤立为 0 → 前后均非零时判定为测量异常，相邻平均替代
--      连续 ≥2 个 0 不处理（视为真实停机）；负数场景同样适用
-- 空值保护：NULLIF('') + NULLIF('null') + 0.0，把空串/"null"字符串/JSON null 统一转为 SQL NULL
-- 性能优化：
--   ① 预过滤含 null 的行（LIKE 字符串检查，避免无效行的 JSON 解析）
--   ② 只生成到数组实际长度（不固定 95）
--   ③ 建议预先加索引：ALTER TABLE his_unit_power ADD INDEX idx_data_time (DATA_TIME);
-- 用法：修改 WHERE 条件中的日期后，直接粘贴到 MySQL 客户端执行
--
-- 【修改记录】
-- ➕ 2026-07-16 L-SKstart：新增孤立 0 填充（前后非零时视为测量异常，相邻平均替代，支持负数场景）
-- 🐛 2026-07-16 L-SKstart：修复 JSON 字符串 "null" 被 +0.0 误转为 0 导致无法补点 — 增加 NULLIF('null') 保护
-- 🔧 2026-07-14 Copilot：简化 LIKE 预过滤（去掉 6 个 OR 条件，只保留 '%null%'），减少全字符串扫描次数
--   v6 (07-14) 🔧 合并版：补null为主 + 兼容补0 + NULLIF保护 + 末尾点填充
--   v5 (07-13 14:27) ➕ 新增末尾点填充（23:45 空值用前一个值回填）
--   v4 (07-13 14:25) 🔧 数字序列 0-287 → 0-95（非288点而是96点）
--   v3 (07-13 14:24) 🚀 新增 LIKE 预过滤 + 索引建议
--   v2 (07-13 14:23) 🐛 去掉外层 CAST(... AS CHAR(10000)) 修复 MySQL 语法报错
--   v1 (07-13)       初始版本，含 CAST(CHAR(10000))
-- ============================================================

UPDATE his_unit_power t
JOIN (
    -- 【子查询 s】遍历每个 ID 的 JSON 数组元素，提取值及前后邻居
    SELECT
        s.ID,
        CONCAT(
            '[',
            GROUP_CONCAT(
                CASE
                    -- 填充条件 A — 末尾点（如 23:45），null 用前一个非零值回填
                    WHEN s.idx = s.arr_len - 1
                        AND s.cur_val IS NULL
                        AND s.prev_val IS NOT NULL
                        AND s.prev_val <> 0
                    THEN CAST(CAST(s.prev_val AS SIGNED) AS CHAR)  -- 用前一个值回填
                    -- 填充条件 B：内部点（非首尾），null 或孤立 0，前后均非零时取相邻平均
                    WHEN s.idx BETWEEN 1 AND s.arr_len - 2
                        AND (s.cur_val IS NULL OR s.cur_val = 0)
                        AND s.prev_val IS NOT NULL
                        AND s.next_val IS NOT NULL
                        AND s.prev_val <> 0
                        AND s.next_val <> 0
                    THEN CAST(CAST((s.prev_val + s.next_val) / 2 AS SIGNED) AS CHAR)  -- 用相邻平均值替代
                    ELSE COALESCE(s.raw_val, 'null')  -- 保持原值（含 null）
                END
                ORDER BY s.idx
                SEPARATOR ','
            ),
            ']'
        ) AS new_tv_value
    FROM (
        -- 【子查询 n】生成 0~N 的数字序列（N=数组长度-1，对应每 15 分钟时点的索引）
        SELECT
            t1.ID,
            JSON_LENGTH(t1.TV_VALUE) AS arr_len,                -- 数组长度（应为 96）
            n.idx,                                               -- 当前元素索引
            JSON_UNQUOTE(JSON_EXTRACT(t1.TV_VALUE, CONCAT('$[', n.idx, ']'))) AS raw_val,          -- 原始值（字符串）
            (NULLIF(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(t1.TV_VALUE, CONCAT('$[', n.idx - 1, ']'))), ''), 'null') + 0.0) AS prev_val,  -- 前一个值（''→null, 'null'→null, JSON null→null）
            (NULLIF(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(t1.TV_VALUE, CONCAT('$[', n.idx, ']'))), ''), 'null') + 0.0) AS cur_val,       -- 当前值（''→null, 'null'→null, JSON null→null）
            (NULLIF(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(t1.TV_VALUE, CONCAT('$[', n.idx + 1, ']'))), ''), 'null') + 0.0) AS next_val   -- 后一个值（''→null, 'null'→null, JSON null→null）
        FROM his_unit_power t1
        JOIN (
            -- 数字序列：2 个 CROSS JOIN 生成 0-99（截取到数组实际长度）
            SELECT a.n + b.n * 10 AS idx
            FROM (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
            ) a
            CROSS JOIN (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
            ) b
            WHERE a.n + b.n * 10 BETWEEN 0 AND 95
        ) n
        WHERE t1.DATA_TIME = '2026-07-10'        -- ⚡ 目标日期，执行前改为实际日期
            AND n.idx < JSON_LENGTH(t1.TV_VALUE)    -- 只遍历到数组实际长度
            AND (                                   -- 预过滤含 null/空串/0 的行（避免无效行的 JSON 解析）
                t1.TV_VALUE LIKE '%null%'             -- 含 JSON null / "null" 字符串
                OR t1.TV_VALUE LIKE '%""%'            -- 含 JSON 空字符串
                OR t1.TV_VALUE LIKE '%,0,%'           -- 含孤立整数 0（中间位置）
                OR t1.TV_VALUE LIKE '%,0]%'           -- 含孤立整数 0（末尾）
                OR t1.TV_VALUE LIKE '%[0,%'           -- 含孤立整数 0（开头）
            )
    ) s
    GROUP BY s.ID
    -- HAVING 过滤：只更新至少有一个 null 被填充的行
    HAVING SUM(
        CASE
            -- 末尾点（用前一个值回填）
            WHEN s.idx = s.arr_len - 1
                AND s.cur_val IS NULL
                AND s.prev_val IS NOT NULL
                AND s.prev_val <> 0
            THEN 1
            -- 内部点（相邻平均 — null 或孤立 0）
            WHEN s.idx BETWEEN 1 AND s.arr_len - 2
                AND (s.cur_val IS NULL OR s.cur_val = 0)
                AND s.prev_val IS NOT NULL
                AND s.next_val IS NOT NULL
                AND s.prev_val <> 0
                AND s.next_val <> 0
            THEN 1
            ELSE 0
        END
    ) > 0
) x
ON t.ID = x.ID
SET t.TV_VALUE = x.new_tv_value     -- 用补点后的新 JSON 数组覆盖原值
WHERE t.DATA_TIME = '2026-07-10';   -- ⚡ 限定日期，避免误更新其他日期的数据
