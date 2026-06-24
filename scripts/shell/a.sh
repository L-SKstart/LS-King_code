#!/bin/bash
# ============================================================================
# 脚本名称: cime_xml_extract.sh
# 功能描述: 
#   1. 支持多种日期输入方式（当天/单个日期/日期范围）
#   2. 从阿里云 OSS 下载对应的压缩包（压缩包文件名格式: MXWJ-DDXT_yyyy-M-d.tar.gzaa）
#   3. 解压流程（3层）:
#      a) gunzip .tar.gzaa → .tar（原始 tar 包）
#      b) tar -xf .tar → 两层目录结构
#      c) gunzip .xml.gz → .xml
#   4. 在解压后的目录中查找目标 XML 文件（XML 文件名日期格式为 yyyyMMdd，如 NanW_20260604*_DWMX.xml）
#   5. 将找到的 XML 文件复制到固定目录，避免重复处理
#
# 作者: 罗圣康
# 版本: 3.0
# 日期: 2026-06-05
# ============================================================================

set -eo pipefail

# ---------------------------------- 配置区 ----------------------------------
# 以下参数请按实际环境修改（手动 ossutil 能跑通的那个 -e -i -k 值）
# Cloud_Tool="/opt/Alibaba/ossutil64"
# Endpoint="http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn"
# accessKeyID="xeL2TscChf2chype"
# accessKeySecret="H1Bskv86AydGi7KBAc3jWnsiRdavhf"
# OSS_ARCHIVE_DIR="oss://ydsjzx/sjgx/ayyk/DWMx"
ARCHIVE_PREFIX="MXWJ-DDXT_"                        # 压缩包文件名前缀

LOCAL_TEMP_BASE="/opt/cime"
FINAL_XML_DIR="/mnt/dwayk/cime"
LOG_DIR="/home/auto_shell/logs"
LOG_FILE="${LOG_DIR}/task_cime.log"
DEBUG="${CIME_DEBUG:-0}"                            # 设为1打印实际执行的ossutil命令（调试用）
# 分片拷贝参数（大文件加速下载）
OSS_PART_SIZE="10485760"                           # 分片大小 10MB
OSS_PARALLEL="5"                                   # 并发线程数

# ---------------------------------- 辅助函数 ----------------------------------

log() {
    local level="$1"
    local msg="$2"
    # 日志输出到 stderr（终端可见）+ 日志文件
    # 避免 stdout 污染 $() 捕获的函数返回值
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg" | tee -a "$LOG_FILE" >&2
}

init_dirs() {
    /usr/bin/sudo mkdir -p "$LOG_DIR" "$FINAL_XML_DIR" "$LOCAL_TEMP_BASE"
    # 确保 OSS 路径以 / 结尾，避免路径拼接错误
    [[ "$OSS_ARCHIVE_DIR" != */ ]] && OSS_ARCHIVE_DIR="${OSS_ARCHIVE_DIR}/"
    # 清理可能的 Windows 换行符 (CRLF -> LF)，防止 \r 混入参数导致 403
    Cloud_Tool="${Cloud_Tool%$'\r'}"
    OSS_ARCHIVE_DIR="${OSS_ARCHIVE_DIR%$'\r'}"
    log "INFO" "目录初始化完成: LOG=$LOG_DIR, XML_OUT=$FINAL_XML_DIR, TEMP_BASE=$LOCAL_TEMP_BASE"
}

# 检查 ossutil 工具是否可用
check_tool() {
    if [ ! -x "$Cloud_Tool" ] && ! command -v "$Cloud_Tool" &>/dev/null; then
        log "ERROR" "ossutil 工具不可用: $Cloud_Tool"
        log "ERROR" "请确认路径正确或已安装 ossutil64"
        exit 1
    fi
    log "INFO" "ossutil 工具检查通过: $Cloud_Tool"
}

# 信号处理: 清理残留临时目录
cleanup_on_interrupt() {
    log "WARN" "收到中断信号，清理临时目录..."
    rm -rf "${LOCAL_TEMP_BASE}"/work_* 2>/dev/null || true
    log "INFO" "脚本被中断退出"
    exit 130
}
trap cleanup_on_interrupt INT TERM

# ============================================================================
# yyyyMMdd -> yyyy-M-d (如 20260604 -> 2026-6-4)
# ============================================================================
convert_to_dash_format() {
    local yyyymmdd="$1"
    # 校验: 必须是8位纯数字，否则用 date 命令兜底转换
    if [[ ! "$yyyymmdd" =~ ^[0-9]{8}$ ]]; then
        log "WARN" "convert_to_dash_format: 输入非8位数字 '$yyyymmdd'，尝试 date 转换"
        yyyymmdd=$(date -d "$yyyymmdd" +"%Y%m%d" 2>/dev/null || echo "")
        if [[ ! "$yyyymmdd" =~ ^[0-9]{8}$ ]]; then
            log "ERROR" "convert_to_dash_format: 无法转换 '$1'"
            echo ""
            return 1
        fi
    fi
    local year="${yyyymmdd:0:4}"
    local month=$((10#${yyyymmdd:4:2}))
    local day=$((10#${yyyymmdd:6:2}))
    echo "${year}-${month}-${day}"
}

# ============================================================================
# yyyy-M-d 或 yyyyMMdd -> yyyyMMdd
# ============================================================================
normalize_date() {
    local input_date="$1"
    if [[ "$input_date" == *-* ]]; then
        date -d "$input_date" +"%Y%m%d" 2>/dev/null || {
            log "ERROR" "日期格式错误，无法转换: $input_date"
            exit 1
        }
    else
        if [[ "$input_date" =~ ^[0-9]{8}$ ]]; then
            echo "$input_date"
        else
            log "ERROR" "日期格式错误，应为 yyyymmdd 或 yyyy-m-d: $input_date"
            exit 1
        fi
    fi
}

# ============================================================================
# 解析用户输入: 空/单日/范围
# ============================================================================
parse_user_input() {
    local user_input="$1"
    local dates=()

    if [ -z "$user_input" ]; then
        local today
        today=$(date +"%Y%m%d")
        dates=("$today")
        log "INFO" "未指定日期，自动使用当天: $today"
    elif [[ "$user_input" == *","* ]]; then
        local start_raw
        start_raw=$(echo "$user_input" | cut -d',' -f1)
        local end_raw
        end_raw=$(echo "$user_input" | cut -d',' -f2)
        local start
        start=$(normalize_date "$start_raw")
        local end
        end=$(normalize_date "$end_raw")
        if [[ "$start" > "$end" ]]; then
            log "ERROR" "起始日期不能大于结束日期: $start > $end"
            exit 1
        fi
        local current="$start"
        while [[ "$current" -le "$end" ]]; do
            dates+=("$current")
            current=$(date -d "$current +1 day" +"%Y%m%d")
        done
        log "INFO" "日期范围: $start 至 $end，共 ${#dates[@]} 天"
    else
        local norm_date
        norm_date=$(normalize_date "$user_input")
        dates=("$norm_date")
        log "INFO" "单个日期: $norm_date"
    fi
    echo "${dates[@]}"
}

# ============================================================================
# 从 OSS 查找压缩包: ${ARCHIVE_PREFIX}yyyy-M-d.tar.gzaa
# 优先用 ossutil ls 列出目录后精确匹配（避免 stat 403 问题）
# ============================================================================
get_remote_archive() {
    local target_date_yyyymmdd="$1"
    local target_date_dash
    target_date_dash=$(convert_to_dash_format "$target_date_yyyymmdd") || {
        log "ERROR" "日期转换失败: $target_date_yyyymmdd"
        return 1
    }
    
    log "INFO" "OSS 查找: ${ARCHIVE_PREFIX}${target_date_dash}*.tar.gzaa"

    # DEBUG: 打印实际执行的命令（与手动对比）
    if [ "$DEBUG" = "1" ]; then
        log "DEBUG" "执行命令: $Cloud_Tool ls ${OSS_ARCHIVE_DIR} -d -e http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn -i xeL2TscChf2chype -k H1Bskv86AydGi7KBAc3jWnsiRdavhf"
    fi

    $Cloud_Tool ls ${OSS_ARCHIVE_DIR} -d -e "http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn" -i "xeL2TscChf2chype" -k "H1Bskv86AydGi7KBAc3jWnsiRdavhf" > "/mnt/dwayk/cime/ls_output.txt" 2>&1 || true

    # 检测 OSS 认证/连接错误
    if grep -qiE "InvalidAccessKeyId|AccessDenied|403|ErrorCode" "/mnt/dwayk/cime/ls_output.txt"; then
        log "ERROR" "OSS 连接失败 (认证或权限错误):"
        # 注意: while read 管道末尾加 || true，防止 grep 无匹配时 pipefail 触发 set -e
        grep -iE "Error|403" "/mnt/dwayk/cime/ls_output.txt" | while read -r err_line; do
            log "ERROR" "  $err_line"
        done || true
        return 1
    fi

    # 精确匹配: 前缀+日期+.tar.gzaa
    local archive
    archive=$(grep -F "${ARCHIVE_PREFIX}${target_date_dash}" "/mnt/dwayk/cime/ls_output.txt" \
        | grep -F ".tar.gzaa" \
        | awk '{print $NF}' \
        | head -1)

    if [ -n "$archive" ]; then
        log "INFO" "OSS 找到: ${archive}"
        echo "$archive"
    else
        log "WARN" "OSS 未找到 ${ARCHIVE_PREFIX}${target_date_dash}*.tar.gzaa"
    fi
}

# ============================================================================
# 下载压缩包 (ossutil cp --recursive --include --force)
# ============================================================================
download_archive() {
    local remote_name="$1"
    local local_dir="$2"
    /usr/bin/sudo mkdir -p "$local_dir"
    log "INFO" "下载: $remote_name"

    # DEBUG: 打印实际执行的命令
    if [ "$DEBUG" = "1" ]; then
        log "DEBUG" "执行命令: $Cloud_Tool sync ${OSS_ARCHIVE_DIR} ${local_dir}/ -e http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn -i xeL2TscChf2chype -k H1Bskv86AydGi7KBAc3jWnsiRdavhf --recursive --include=$remote_name -f --retry-times=3 --connect-timeout=30 --update -f >/dev/null 2>&1
    fi

    $Cloud_Tool sync "$OSS_ARCHIVE_DIR" "$local_dir/" -e "http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn" -i "xeL2TscChf2chype" -k "H1Bskv86AydGi7KBAc3jWnsiRdavhf" --recursive --include="$remote_name" -f --retry-times=3 --connect-timeout=30 --update -f >/dev/null 2>&1

    if [ $? -eq 0 ] && [ -f "${local_dir}/${remote_name}" ] && [ -s "${local_dir}/${remote_name}" ]; then
        echo "${local_dir}/${remote_name}"
    else
        log "ERROR" "ossutil 下载失败: $remote_name"
        if [ ! -f "${local_dir}/${remote_name}" ]; then
            log "ERROR" "  文件不存在: ${local_dir}/${remote_name}"
        elif [ ! -s "${local_dir}/${remote_name}" ]; then
            log "ERROR" "  文件为空: ${local_dir}/${remote_name}"
        fi
        return 1
    fi
}

# ============================================================================
# extract_archive - 第1+2层解压
#   第1层: gunzip .tar.gzaa -> .tar
#   第2层: tar -xf .tar -> 两层目录结构
# ============================================================================
extract_archive() {
    local archive_path="$1"
    local extract_dir="$2"

    /usr/bin/sudo mkdir -p "$extract_dir"
    log "INFO" "===== 第1+2层解压: $(basename "$archive_path") ====="

    # ---- 第1层: gunzip ----
    # .tar.gzaa 本质是 gzip 压缩的 tar 包（非标准扩展名）
    local tar_file="${archive_path%.gzaa}.tar"
    log "INFO" "[第1层] gunzip -> $(basename "$tar_file")"

    gunzip -c "$archive_path" > "$tar_file" 2>/dev/null
    if [ $? -eq 0 ] && [ -f "$tar_file" ] && [ -s "$tar_file" ]; then
        log "INFO" "[第1层] gunzip 成功"
    else
        log "ERROR" "[第1层] gunzip 失败: $archive_path"
        return 1
    fi

    # ---- 第2层: tar 解包 ----
    log "INFO" "[第2层] tar 解包 -> $extract_dir"
    if tar -xf "$tar_file" -C "$extract_dir" 2>/dev/null; then
        log "INFO" "[第2层] tar -xf 成功"
    elif tar -xzf "$tar_file" -C "$extract_dir" 2>/dev/null; then
        log "INFO" "[第2层] tar -xzf 成功"
    else
        log "ERROR" "[第2层] tar 解包失败: $tar_file"
        rm -f "$tar_file"
        return 1
    fi

    rm -f "$tar_file"
    log "INFO" "===== 前 2层解压完成 ====="
    return 0
}

# ============================================================================
# find_and_decompress_xml - 第3层解压
#   递归查找 .xml.gz -> gunzip -> .xml
# ============================================================================
find_and_decompress_xml() {
    local search_dir="$1"
    local target_date_yyyymmdd="$2"

    log "INFO" "[第3层] 查找 NanW_${target_date_yyyymmdd}*_DWMX.xml.gz"

    # 优先查找 .xml.gz
    local xml_gz
    xml_gz=$(find "$search_dir" -type f \
        -name "NanW_${target_date_yyyymmdd}*_DWMX.xml.gz" 2>/dev/null | head -1)

    if [ -n "$xml_gz" ]; then
        log "INFO" "[第3层 ] gunzip: $(basename "$xml_gz")"
        if gunzip "$xml_gz" 2>/dev/null; then
            :
        elif gunzip -c "$xml_gz" > "${xml_gz%.gz}" 2>/dev/null; then
            rm -f "$xml_gz"
        else
            log "ERROR" "[第3层] gunzip 失败: $xml_gz"
            return 1
        fi
        local xml_file="${xml_gz%.gz}"
        if [ -f "$xml_file" ]; then
            log "INFO" "[第3层] 成功 -> $(basename "$xml_file")"
            echo "$xml_file"
            return 0
        fi
    fi

    # 回退: 可能已经是 .xml（无需 gunzip）
    local xml_direct
    xml_direct=$(find "$search_dir" -type f \
        -name "NanW_${target_date_yyyymmdd}*_DWMX.xml" 2>/dev/null | head -1)
    if [ -n "$xml_direct" ]; then
        log "INFO" "[第3层] 直接找到 .xml: $(basename "$xml_direct")"
        echo "$xml_direct"
        return 0
    fi

    log "ERROR" "[第3层] 未找到 NanW_${target_date_yyyymmdd}*_DWMX.xml[.gz]"
    return 1
}

# ============================================================================
# 复制 XML 到最终目录
# ============================================================================
copy_xml_to_final() {
    local xml_path="$1"
    local final_dir="$2"
    local filename
    filename=$(basename "$xml_path")
    local dest_path="${final_dir}/${filename}"
    cp "$xml_path" "$dest_path"
    log "INFO" "XML 已复制: $dest_path"
}

# ============================================================================
# 处理单个日期
# ============================================================================
process_one_date() {
    local target_date_yyyymmdd="$1"
    log "INFO" "========== 处理日期: $target_date_yyyymmdd =========="

    # 步骤1: 检查最终 XML 是否已存在（幂等）
    local existing_xml
    existing_xml=$(find "$FINAL_XML_DIR" -type f \
        -name "NanW_${target_date_yyyymmdd}*_DWMX.xml" 2>/dev/null | head -1)
    if [ -n "$existing_xml" ]; then
        log "INFO" "XML 已存在，跳过: $(basename "$existing_xml")"
        return 0
    fi

    # 步骤2: OSS 查找压缩包
    local remote_archive
    remote_archive=$(get_remote_archive "$target_date_yyyymmdd") || {
        log "WARN" "OSS 查找异常，跳过日期 $target_date_yyyymmdd"
        return 0
    }
    if [ -z "$remote_archive" ]; then
        log "WARN" "OSS 无压缩包，跳过日期 $target_date_yyyymmdd"
        return 0
    fi

    # 步骤3: 创建临时工作目录
    local work_dir="${LOCAL_TEMP_BASE}/work_${target_date_yyyymmdd}_$$"
    /usr/bin/sudo mkdir -p "$work_dir"

    # 步骤4: 下载
    local local_archive
    local_archive=$(download_archive "$remote_archive" "$work_dir") || {
        rm -rf "$work_dir"
        return 1
    }

    # 步骤5: 第1+2层解压
    extract_archive "$local_archive" "$work_dir" || {
        log "ERROR" "解压失败，清理临时目录"
        rm -rf "$work_dir"
        return 1
    }

    # 步骤6: 第3层解压 — 查找 .xml.gz 并 gunzip
    local target_xml
    target_xml=$(find_and_decompress_xml "$work_dir" "$target_date_yyyymmdd") || {
        log "ERROR" "未找到 XML 文件"
        rm -rf "$work_dir"
        return 1
    }

    # 步骤7: 复制到最终目录
    copy_xml_to_final "$target_xml" "$FINAL_XML_DIR"

    # 步骤8: 清理
    rm -rf "$work_dir"
    log "INFO" "日期 $target_date_yyyymmdd 处理完成"
    return 0
}

# ---------------------------------- 主流程 ----------------------------------
main() {
    USER_INPUT="${1:-}"
    init_dirs
    check_tool

    if [ "$DEBUG" = "1" ]; then
        log "DEBUG" "配置值确认:"
        log "DEBUG" "  Cloud_Tool     = [$Cloud_Tool]"
        log "DEBUG" "  Endpoint       = [$Endpoint]"
        log "DEBUG" "  accessKeyID    = [${accessKeyID:0:4}...${accessKeyID: -4}]"
        log "DEBUG" "  OSS_ARCHIVE_DIR= [$OSS_ARCHIVE_DIR]"
    fi

    local date_list
    date_list=("$(parse_user_input "$USER_INPUT")")
 
    if [ ${#date_list[@]} -eq 0 ]; then
        log "ERROR" "没有生成任何有效日期，脚本退出"
        exit 1
    fi

    log "INFO" "共需处理 ${#date_list[@]} 个日期: ${date_list[*]}"

    local success_count=0
    local fail_count=0
    for dt in "${date_list[@]}"; do
        if process_one_date "$dt"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done

    log "INFO" "全部完成! 成功: ${success_count}, 失败: ${fail_count}"
}

main "$@"