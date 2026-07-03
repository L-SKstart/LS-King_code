#!/bin/bash
# 综合测试脚本：搭建模拟环境 + 运行 oss_extract_process.sh
set -euo pipefail

echo "=== [1/5] 创建目录和 mock ossutil64 ==="
mkdir -p /opt/Alibaba /tmp/oss_mock_data /mnt/data/oss/DHM/IN /tmp/oss_data /tmp/oss_extract_tmp

cat > /opt/Alibaba/ossutil64 << 'MOCKEOF'
#!/bin/bash
M=$1
S=/tmp/oss_mock_data
case $M in
  ls)
    D=""
    for a in "$@"; do [[ $a == --include=* ]] && D="${a#--include=}"; done
    D="${D%\*}"
    [ -n "$D" ] && echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133810.tar.gz" && echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133810_output.tar.gz" && echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133922.tar.gz" && echo "oss://ydxt-2/extdata/DDXT/clearing/IIS/${D}000000_DHM_20250531133922_output.tar.gz" && echo "Object and Directory Number is: 4"
    ;;
  sync)
    P=""; T=""
    for a in "$@"; do [[ $a == --include=* ]] && P="${a#--include=}"; [[ $a == /tmp/* ]] && T="$a"; done
    T="${T%/}"; P="${P%\*}"
    [ -n "$P" ] && [ -d "$S" ] && for f in "$S"/*"$P"*.tar.gz; do [ -f "$f" ] && cp "$f" "$T/" 2>/dev/null; done
    ;;
esac
exit 0
MOCKEOF
chmod +x /opt/Alibaba/ossutil64
echo "mock ossutil64 OK"

echo ""
echo "=== [2/5] 创建模拟 tar.gz 数据 ==="
TDATE="20260625"
C1="${TDATE}000000_DHM_20250531133810"
C2="${TDATE}000000_DHM_20250531133922"

# input 文件1 (含目标字段)
rm -rf /tmp/build_test
mkdir -p "/tmp/build_test/${C1}/BasicInfo"
echo "# CaseName 方案名称 UC-测试方案" > "/tmp/build_test/${C1}/BasicInfo/BasicInfo.txt"
echo "test data 1" > "/tmp/build_test/${C1}/data.txt"
cd /tmp/build_test && tar -czf "/tmp/oss_mock_data/${C1}.tar.gz" "${C1}"
echo "创建: ${C1}.tar.gz (含目标字段)"

# output 文件1
mkdir -p "/tmp/build_test/${C1}_output/result"
echo "output data 1" > "/tmp/build_test/${C1}_output/result/out.txt"
cd /tmp/build_test && tar -czf "/tmp/oss_mock_data/${C1}_output.tar.gz" "${C1}_output"
echo "创建: ${C1}_output.tar.gz"

# input 文件2 (不含目标字段)
mkdir -p "/tmp/build_test/${C2}/BasicInfo"
echo "no match data" > "/tmp/build_test/${C2}/BasicInfo/BasicInfo.txt"
cd /tmp/build_test && tar -czf "/tmp/oss_mock_data/${C2}.tar.gz" "${C2}"
echo "创建: ${C2}.tar.gz (不含目标字段)"

# output 文件2
mkdir -p "/tmp/build_test/${C2}_output/result"
echo "output data 2" > "/tmp/build_test/${C2}_output/result/out.txt"
cd /tmp/build_test && tar -czf "/tmp/oss_mock_data/${C2}_output.tar.gz" "${C2}_output"
echo "创建: ${C2}_output.tar.gz"

rm -rf /tmp/build_test
echo "模拟数据创建完成"

echo ""
echo "=== [3/5] 清空输出目录 ==="
rm -rf /mnt/data/oss/DHM/IN/* 2>/dev/null || true
rm -rf /tmp/oss_data/* 2>/dev/null || true
rm -rf /tmp/oss_extract_tmp/* 2>/dev/null || true

echo ""
echo "=== [4/5] 运行 oss_extract_process.sh ==="
echo "========================================"
bash /tmp/extract_test.sh "$TDATE" 2>&1 || true
RC=$?
echo "========================================"
echo "脚本退出码: ${RC}"

echo ""
echo "=== [5/5] 结果验证 ==="
echo ""
echo "--- PREDICT_DIR 输出结构 ---"
find /mnt/data/oss/DHM/IN/ -type f -o -type d 2>/dev/null | head -30 || echo "(空)"
echo ""
echo "--- 根目录 / 安全检查 ---"
echo "根目录条目: $(ls / | wc -l)"
echo "根目录关键文件检查:"
ls -la /etc/passwd /etc/shadow /bin/bash 2>&1 | head -5
echo ""
echo "--- /tmp 残留检查 ---"
echo "oss_data:      $(ls /tmp/oss_data/ 2>/dev/null | wc -l) 个文件"
echo "oss_extract_tmp: $(ls /tmp/oss_extract_tmp/ 2>/dev/null | wc -l) 个文件"
echo ""
echo "✅ 测试完成"
