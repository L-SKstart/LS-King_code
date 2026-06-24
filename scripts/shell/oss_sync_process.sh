#!/bin/bash
# ============================================================
# OSS 离线数据同步脚本
#
# 【用途】
#   从 OSS 拉取数据 → 检测目标字段 → 将命中的 input+output 复制到固定目录
#   ⚠️ 本脚本只复制不解压
#
# 【文件名规则】
#   input 文件:  {业务日期YYYYMMDDHHMMSS}_DHM_{生成时间戳}.tar.gz              （无 _output 后缀）
#   output 文件: {业务日期YYYYMMDDHHMMSS}_DHM_{生成时间戳}_output*.tar.gz （匹配 _output 前缀，兼容 _iter3 等后缀）
#   ⇒ output 复制时会自动改名为 _out.tar.gz
#
# 【调用方式】
#   bash oss_sync_process.sh              # 处理当天
#   bash oss_sync_process.sh 20260604     # 处理指定日期
#   bash oss_sync_process.sh 20260601,20260604  # 处理日期范围
#
# 【输出结构】（OUTPUT_DIR 下）
#   {业务日期YYYYMMDDHHMMSS}_DHM_{时间戳}.tar.gz         ← input（原样）
#   {业务日期YYYYMMDDHHMMSS}_DHM_{时间戳}_out.tar.gz     ← output（改后缀）
# ============================================================

set -euo pipefail

# ============================================================
# ⚠️ 配置区 — 请根据实际环境修改以下参数
# ============================================================

# OSS 工具路径（确认服务器上 ossutil64 安装位置）
Cloud_Tool="/opt/Alibaba/ossutil64"

# OSS 连接信息（从 a.sh 复用，如有变更请更新）
Endpoint="http://oss-cn-guangzhou-mwang-d01-a.pddc-cloud2.cn"
accessKeyID="0tyuF0mqAqoIpPl"
accessKeySecret="c4pth7OE4jPpqPfHldo4QWmgz1I9yj3"

# ⚠️ OSS 远端目录 — 必填！
OSS_ARCHIVE_DIR="oss://ydxt-2/extdata/DDXT/clearing/IIS"

# 本地目录
LOCAL_DOWN_DIR="/tmp/oss_data"        # 下载临时目录（脚本会自动清理）
OUTPUT_DIR="/tmp/oss_output"          # 输出目录（input+output 最终存放位置）

# 检索字段（tar.gz 内 BasicInfo/BasicInfo.txt 中匹配的内容）
# ⚠️ 注意：文件中的实际格式开头有 "# "，末尾有 "-"，不要漏写
TARGET_FIELD="# CaseName 方案名称 UC-"

# OSS 下载参数
RETRY_TIMES=3
CONNECT_TIMEOUT=30
DEBUG="${OSS_DEBUG:-0}"               # 设 1 可打印 ossutil 调试信息

# ============================================================
# 以下为脚本逻辑，如无必要请勿修改
# ============================================================

# ---------- 日志 ----------
log() { echo "$(date "+%Y-%m-%d %H:%M:%S") [$1] $2" >&2; }

# ---------- 日期解析 ----------
# 输入格式：空=当天 | yyyyMMdd=单日期 | yyyyMMdd,yyyyMMdd=范围
normalize_date() {
    local input="$1"
    if [[ "$input" == *-* ]]; then
        date -d "$input" +"%Y%m%d" 2>/dev/null || { log "ERROR" "日期格式错误: $input"; exit 1; }
    else
        [[ "$input" =~ ^[0-9]{8}$ ]] && echo "$input" || { log "ERROR" "日期格式错误: $input"; exit 1; }
    fi
}

parse_dates() {
    local input="${1:-}"
    local dates=()
    if [[ -z "$input" ]]; then
        dates+=("$(date +"%Y%m%d")")
        log "INFO" "未指定日期，使用当天: ${dates[0]}"
    elif [[ "$input" == *","* ]]; then
        local start end
        start=$(normalize_date "${input%%,*}")
        end=$(normalize_date "${input#*,}")
        if [[ "$start" > "$end" ]]; then log "ERROR" "起始日期 > 结束日期"; exit 1; fi
        local cur="$start"
        while [[ "$cur" -le "$end" ]]; do
            dates+=("$cur")
            cur=$(date -d "${cur:0:4}-${cur:4:2}-${cur:6:2} +1 day" +"%Y%m%d")
        done
        log "INFO" "日期范围: $start ~ $end，共 ${#dates[@]} 天"
    else
        dates+=("$(normalize_date "$input")")
        log "INFO" "单个日期: ${dates[0]}"
    fi
    echo "${dates[@]}"
}

# ---------- OSS 操作函数 ----------
# 注：ossutil 的 -e -i -k 参数与 a.sh 保持一致

# OSS 按日期列出文件（--include 服务端过滤，与手动验证命令一致）
# 参数：$1=日期(YYYYMMDD)
oss_ls() {
    local date_filter="${1:-}"
    local include_arg=""
    [[ -n "$date_filter" ]] && include_arg="--include=${date_filter}*"
    if [[ "${DEBUG}" == "1" ]]; then
        log "DEBUG" "oss_ls 执行: $Cloud_Tool ls ${OSS_ARCHIVE_DIR} -d ${include_arg} -e ..."
    fi
    $Cloud_Tool ls "${OSS_ARCHIVE_DIR}" -d ${include_arg} -e "$Endpoint" -i "$accessKeyID" -k "$accessKeySecret" 2>/dev/null
}

# 从 OSS 下载文件（通过文件名前缀匹配，取 _DHM_ 前的时间戳前缀）
# 参数：$1=文件名  $2=目标目录
# 返回：0=成功  1=失败
oss_download() {
    local target_file="$1" dest_dir="$2"
    local prefix="${target_file%%_DHM*}"
    echo ">>> 下载: ${target_file}（前缀: ${prefix}*）"
    $Cloud_Tool sync "${OSS_ARCHIVE_DIR}" "${dest_dir}/" \
        -e "$Endpoint" -i "$accessKeyID" -k "$accessKeySecret" \
        --recursive --include="${prefix}*" -f \
        --retry-times="${RETRY_TIMES}" --connect-timeout="${CONNECT_TIMEOUT}" --update
    if [[ -f "${dest_dir}/${target_file}" && -s "${dest_dir}/${target_file}" ]]; then
        echo "   ✅ 下载成功"
        return 0
    else
        echo "   ❌ 下载失败或文件为空"
        return 1
    fi
}

# ============================================================
# 处理单个日期
# ============================================================
process_one_date() {
    local date_yyyymmdd="$1"
    echo ""
    echo "========================================"
    echo ">>> 处理日期: ${date_yyyymmdd}"
    echo "========================================"

    # ----- 1. OSS 按日期列文件（--include 服务端过滤）-----
    echo ">>> 拉取 OSS 文件列表（日期: ${date_yyyymmdd}）..."
    local ls_out
    ls_out=$(oss_ls "$date_yyyymmdd" || true)
    # 过滤 .tar.gz，匹配文件名以日期开头（/日期前缀）
    local all_remote
    all_remote=$(echo "$ls_out" | awk -v d="${date_yyyymmdd}" '$NF ~ "/" d && $NF ~ /\.tar\.gz$/' | sort -t'_' -k3 -r || true)

    if [[ -z "$all_remote" ]]; then
        echo "[WARN] OSS 无文件，跳过 ${date_yyyymmdd}"
        return 0
    fi

    # ----- 2. 从最新到最旧，逐个下载并检索目标字段 -----
    local target_input=""
    local input_count=0
    for remote_f in $all_remote; do
        local fname="${remote_f##*/}"
        # 跳过 output 文件
        [[ "$fname" == *_output* ]] && continue
        ((input_count++)) || true
        echo -n "  检查: ${fname} ... "

        # 清空临时目录，下载单个文件
        rm -rf "${LOCAL_DOWN_DIR:?}"/* 2>/dev/null || true
        if ! oss_download "$fname" "$LOCAL_DOWN_DIR"; then echo "❌ 跳过"; continue; fi

        local local_f="${LOCAL_DOWN_DIR}/${fname}"
        local inner_dir="${fname%.tar.gz}"
        # tar -xOf 不解压直接读取内部文件 → 转码 → grep 目标字段
        if tar -xOf "$local_f" "${inner_dir}/BasicInfo/BasicInfo.txt" 2>/dev/null \
            | iconv -f GB18030 -t UTF-8//IGNORE \
            | grep -q "${TARGET_FIELD}"; then
            echo "✅ 命中"
            target_input="$local_f"
            break
        else
            echo "❌ 无匹配"
            rm -f "$local_f"
        fi
    done

    if [[ -z "$target_input" ]]; then
        echo "[WARN] ${date_yyyymmdd} 无含目标字段的文件，跳过"
        return 0
    fi

    local base_name="${target_input##*/}"
    local core_name="${base_name%.tar.gz}"        # 去掉 .tar.gz 后的核心名
    echo ">>> 选中: ${base_name}"

    # ----- 3. 复制 input 到输出目录（不解压） -----
    mkdir -p "${OUTPUT_DIR}"
    cp "$target_input" "${OUTPUT_DIR}/"
    echo "   ✅ ${base_name} → ${OUTPUT_DIR}/"

    # ----- 4. 从 OSS 列表按前缀查找 output 文件，改 _out 后复制 -----
    # 兼容 _output.tar.gz / _output_iter3.tar.gz 等不同后缀
    echo ">>> 检测 output..."
    local output_name
    output_name=$(echo "$all_remote" | grep -E "${core_name}_output.*\.tar\.gz$" | head -1)
    output_name="${output_name##*/}"
    if [[ -n "$output_name" ]]; then
        echo "   找到: ${output_name}"
        rm -rf "${LOCAL_DOWN_DIR:?}"/* 2>/dev/null || true
        if oss_download "$output_name" "$LOCAL_DOWN_DIR"; then
            local out_name="${core_name}_out.tar.gz"
            cp "${LOCAL_DOWN_DIR}/${output_name}" "${OUTPUT_DIR}/${out_name}"
            echo "   ✅ ${out_name} → ${OUTPUT_DIR}/"
        fi
    else
        echo "   [通知] OSS 无对应 output"
    fi

    echo ">>> 日期 ${date_yyyymmdd} 处理完成"
    return 0
}

# ============================================================
# 主流程
# ============================================================
main() {
    local user_input="${1:-}"
    # 确保 OSS 路径以 / 结尾，避免路径拼接错误（参照 a.sh）
    [[ "$OSS_ARCHIVE_DIR" != */ ]] && OSS_ARCHIVE_DIR="${OSS_ARCHIVE_DIR}/"
    mkdir -p "${LOCAL_DOWN_DIR}" "${OUTPUT_DIR}"

    local date_list
    date_list=($(parse_dates "$user_input"))
    if [[ ${#date_list[@]} -eq 0 ]]; then
        log "ERROR" "无有效日期"
        exit 1
    fi

    local succ=0 fail=0
    for dt in "${date_list[@]}"; do
        if process_one_date "$dt"; then ((succ++)) || true; else ((fail++)) || true; fi
    done

    echo ""
    echo "========================================"
    echo "✅ 全部完成！成功: ${succ}  跳过: ${fail}"
    echo "   输出目录: ${OUTPUT_DIR}"
    ls -lh "${OUTPUT_DIR}/" 2>/dev/null | tail -20
    echo "========================================"
}

main "$@"
