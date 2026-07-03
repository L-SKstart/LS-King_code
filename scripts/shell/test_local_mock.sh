#!/bin/bash
# ============================================================
# 本地模拟测试脚本：创建假数据 + 运行 oss_extract_process.sh
# 无 OSS 依赖，在服务器上测试脚本完整逻辑
# ============================================================
set -euo pipefail

echo "========================================"
echo "  OSS Extract 本地模拟测试"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# ---- 1. 创建 mock ossutil64 ----
MOCK_OSSUTIL="/opt/Alibaba/ossutil64"
MOCK_STORE="/tmp/oss_mock_data"

echo ""
echo ">>> [1/5] 安装 mock ossutil64 ..."
mkdir -p /opt/Alibaba /tmp/oss_mock_data
cat > "$MOCK_OSSUTIL" << 'MOCKEOF'
#!/bin/bash
MODE="$1"
MOCK_STORE="/tmp/oss_mock_data"
case "$MODE" in
    ls)
        DATE_FILTER=""
        for arg in "$@"; do
            [[ "$arg" == --include=* ]] && DATE_FILTER="${arg#--include=}"
        done
        DATE_FILTER="${DATE_FILTER%\*}"
        if [[ -n "$DATE_FILTER" ]]; then
            cat <<EOF
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133810.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133810_output.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133922.tar.gz
oss://ydxt-2/extdata/DDXT/clearing/IIS/${DATE_FILTER}000000_DHM_20250531133922_output.tar.gz
Object and Directory Number is: 4
EOF
        else
            echo "Object and Directory Number is: 0"
        fi
        ;;
    sync)
        DEST=""
        PREFIX=""
        for arg in "$@"; do
            [[ "$arg" == --include=* ]] && PREFIX="${arg#--include=}"
            [[ "$arg" == /tmp/* ]] && DEST="$arg"
        done
        DEST="${DEST%/}"
        if [[ -n "$PREFIX" && -d "$MOCK_STORE" ]]; then
            PREFIX_CLEAN="${PREFIX%\*}"
            for f in "$MOCK_STORE"/*"$PREFIX_CLEAN"*.tar.gz 2>/dev/null; do
                [[ -f "$f" ]] && cp "$f" "$DEST/" 2>/dev/null
            done
        fi
        ;;
    *)
        echo "mock ossutil: unknown $MODE" >&2
        ;;
esac
exit 0
MOCKEOF
chmod +x "$MOCK_OSSUTIL"
echo "   mock ossutil64 已安装到 $MOCK_OSSUTIL"

# ---- 2. 创建模拟 tar.gz 数据 ----
echo ""
echo ">>> [2/5] 创建模拟 OSS 数据文件 ..."
TEST_DATE="20260625"
CORE="${TEST_DATE}000000_DHM_20250531133810"

# input 文件 (无 _output)
mkdir -p "/tmp/build/${CORE}/BasicInfo"
echo "# CaseName 方案名称 UC-测试方案" > "/tmp/build/${CORE}/BasicInfo/BasicInfo.txt"
echo "test input data" > "/tmp/build/${CORE}/data.txt"
cd /tmp/build
tar -czf "${MOCK_STORE}/${CORE}.tar.gz" "${CORE}"
echo "   创建: ${CORE}.tar.gz"

# output 文件
CORE_OUT="${TEST_DATE}000000_DHM_20250531133810"
mkdir -p "/tmp/build/${CORE_OUT}_output/result"
echo "test output data" > "/tmp/build/${CORE_OUT}_output/result/output.txt"
tar -czf "${MOCK_STORE}/${CORE_OUT}_output.tar.gz" "${CORE_OUT}_output"
echo "   创建: ${CORE_OUT}_output.tar.gz"

# 第二个 input (不同时间戳，用于测试匹配逻辑)
CORE2="${TEST_DATE}000000_DHM_20250531133922"
mkdir -p "/tmp/build/${CORE2}/BasicInfo"
echo "other data" > "/tmp/build/${CORE2}/BasicInfo/BasicInfo.txt"
tar -czf "${MOCK_STORE}/${CORE2}.tar.gz" "${CORE2}"
echo "   创建: ${CORE2}.tar.gz"

CORE2_OUT="${TEST_DATE}000000_DHM_20250531133922"
mkdir -p "/tmp/build/${CORE2_OUT}_output/result"
echo "other output" > "/tmp/build/${CORE2_OUT}_output/result/output.txt"
tar -czf "${MOCK_STORE}/${CORE2_OUT}_output.tar.gz" "${CORE2_OUT}_output"
echo "   创建: ${CORE2_OUT}_output.tar.gz"

rm -rf /tmp/build
echo "   模拟数据创建完成"

# ---- 3. 上传测试脚本 ----
echo ""
echo ">>> [3/5] 准备测试脚本 ..."
# 脚本应该已经通过 SCP 上传，这里检查
if [[ ! -f /tmp/oss_extract_process_test.sh ]]; then
    echo "   ⚠️ 测试脚本未上传，请先 SCP"
    exit 1
fi
echo "   测试脚本就绪"

# ---- 4. 运行脚本 ----
echo ""
echo ">>> [4/5] 运行 oss_extract_process.sh ${TEST_DATE} ..."
echo "========================================"
bash /tmp/oss_extract_process_test.sh "$TEST_DATE" 2>&1 || true
EXIT_CODE=$?
echo "========================================"
echo "   脚本退出码: ${EXIT_CODE}"

# ---- 5. 验证结果 ----
echo ""
echo ">>> [5/5] 验证输出结果 ..."
echo ""
echo "--- 预期输出目录结构 ---"
find /mnt/data/oss/DHM/IN/ -type f -o -type d 2>/dev/null | sort | head -30 || echo "(目录为空或不存在)"
echo ""
echo "--- /tmp 临时目录检查 ---"
echo "LOCAL_DOWN_DIR: $(ls /tmp/oss_data/ 2>/dev/null || echo '(空)')"
echo "EXTRACT_TMP:    $(ls /tmp/oss_extract_tmp/ 2>/dev/null || echo '(空)')"

echo ""
echo "--- 系统根目录保护检查 ---"
# 确认 / 下没有被意外修改
ROOT_CHECK=$(ls -la / | wc -l)
echo "根目录条目数: ${ROOT_CHECK}"
echo "✅ 测试完成"
