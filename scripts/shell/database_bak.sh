#!/bin/bash
# ============================================================
# 数据库备份脚本（增强版 + 优化版）
# 保存为 /opt/db_backup.sh
# 用法：
#   bash database_bak.sh                  全量备份（慢，文件大）
#   bash database_bak.sh --light          轻量备份（排除备份表副本，推荐）
#   bash database_bak.sh --separate       分表备份（每表单独文件，推荐）
#   bash database_bak.sh --structure-only 仅备份表结构（不含数据）
#   bash database_bak.sh --check          诊断模式（仅测试连接，不备份）
# ============================================================

# ===== 数据库配置（按需修改） =====
DB_USER="mysql"
DB_PASSWORD="Tcdn@2023."
DB_NAME="mss_gd_pbms"
DB_HOST="192.168.20.10"
DB_PORT="3306"

# ===== 备份目录配置 =====
BACKUP_DIR="/app/backups_mss_gd_pbms/db"
LOG_FILE="/var/log/db_backup.log"
DATE_STAMP=$(date +%Y%m%d_%H%M)

# ===== 排除表列表（备份表副本，无需重复备份） =====
IGNORE_TABLES=(
    "basic_device_relation_copy1"
    "basic_device_relation_copy2"
    "basic_device_account_copy1"
    "basic_device_account_copy1_copy1"
)

# 确保备份目录存在
mkdir -p "$BACKUP_DIR" 2>/dev/null

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    [ -t 1 ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 构建 --ignore-table 参数
build_ignore_args() {
    local args=""
    for tbl in "${IGNORE_TABLES[@]}"; do
        args+=" --ignore-table=${DB_NAME}.${tbl}"
    done
    echo "$args"
}

# ===== 诊断模式 =====
if [ "$1" = "--check" ]; then
    echo ""
    echo "========== 数据库连接诊断 =========="
    echo "目标：${DB_HOST}:${DB_PORT}  数据库：${DB_NAME}  用户：${DB_USER}"
    echo ""

    command -v mysqldump &>/dev/null && echo "✅ mysqldump 可用" || echo "❌ mysqldump 未安装"
    command -v mysql &>/dev/null && echo "✅ mysql 客户端可用" || echo "❌ mysql 客户端未安装"

    echo ""
    echo "--- 测试网络连通 ---"
    timeout 5 bash -c "echo > /dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null \
        && echo "✅ 端口可达" || echo "❌ 端口不可达"

    echo ""
    echo "--- 测试 MySQL 登录 ---"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" "$DB_NAME" -e "SELECT 1 AS test;" 2>&1 \
        && echo "✅ 登录成功" || echo "❌ 登录失败"

    echo ""
    echo "--- 各表大小排行 ---"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" "$DB_NAME" -e "
        SELECT table_name AS '表名',
               ROUND((data_length+index_length)/1024/1024,2) AS '大小(MB)',
               table_rows AS '行数'
        FROM information_schema.tables
        WHERE table_schema='${DB_NAME}'
        ORDER BY (data_length+index_length) DESC
        LIMIT 20;" 2>/dev/null || echo "❌ 无法读取"

    echo ""
    echo "========== 诊断完成 =========="
    exit 0
fi

# ===== 分表备份模式（每表单独文件） =====
if [ "$1" = "--separate" ]; then
    log "========== 开始分表备份 =========="

    # 获取所有表名
    TABLES=$(mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" "$DB_NAME" \
        -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema='${DB_NAME}' ORDER BY (data_length+index_length) DESC;" 2>>"$LOG_FILE")

    TOTAL_SIZE=0
    TABLE_COUNT=0
    for TBL in $TABLES; do
        # 检查是否在排除列表
        SKIP=false
        for IGN in "${IGNORE_TABLES[@]}"; do
            [ "$TBL" = "$IGN" ] && SKIP=true && break
        done
        $SKIP && log "⏭️  跳过排除表：${TBL}" && continue

        # 备份单表
        TBL_FILE="${DB_NAME}_${TBL}_${DATE_STAMP}.sql.gz"
        mysqldump -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" \
            --single-transaction --quick \
            "$DB_NAME" "$TBL" 2>>"$LOG_FILE" | gzip -9 > "${BACKUP_DIR}/${TBL_FILE}"

        if [ $? -eq 0 ]; then
            SZ=$(ls -lh "${BACKUP_DIR}/${TBL_FILE}" | awk '{print $5}')
            log "✅ ${TBL} → ${TBL_FILE}（${SZ}）"
            TABLE_COUNT=$((TABLE_COUNT + 1))
        else
            log "❌ ${TBL} 备份失败"
            rm -f "${BACKUP_DIR}/${TBL_FILE}"
        fi
    done

    log "========== 分表备份完成（共 ${TABLE_COUNT} 个表）=========="

    # 清理旧备份（保留 35 周 = 245 天）
    find "$BACKUP_DIR" -name "${DB_NAME}_*_*.sql.gz" -mtime +245 -exec rm {} \; 2>/dev/null
    log "🗑️  已清理超过 245 天的旧分表备份"
    exit 0
fi

# ===== 仅备份表结构 =====
if [ "$1" = "--structure-only" ]; then
    BACKUP_FILE="${DB_NAME}_struct_${DATE_STAMP}.sql"
    log "========== 开始备份表结构 =========="
    mysqldump -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" \
        --no-data --routines --events --triggers \
        "$DB_NAME" 2>>"$LOG_FILE" | gzip -9 > "${BACKUP_DIR}/${BACKUP_FILE}.gz"
    if [ $? -eq 0 ]; then
        GZ_SIZE=$(ls -lh "${BACKUP_DIR}/${BACKUP_FILE}.gz" | awk '{print $5}')
        log "✅ 表结构备份完成：${BACKUP_FILE}.gz（${GZ_SIZE}）"
    else
        log "❌ 表结构备份失败"
        exit 1
    fi
    exit 0
fi

# ===== 备份模式 =====
# 构建排除参数
IGNORE_ARGS=$(build_ignore_args)

if [ "$1" = "--light" ]; then
    # 轻量模式：排除备份表副本 + 最高压缩
    BACKUP_FILE="${DB_NAME}_light_${DATE_STAMP}.sql"
    log "========== 开始轻量备份（排除${#IGNORE_TABLES[@]}个备份副本表）=========="
    log "排除的表：${IGNORE_TABLES[*]}"
    mysqldump -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" \
        --single-transaction --quick \
        $IGNORE_ARGS \
        "$DB_NAME" 2>>"$LOG_FILE" | gzip -9 > "${BACKUP_DIR}/${BACKUP_FILE}.gz"
else
    # 全量模式
    BACKUP_FILE="${DB_NAME}_full_${DATE_STAMP}.sql"
    log "========== 开始全量备份 =========="
    mysqldump -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" \
        --single-transaction --quick \
        "$DB_NAME" 2>>"$LOG_FILE" | gzip -9 > "${BACKUP_DIR}/${BACKUP_FILE}.gz"
fi

# 检查备份结果
if [ $? -ne 0 ]; then
    log "❌ 备份失败"
    rm -f "${BACKUP_DIR}/${BACKUP_FILE}.gz"
    exit 1
fi

GZ_SIZE=$(ls -lh "${BACKUP_DIR}/${BACKUP_FILE}.gz" | awk '{print $5}')
GZ_BYTES=$(stat -c%s "${BACKUP_DIR}/${BACKUP_FILE}.gz" 2>/dev/null || stat -f%z "${BACKUP_DIR}/${BACKUP_FILE}.gz" 2>/dev/null)

if [ -z "$GZ_BYTES" ] || [ "$GZ_BYTES" -lt 100 ]; then
    log "❌ 备份文件异常小（${GZ_BYTES}字节），删除"
    rm -f "${BACKUP_DIR}/${BACKUP_FILE}.gz"
    exit 1
fi

log "✅ 备份成功：${BACKUP_FILE}.gz（${GZ_SIZE}）"

# 删除旧备份（保留最近 35 周 = 245 天）
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +245 -exec rm {} \; 2>/dev/null

log "========== 备份完成 =========="
exit 0
