#!/bin/bash
# Git pre-push hook 自动化测试脚本
# 在临时仓库中模拟各种推送场景，验证 hook 行为
# 用法: bash scripts/shell/test-pre-push-hook.sh

set -euo pipefail

# 解析 hook 脚本的绝对路径（防止 cd 后找不到）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/git-pre-push-hook.sh"

PASS=0
FAIL=0

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 hook 文件
if [[ ! -f "$HOOK_SCRIPT" ]]; then
    echo -e "${RED}错误: 找不到 $HOOK_SCRIPT${NC}"
    exit 1
fi

# 创建持久化的临时目录
BARE_DIR=$(mktemp -d /tmp/test-hook-bare.XXXXXX)
TEMP_DIR=$(mktemp -d /tmp/test-hook-local.XXXXXX)

cleanup() {
    [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]] && rm -rf "$TEMP_DIR"
    [[ -n "${BARE_DIR:-}" && -d "${BARE_DIR:-}" ]] && rm -rf "$BARE_DIR"
}
trap cleanup EXIT

# ============================================================
# 辅助函数
# ============================================================

# 运行 hook 并验证退出码
# $1: 测试名称
# $2: 期望的退出码 (0 或 1)
# $3: stdin 行（模拟 git 传给 hook 的数据）
# $4: bare 目录路径
# $5: 可选 env var 覆盖 "SKIP=1"
run_test() {
    local name="$1"
    local expected_exit="$2"
    local stdin_data="$3"
    local bare="$4"
    local skip_flag="${5:-}"

    local actual_exit=0
    if [[ "$skip_flag" == "SKIP=1" ]]; then
        echo "$stdin_data" | SKIP_BACKUP_HOOK=1 bash "$HOOK_SCRIPT" origin "$bare" >/dev/null 2>&1 || actual_exit=$?
    else
        echo "$stdin_data" | bash "$HOOK_SCRIPT" origin "$bare" >/dev/null 2>&1 || actual_exit=$?
    fi

    if [[ $actual_exit -eq $expected_exit ]]; then
        echo -e "  ${GREEN}PASS${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $name (期望 exit=$expected_exit, 实际 exit=$actual_exit)"
        echo "  --- 调试输出 ---"
        echo "$stdin_data" | bash "$HOOK_SCRIPT" origin "$bare" 2>&1 || true
        echo "  -----------------"
        FAIL=$((FAIL + 1))
    fi
}

# 在远程 bare 仓库运行测试（创建初始提交）
setup_repo() {
    local bare="$1"
    local work="$2"
    local with_remote_main="${3:-yes}"  # 是否先推送一次 main

    git init --bare "$bare" --quiet
    git init "$work" --quiet
    cd "$work"
    git remote add origin "$bare"

    echo "init" > README.md
    git add README.md
    git commit -m "initial commit" --quiet

    if [[ "$with_remote_main" == "yes" ]]; then
        git push origin main --quiet 2>/dev/null || true
    fi
}

echo "============================================"
echo "  Git Pre-Push Hook 测试套件"
echo "============================================"

ZERO="0000000000000000000000000000000000000000"

# ============================================================
# 测试集 1：分支策略（有远程 main 的仓库）
# ============================================================
echo ""
echo "--- 测试集 1：分支策略（有远程 main） ---"

setup_repo "$BARE_DIR" "$TEMP_DIR" "yes"
MAIN_SHA=$(cd "$TEMP_DIR" && git rev-parse HEAD)

run_test "推送到 main" 0 \
    "refs/heads/main $MAIN_SHA refs/heads/main $MAIN_SHA" \
    "$BARE_DIR"

run_test "推送到 workspace（应阻止）" 1 \
    "refs/heads/workspace $MAIN_SHA refs/heads/workspace $MAIN_SHA" \
    "$BARE_DIR"

run_test "推送到 feature/test（应阻止）" 1 \
    "refs/heads/feature/test $MAIN_SHA refs/heads/feature/test $MAIN_SHA" \
    "$BARE_DIR"

run_test "混合推送 main + workspace（应阻止）" 1 \
    "refs/heads/main $MAIN_SHA refs/heads/main $MAIN_SHA
refs/heads/workspace $MAIN_SHA refs/heads/workspace $MAIN_SHA" \
    "$BARE_DIR"

run_test "删除 main 分支（应阻止）" 1 \
    "refs/heads/main $ZERO refs/heads/main $MAIN_SHA" \
    "$BARE_DIR"

run_test "删除 feature 分支（应放行）" 0 \
    "refs/heads/feature/test $ZERO refs/heads/feature/test $MAIN_SHA" \
    "$BARE_DIR"

# ============================================================
# 测试集 2：防递归
# ============================================================
echo ""
echo "--- 测试集 2：防递归 ---"

run_test "推送到 backup/main-* 分支（防递归）" 0 \
    "refs/heads/backup/main-20260709-120000 $MAIN_SHA refs/heads/backup/main-20260709-120000 $MAIN_SHA" \
    "$BARE_DIR"

run_test "SKIP_BACKUP_HOOK=1 放行（推送到 workspace）" 0 \
    "refs/heads/workspace $MAIN_SHA refs/heads/workspace $MAIN_SHA" \
    "$BARE_DIR" "SKIP=1"

# ============================================================
# 测试集 3：首次推送（远程无 main）
# ============================================================
echo ""
echo "--- 测试集 3：首次推送（远程无 main） ---"

BARE2=$(mktemp -d /tmp/test-hook-bare2.XXXXXX)
WORK2=$(mktemp -d /tmp/test-hook-work2.XXXXXX)
setup_repo "$BARE2" "$WORK2" "no"
FIRST_SHA=$(cd "$WORK2" && git rev-parse HEAD)

run_test "首次推送到 main（远程无 main）" 0 \
    "refs/heads/main $FIRST_SHA refs/heads/main $ZERO" \
    "$BARE2"

# 验证：首次推送不应创建备份
BACKUP_COUNT=$(cd "$WORK2" && git branch --list "backup/main-*" 2>/dev/null | wc -l || echo 0)
echo "  首次推送本地备份分支数: $BACKUP_COUNT (期望 0)"

rm -rf "$BARE2" "$WORK2"

# ============================================================
# 测试集 4：备份创建（需要远程可访问的测试）
# ============================================================
echo ""
echo "--- 测试集 4：备份创建 ---"

BARE3=$(mktemp -d /tmp/test-hook-bare3.XXXXXX)
WORK3=$(mktemp -d /tmp/test-hook-work3.XXXXXX)
setup_repo "$BARE3" "$WORK3" "yes"

# 做一个新提交，模拟真实推送
cd "$WORK3"
echo "v2" >> README.md
git add README.md
git commit -m "v2" --quiet
V2_SHA=$(git rev-parse HEAD)
V1_SHA=$(git rev-parse HEAD~1)

# 用 remote_oid = V1_SHA（即推送前远程 main 的 SHA）
run_test "正常 main 推送，remote_oid 指向旧 main" 0 \
    "refs/heads/main $V2_SHA refs/heads/main $V1_SHA" \
    "$BARE3"

# 检查备份是否在远程 bare 中被创建
BACKUP_REFS=$(cd "$BARE3" && git branch --list "backup/main-*" 2>/dev/null || true)
echo "  远程备份分支: $BACKUP_REFS"

rm -rf "$BARE3" "$WORK3"

# ============================================================
# 测试集 5：过期清理
# ============================================================
echo ""
echo "--- 测试集 5：过期清理 ---"

BARE4=$(mktemp -d /tmp/test-hook-bare4.XXXXXX)
WORK4=$(mktemp -d /tmp/test-hook-work4.XXXXXX)
setup_repo "$BARE4" "$WORK4" "yes"
SHA4=$(cd "$WORK4" && git rev-parse HEAD)

# 创建一个超过 180 天的旧备份分支
cd "$WORK4"
OLD_BACKUP="backup/main-20200101-000000"
git branch "$OLD_BACKUP" HEAD

run_test "清理过期备份（180天前）" 0 \
    "refs/heads/main $SHA4 refs/heads/main $SHA4" \
    "$BARE4"

# 检查旧备份是否被删除
if git rev-parse --verify "refs/heads/$OLD_BACKUP" >/dev/null 2>&1; then
    echo -e "  ${YELLOW}WARN${NC} 旧备份 '$OLD_BACKUP' 未被删除（可能 date -d 不可用）"
else
    echo -e "  ${GREEN}PASS${NC} 旧备份 '$OLD_BACKUP' 已被自动清理"
    PASS=$((PASS + 1))
fi

# 新备份应保留
RECENT_BACKUP="backup/main-20260708-120000"
git branch "$RECENT_BACKUP" HEAD

run_test "保留近期备份" 0 \
    "refs/heads/main $SHA4 refs/heads/main $SHA4" \
    "$BARE4"

if git rev-parse --verify "refs/heads/$RECENT_BACKUP" >/dev/null 2>&1; then
    echo -e "  ${GREEN}PASS${NC} 近期备份 '$RECENT_BACKUP' 被正确保留"
    PASS=$((PASS + 1))
    git branch -D "$RECENT_BACKUP" 2>/dev/null || true
else
    echo -e "  ${YELLOW}WARN${NC} 近期备份 '$RECENT_BACKUP' 被误删"
fi

rm -rf "$BARE4" "$WORK4"

# ============================================================
# 测试集 6：空输入
# ============================================================
echo ""
echo "--- 测试集 6：边界情况 ---"

run_test "空 stdin 输入" 0 "" "$BARE_DIR"

# ============================================================
# 结果
# ============================================================
echo ""
echo "============================================"
echo -e "  结果: ${GREEN}$PASS 通过${NC}, ${RED}$FAIL 失败${NC}"
echo "============================================"

cd "$OLDPWD" 2>/dev/null || true
exit $FAIL
