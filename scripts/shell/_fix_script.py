#!/bin/bash
# ============================================================
# OSS 离线数据解压脚本
#
# 【用途】
#   从 OSS 拉取数据 -> 检测目标字段 -> 解压到 PREDICT 目录结构
#   本脚本会解压，不同于 oss_sync_process.sh（纯复制）
#
# 【文件名规则】
#   input:   {业务日期}_DHM_{时间戳}.tar.gz               (无 _output)
#   output:  {业务日期}_DHM_{时间戳}_output.tar.gz         (有 _output)
#   解压后 output 目录名自动改为 _out
#
# 【目录结构】
#   PREDICT_DIR/
#   └── {YYYMMDD}/
#       ├── DHM_IN/{name}/          <- input 解压后 (strip 展平)
#       └── DHM_OUT/{name}_out/     <- output 解压后 (改后缀 + strip)
#
# 【注意】
#   tar.gz 内部有两层同名目录，--strip-components=1 去掉外层
#   input 和 output 是独立文件，各自独立下载、独立解压
#
# 【调用】
#   bash oss_extract_process.sh              # 当天
#   bash oss_extract_process.sh 20260604     # 指定日期
#   bash oss_extract_process.sh 20260601,20260604  # 范围
# ============================================================
set -euo pipefail

# ============================================================
# 配置区 -- 请根据实际环境修改以下参数
# ============================================================

# OSS 工具路径（确认 ossutil64 安装位置）
Cloud_Tool="/opt/Alibaba/ossutil64"

# OSS 连接信息（从 a.sh 复用，如有变更请更新）
Endpoint="http://oss-cn-guangzhou-nfdw-d01-a.pdcc-cloud-inc.cn"
accessKeyID="xeL2TscChf2chype"
accessKeySecret="H1Bskv86AydGi7KBAc3jWnsiRdavhf"

# OSS 远端目录 -- 必填！如 oss://bucket/path/
OSS_ARCHIVE_DIR=""

# 本地目录
LOCAL_DOWN_DIR="/tmp/oss_data"
PREDICT_DIR="/opt/PREDICT"
EXTRACT_TMP="/tmp/oss_extract_tmp"

# 检索字段（BasicInfo/BasicInfo.txt 中匹配的内容）
# 文件中的实际格式开头有 "# "，末尾有 "-"
TARGET_FIELD="# CaseName 方案名称 UC-"

# OSS 下载参数
RETRY_TIMES=3
CONNECT_TIMEOUT=30
DEBUG="${OSS_DEBUG:-0}"

# ============================================================
# 以下为脚本逻辑，如无必要请勿修改
# ============================================================

log() { echo "$(date "+%Y-%m-%d %H:%M:%S") [$1] $2"; }

# ---------- 日期解析 ----------
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
        if [[ "$start" > "$end" ]]; then log "ERROR" "起始日期>结束日期"; exit 1; fi
        local cur="$start"
        while [[ "$cur" -le "$end" ]]; do
            dates+=("$cur")
            cur=$(date -d "$cur +1 day" +"%Y%m%d")
        done
        log "INFO" "日期范围: $start ~ $end，共 ${#dates[@]} 天"
    else
        dates+=("$(normalize_date "$input")")
        log "INFO" "单个日期: ${dates[0]}"
    fi
    echo "${dates[@]}"
}

# ---------- OSS 操作 ----------
oss_ls() {
    $Cloud_Tool ls "${OSS_ARCHIVE_DIR}" -e "$Endpoint" -i "$accessKeyID" -k "$accessKeySecret" 2>/dev/null
}

oss_download() {
    local target_file="$1" dest_dir="$2"
    echo ">>> 下载: ${target_file}"
    $Cloud_Tool sync "${OSS_ARCHIVE_DIR}" "${dest_dir}/"         -e "$Endpoint" -i "$accessKeyID" -k "$accessKeySecret"         --recursive --include="${target_file}" -f         --retry-times="${RETRY_TIMES}" --connect-timeout="${CONNECT_TIMEOUT}" --update         >/dev/null 2>&1
    if [[ -f "${dest_dir}/${target_file}" && -s "${dest_dir}/${target_file}" ]]; then
        echo "   ✅ 下载\u6210\u529f"
        return 0
    else
        echo "   ❌ \u5931\u8d25"
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

    # 1. OSS 列出当天所有 tar.gz
    echo ">>> 拉取 OSS 文件列表..."
    local ls_out
    ls_out=$(oss_ls || true)
    local all_remote
    all_remote=$(echo "$ls_out" | awk '{print $NF}' | grep "${date_yyyymmdd}" | grep '\\.tar\\.gz$' || true)
    local input_list
    input_list=$(echo "$all_remote" | grep -v '_output' || true)

    if [[ -z "$input_list" ]]; then
        echo "[WARN] 无 input 文件，跳过 ${date_yyyymmdd}"
        return 0
    fi

    local sorted_inputs
    sorted_inputs=$(echo "$input_list" | sort -t'_' -k3 -r)
    echo "共 $(echo "$sorted_inputs" | wc -l) 个 input"

    # 2. 从新到旧检索目标字段
    local target_input=""
    for remote_f in $sorted_inputs; do
        local fname
        fname=$(basename "$remote_f")
        echo -n "  检查: ${fname} ... "

        rm -rf "${LOCAL_DOWN_DIR:?}"/* 2>/dev/null || true
        if ! oss_download "$fname" "$LOCAL_DOWN_DIR"; then echo " 跳过"; continue; fi

        local local_f="${LOCAL_DOWN_DIR}/${fname}"
        if tar -xOf "$local_f" "BasicInfo/BasicInfo.txt" 2>/dev/null             | iconv -f GB18030 -t UTF-8//IGNORE             | grep -q "${TARGET_FIELD}"; then
            echo " ✅ \u547d\u4e2d"
            target_input="$local_f"
            break
        else
            echo " ❌ \u65e0\u5339\u914d"
            rm -f "$local_f"
        fi
    done

    if [[ -z "$target_input" ]]; then
        echo "[WARN] ${date_yyyymmdd} \u65e0\u542b\u76ee\u6807\u5b57\u6bb5\u7684\u6587\u4ef6\uff0c跳过"
        return 0
    fi

    local base_name
    base_name=$(basename "$target_input")
    local core_name="${base_name%.tar.gz}"
    local busi_date
    busi_date=$(echo "$core_name" | awk -F'_DHM_' '{print $1}' | cut -c1-8)
    echo ">>> 选中: ${base_name}  \u4e1a\u52a1\u65e5\u671f: ${busi_date}"

    # 3. 解压 input -> PREDICT/{busi_date}/DHM_IN/{core_name}/
    local in_target="${PREDICT_DIR}/${busi_date}/DHM_IN/${core_name}"
    echo ">>> 解压 input -> ${in_target}/"
    rm -rf "${EXTRACT_TMP:?}"/* 2>/dev/null || true
    tar -zxvf "$target_input" -C "${EXTRACT_TMP}" --strip-components=1

    mkdir -p "${PREDICT_DIR}/${busi_date}/DHM_IN"
    if [[ -d "${EXTRACT_TMP}/${core_name}" ]]; then
        mv "${EXTRACT_TMP}/${core_name}" "${in_target}"
    else
        mkdir -p "${in_target}"
        mv "${EXTRACT_TMP}"/* "${in_target}/" 2>/dev/null || true
    fi
    echo "   ${in_target}/"

    # 4. 找对应 output，解压 -- 改 _out
    local output_name="${core_name}_output.tar.gz"
    echo ">>> 检测 output: ${output_name}"
    if echo "$all_remote" | grep -qF "$output_name"; then
        rm -rf "${LOCAL_DOWN_DIR:?}"/* 2>/dev/null || true
        if oss_download "$output_name" "$LOCAL_DOWN_DIR"; then
            local out_target="${PREDICT_DIR}/${busi_date}/DHM_OUT/${core_name}_out"
            echo ">>> 解压 output -> ${out_target}/"
            rm -rf "${EXTRACT_TMP:?}"/* 2>/dev/null || true
            tar -zxvf "${LOCAL_DOWN_DIR}/${output_name}" -C "${EXTRACT_TMP}" --strip-components=1

            mkdir -p "${PREDICT_DIR}/${busi_date}/DHM_OUT"
            if [[ -d "${EXTRACT_TMP}/${core_name}_output" ]]; then
                mv "${EXTRACT_TMP}/${core_name}_output" "${out_target}"
            else
                mkdir -p "${out_target}"
                mv "${EXTRACT_TMP}"/* "${out_target}/" 2>/dev/null || true
            fi
            echo "   ${out_target}/"
        fi
    else
        echo "   [通知] 无对应 output"
    fi

    echo ">>> ${date_yyyymmdd} 完成"
    return 0
}

# ============================================================
# 主流程
# ============================================================
main() {
    local user_input="${1:-}"
    [[ "$OSS_ARCHIVE_DIR" != */ ]] && OSS_ARCHIVE_DIR="${OSS_ARCHIVE_DIR}/"
    mkdir -p "${LOCAL_DOWN_DIR}" "${PREDICT_DIR}" "${EXTRACT_TMP}"

    local date_list
    date_list=($(parse_dates "$user_input"))
    if [[ ${#date_list[@]} -eq 0 ]]; then
        log "ERROR" "无有效日期"
        exit 1
    fi

    local succ=0 fail=0
    for dt in "${date_list[@]}"; do
        if process_one_date "$dt"; then ((succ++)); else ((fail++)); fi
    done

    echo ""
    echo "========================================"
    echo "  完成\uff01\u6210\u529f: ${succ}  跳过: ${fail}"
    echo "   解压\u6839\u76ee\u5f55: ${PREDICT_DIR}"
    echo "========================================"
}

main "$@"
