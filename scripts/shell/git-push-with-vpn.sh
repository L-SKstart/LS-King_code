#!/bin/bash
# 🔧 2026-07-15 Reasonix：Git 推送自动 VPN 切换脚本
#
# 用法：
#   bash scripts/shell/git-push-with-vpn.sh          # 推送 main（默认）
#   bash scripts/shell/git-push-with-vpn.sh "commit msg"  # 带提交信息
#
# 流程：先直接推 → 失败则开 v2rayN 走代理重试 → 再失败则切换线路 → 最终清理

set -e

# ============================================================
# 配置（v2rayN）
# ============================================================
V2RAYN_EXE="D:/v2rayN-windows-64/v2rayN.exe"
CLASH_API="http://127.0.0.1:9090"
PROXY_SOCKS5="socks5h://127.0.0.1:10808"
PROXY_HTTP="http://127.0.0.1:7890"
GIT_REMOTE="origin"
GIT_TARGET="main"
LOCAL_BRANCH="workspace"

# ============================================================
# 颜色
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# 检测 v2rayN 是否运行
# ============================================================
is_v2ray_running() {
  curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$CLASH_API" 2>/dev/null | grep -q "200\|400\|404"
}

# ============================================================
# 启动 v2rayN（以管理员身份）
# ============================================================
start_v2ray() {
  info "启动 v2rayN..."
  # 以管理员身份启动
  powershell -Command "Start-Process -FilePath '$V2RAYN_EXE' -Verb RunAs"
  # 等待 Clash API 就绪（最多 15 秒）
  for i in $(seq 1 15); do
    if is_v2ray_running; then
      info "v2rayN 就绪（${i}s）"
      return 0
    fi
    sleep 1
  done
  warn "v2rayN 启动超时，但可能仍在后台启动中"
  return 0
}

# ============================================================
# 设置 Git 代理
# ============================================================
set_git_proxy() {
  info "设置 Git 代理（SOCKS5 127.0.0.1:10808）..."
  git config http.proxy "$PROXY_SOCKS5"
  git config https.proxy "$PROXY_SOCKS5"
}

# ============================================================
# 清除 Git 代理
# ============================================================
unset_git_proxy() {
  info "清除 Git 代理..."
  git config --unset http.proxy 2>/dev/null || true
  git config --unset https.proxy 2>/dev/null || true
}

# ============================================================
# 切换 v2rayN 线路（通过 Clash API）
# ============================================================
switch_v2ray_line() {
  info "切换 v2rayN 线路..."

  # 获取代理列表
  local proxies
  proxies=$(curl -s "$CLASH_API/proxies" 2>/dev/null)

  if [ -z "$proxies" ]; then
    warn "无法获取代理列表，跳过切换"
    return 1
  fi

  # 查找代理选择器（通常是 "Proxy" 或 "🚀 节点选择" 等名称）
  local selector_name
  selector_name=$(echo "$proxies" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for name, info in data.get('proxies', {}).items():
        t = info.get('type', '')
        if t == 'Selector':
            print(name)
            sys.exit(0)
    print('')
except:
    print('')
" 2>/dev/null)

  if [ -z "$selector_name" ]; then
    warn "未找到节点选择器"
    return 1
  fi

  # 获取当前选中节点
  local now_name
  now_name=$(echo "$proxies" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    selector_name = '$selector_name'
    now = data['proxies'].get(selector_name, {}).get('now', '')
    print(now)
except:
    print('')
" 2>/dev/null)

  # 获取所有可选节点
  local all_names
  all_names=$(echo "$proxies" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    selector_name = '$selector_name'
    all_n = data['proxies'].get(selector_name, {}).get('all', [])
    for n in all_n:
        print(n)
except:
    print('')
" 2>/dev/null)

  # 找下一个不同节点
  local next_node=""
  local found_curr=false
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$found_curr" = true ]; then
      next_node="$line"
      break
    fi
    [ "$line" = "$now_name" ] && found_curr=true
  done <<< "$all_names"

  # 如果没找到下一个，用第一个
  if [ -z "$next_node" ]; then
    next_node=$(echo "$all_names" | head -1)
  fi

  # 如果当前节点就是下一个节点，选第二个
  if [ "$next_node" = "$now_name" ] || [ -z "$next_node" ]; then
    next_node=$(echo "$all_names" | sed -n '2p')
  fi

  if [ -n "$next_node" ] && [ "$next_node" != "$now_name" ]; then
    info "切换线路：$now_name → $next_node"
    curl -s -X PUT "$CLASH_API/proxies/$selector_name" -d "{\"name\":\"$next_node\"}" -H "Content-Type: application/json" > /dev/null
    sleep 1
    return 0
  fi

  warn "无可用线路切换"
  return 1
}

# ============================================================
# 执行 Git 推送
# ============================================================
do_git_push() {
  local commit_msg="$1"

  # 检查是否有改动
  if ! git diff --quiet HEAD 2>/dev/null; then
    info "有未提交的更改，执行 git add + commit..."
    git add -A
    git commit -m "${commit_msg:-自动提交 $(date '+%Y-%m-%d %H:%M:%S')}"
  fi

  info "切换到 workspace 分支..."
  git checkout workspace 2>/dev/null || true

  info "推送：git push $GIT_REMOTE $LOCAL_BRANCH:$GIT_TARGET"
  if git push "$GIT_REMOTE" "$LOCAL_BRANCH:$GIT_TARGET" 2>&1; then
    info "推送成功！"
    return 0
  else
    return 1
  fi
}

# ============================================================
# 主流程
# ============================================================
main() {
  local commit_msg="${1:-}"

  echo ""
  info "====== Git 推送（带 VPN 自动切换）======"
  echo ""

  # ---------- 第 1 次尝试：直连 ----------
  warn "▶ 第 1 次尝试：直连推送"
  if do_git_push "$commit_msg"; then
    info "直连推送成功，无需 VPN"
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi
  warn "直连推送失败"

  # ---------- 第 2 次尝试：开 VPN + 代理 ----------
  echo ""
  warn "▶ 第 2 次尝试：启动 v2rayN + 代理推送"

  # 如果 v2rayN 没运行就启动
  if ! is_v2ray_running; then
    start_v2ray
  fi

  set_git_proxy

  if do_git_push "$commit_msg"; then
    info "VPN 代理推送成功"
    unset_git_proxy
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi

  # ---------- 第 3 次尝试：切换线路 ----------
  echo ""
  warn "▶ 第 3 次尝试：切换 VPN 线路后重试"

  switch_v2ray_line || true
  sleep 2

  if do_git_push "$commit_msg"; then
    info "切换线路后推送成功"
    unset_git_proxy
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi

  # ---------- 全部失败 ----------
  unset_git_proxy
  echo ""
  error "====== 推送失败（已尝试直连 → VPN → 切换线路）======"
  error "请手动检查网络或 v2rayN 状态"
  return 1
}

main "$@"
