#!/bin/bash
# ============================================================================
# 脚本名称：mock_ossutil64.sh
# 用途：模拟阿里云 ossutil64 命令行工具（完整版），用于在没有真实 OSS 连接
#       的离线环境或开发环境中进行本地测试。
#       不需要网络、不需要 OSS 账号、不需要真实 OSS bucket。
# 用法：mock_ossutil64.sh ls [参数]             # 模拟列出 OSS 文件
#       mock_ossutil64.sh sync [参数]           # 模拟下载 OSS 文件到本地
#       mock_ossutil64.sh <其他>                # 输出错误并退出
# 环境变量：OSS_MOCK_STORE                      # 可选，指定模拟数据目录
#          不设则默认使用 /tmp/oss_mock_data
# 前提：模拟数据目录中需预先放入测试用的 .tar.gz 文件
# 区别：本脚本是 mock_ossutil.sh 的增强版，支持更多场景和默认兜底行为
# ============================================================================

MODE="$1"                                                 # 第一个参数：操作模式（ls 或 sync）

case "$MODE" in
    ls)
        # ================================================================
        # ls 模式：模拟"列出 OSS bucket 中符合日期前缀的文件"
        # 真实 ossutil 接到 ls 命令后，会向 OSS API 发送请求，返回文件列表
        # 我们这里不用网络，直接根据 --include 参数拼出假的文件路径返回
        # ================================================================
        
        DATE_FILTER=""                                    # 存放从 --include 中提取的日期前缀
        for arg in "$@"; do
            # 遍历所有参数，找 --include=20250601* 这种格式的参数
            # ${arg#--include=} 会去掉字符串开头的 "--include="
            [[ "$arg" == --include=* ]] && DATE_FILTER="${arg#--include=}"
        done
        DATE_FILTER="${DATE_FILTER%\*}"                    # 去掉末尾的 * 通配符（ossutil 用它做模糊匹配）
        
        if [[ -n "$DATE_FILTER" ]]; then
            # 有日期前缀 → 返回该日期的4个模拟文件
            # 为什么是4个？模拟真实场景中 OSS 每日期有 2 个 input + 2 个 output
            cat <<EOF
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133810.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133810_output.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133922.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133922_output.tar.gz
Object and Directory Number is: 4
EOF
            # 注意：最后一行是真实 ossutil 的输出格式尾巴，必须保留
            # 调用方脚本会用 grep 过滤这行，但如果不输出可能影响解析
        else
            # 没有日期前缀（调用方没传 --include）→ 返回一组默认的模拟文件
            # 这是兜底逻辑：测试时即使不指定日期也能得到数据，方便快速验证
            cat <<EOF
oss://ydxt-2/extdata/DDXT/clearing/IIS/20260625000000_DHM_20250624133810.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/20260625000000_DHM_20250624133810_output.tar.gz
Object and Directory Number is: 2
EOF
        fi
        ;;
        
    sync)
        # ================================================================
        # sync 模式：模拟"从 OSS 下载文件到本地目录"
        # 真实 ossutil sync 通过 OSS API 下载文件，我们改为从本地模拟目录复制
        # 这样不需要网络，但调用方脚本感知不到区别——路径和结果一样
        # ================================================================
        
        DEST=""                                           # 本地目标目录（下载到哪里）
        PREFIX=""                                         # 文件前缀过滤（只下载文件名匹配此前缀的文件）
        
        for arg in "$@"; do
            [[ "$arg" == --include=* ]] && PREFIX="${arg#--include=}"  # 提取 --include=20250601*
        done
        
        # 从所有参数中找出本地目标路径（以 / 开头的绝对路径）
        # 为什么用 / 开头判断？因为 OSS bucket 名不含 / 开头，本地路径必有 /
        for arg in "$@"; do
            [[ "$arg" == /* ]] && DEST="$arg"
        done
        
        DEST="${DEST%/}"                                  # 去掉目标目录末尾的 /，保持路径一致
        
        # 从模拟数据目录中复制文件
        # OSS_MOCK_STORE 环境变量优先，没设置就用默认路径 /tmp/oss_mock_data
        # ${变量:-默认值} 语法：如果变量有值就用变量，否则用默认值
        if [[ -n "$PREFIX" && -d "${OSS_MOCK_STORE:-/tmp/oss_mock_data}" ]]; then
            PREFIX_CLEAN="${PREFIX%\*}"                    # 去掉前缀末尾的通配符 *
            # 遍历模拟数据目录中所有匹配前缀的文件，逐个复制到目标目录
            for f in "${OSS_MOCK_STORE:-/tmp/oss_mock_data}"/*${PREFIX_CLEAN}*.tar.gz; do
                # -f 判断是否是普通文件（排除目录）
                # 2>/dev/null 吞掉复制失败时的错误输出，避免干扰脚本日志
                [[ -f "$f" ]] && cp "$f" "$DEST/" 2>/dev/null
            done
        fi
        ;;
        
    *)
        # 不支持的模式：告诉调用方出错了
        # >&2 表示输出到 stderr（标准错误），而不是 stdout（标准输出）
        # 这样调用方可以用 2>/dev/null 单独吞掉错误信息
        echo "Mock ossutil64: unknown mode $MODE" >&2
        exit 1                                            # 非0退出码表示失败
        ;;
esac
exit 0                                                    # 正常结束
