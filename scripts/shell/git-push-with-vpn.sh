#!/bin/bash
# 🔧 2026-07-21 Reasonix：Git 推送自动 VPN 切换脚本（修复版）
# 🔧 2026-07-22 Claude：5 处安全修复（local代理/trap清理/系统代理/VPN停止/--stop模式）
#
# 用法：
#   bash scripts/shell/git-push-with-vpn.sh          # 推送 main（默认）
#   bash scripts/shell/git-push-with-vpn.sh "msg"    # 带提交信息
#   bash scripts/shell/git-push-with-vpn.sh --stop   # 停止 VPN + 清除所有代理残留
#
# 流程：先直接推 → 失败则开 v2rayN 走代理重试 → 再失败则切换线路 → 退出时自动清理代理

# ============================================================
# 配置（v2rayN）
# ============================================================
V2RAYN_EXE="D:/v2rayN-windows-64/v2rayN.exe"
PROXY_SOCKS5="socks5h://127.0.0.1:10808"
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
# 检测 v2rayN 是否运行（检查 SOCKS5 端口）
# ============================================================
is_v2ray_running() {
  timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/10808" 2>/dev/null
}

# ============================================================
# 启动 v2rayN
# ============================================================
start_v2ray() {
  info "启动 v2rayN..."
  # 如果已经在运行就不重复启动
  if is_v2ray_running; then
    info "v2rayN 已在运行"
    return 0
  fi
  powershell -Command "Start-Process -FilePath '$V2RAYN_EXE' -Verb RunAs" >/dev/null 2>&1 || true
  # 等待就绪（最多 15 秒）
  for i in $(seq 1 15); do
    if is_v2ray_running; then
      info "v2rayN 就绪（${i}s）"
      return 0
    fi
    sleep 1
  done
  warn "v2rayN 启动超时，检查是否以管理员权限启动"
  return 1
}

# ============================================================
# 设置 / 清除 Git 代理
# ============================================================
set_git_proxy() {
  info "设置 Git 代理（SOCKS5 127.0.0.1:10808，仅当前仓库）..."
  # 🔧 2026-07-22 Claude：改为 --local，不污染全局 Git 配置
  git config --local http.proxy "$PROXY_SOCKS5" 2>/dev/null || true
  git config --local https.proxy "$PROXY_SOCKS5" 2>/dev/null || true
}

unset_git_proxy() {
  info "清除 Git 代理（当前仓库）..."
  git config --local --unset http.proxy 2>/dev/null || true
  git config --local --unset https.proxy 2>/dev/null || true
}

# 🔧 2026-07-22 Claude：新增 — 清除 Windows 系统代理残留
unset_system_proxy() {
  info "清除 Windows 系统代理..."
  # 关闭系统代理开关
  cmd.exe /c "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyEnable /t REG_DWORD /d 0 /f" 2>/dev/null || true
  # 清除残留的代理服务器地址
  cmd.exe /c "reg delete \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyServer /f 2>NUL" 2>/dev/null || true
  # 重置 WinHTTP 代理
  cmd.exe /c "netsh winhttp reset proxy" >/dev/null 2>&1 || true
  info "系统代理已清除"
}

# 🔧 2026-07-22 Claude：新增 — 停止 v2rayN 进程
stop_v2ray_if_running() {
  if ! is_v2ray_running; then
    return 0
  fi
  info "停止 v2rayN..."
  # 尝试正常关闭
  cmd.exe /c "taskkill /IM v2rayN.exe 2>NUL" 2>/dev/null || true
  sleep 2
  # 如果还在，强制终止
  if is_v2ray_running; then
    cmd.exe /c "taskkill /F /IM v2rayN.exe 2>NUL" 2>/dev/null || true
    sleep 1
  fi
  info "v2rayN 已停止"
}

# 🔧 2026-07-22 Claude：新增 — 完整清理（trap 调用）
cleanup() {
  local exit_code=$?
  unset_git_proxy
  unset_system_proxy
  # 推送成功时停止 VPN（失败时保留让用户排查）
  if [ $exit_code -eq 0 ]; then
    stop_v2ray_if_running
  fi
  exit $exit_code
}

# 🔧 2026-07-22 Claude：捕获退出信号确保清理（Ctrl+C / 异常 / 正常结束）
trap cleanup EXIT SIGINT SIGTERM

# ============================================================
# 执行 Git 推送（自动判断当前分支）
# ============================================================
do_git_push() {
  local commit_msg="$1"

  # 获取当前分支
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  # 检查是否有未提交的改动
  if ! git diff --quiet HEAD 2>/dev/null; then
    if [ -n "$commit_msg" ]; then
      info "提交更改：${commit_msg}"
      git add -A
      git commit -m "${commit_msg}" || true
    else
      warn "有未提交的更改，跳过提交检查。如有需要请先 git commit"
    fi
  fi

  # 在 workspace 分支才推 workspace:main，否则推 current:main
  if [ "$current_branch" = "workspace" ]; then
    info "推送：git push $GIT_REMOTE $LOCAL_BRANCH:$GIT_TARGET"
    if git push "$GIT_REMOTE" "$LOCAL_BRANCH:$GIT_TARGET" 2>&1; then
      info "推送成功！"
      return 0
    fi
  else
    info "当前分支：${current_branch}，推送：git push $GIT_REMOTE ${current_branch}:$GIT_TARGET"
    if git push "$GIT_REMOTE" "$current_branch:$GIT_TARGET" 2>&1; then
      info "推送成功！"
      return 0
    fi
  fi
  return 1
}

# ============================================================
# 切换 v2rayN 线路（通过 Clash API）
# ============================================================
switch_v2ray_line() {
  local api="http://127.0.0.1:9090"
  info "切换 v2rayN 线路..."

  # 先测试 Clash API 是否可用
  local api_ok
  api_ok=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$api" 2>/dev/null || echo "000")
  if [ "$api_ok" = "000" ]; then
    warn "Clash API 不可达（${api}），跳过线路切换"
    return 1
  fi

  # 获取代理列表
  local proxies
  proxies=$(curl -s "$api/proxies" 2>/dev/null)

  if [ -z "$proxies" ]; then
    warn "无法获取代理列表，跳过切换"
    return 1
  fi

  # 查找代理选择器
  local selector_name=""
  selector_name=$(echo "$proxies" | grep -o '"type":"Selector"' -B10 | grep -oP '"name":"[^"]*"' | head -1 | sed 's/"//g' | sed 's/name://g' || echo "")

  if [ -z "$selector_name" ]; then
    warn "未找到节点选择器，跳过切换"
    return 1
  fi

  # 获取当前节点和所有可用节点
  local now_name
  now_name=$(echo "$proxies" | grep -A20 "\"${selector_name}\"" | grep '"now"' | grep -oP '"now":"[^"]*"' | sed 's/"//g' | sed 's/now://g' || echo "")

  # 获取所有节点列表
  local all_names
  all_names=$(echo "$proxies" | grep -A50 "\"${selector_name}\"" | grep '"all"' -A50 | grep -oP '"[^"]*"' | tail -n +2 || echo "")

  # 选下一个节点
  local next_node=""
  local found_curr=false
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    line=$(echo "$line" | sed 's/"//g' | sed 's/,//g')
    [ -z "$line" ] && continue
    if [ "$found_curr" = true ] && [ "$line" != "$now_name" ]; then
      next_node="$line"
      break
    fi
    [ "$line" = "$now_name" ] && found_curr=true
  done <<< "$all_names"

  if [ -z "$next_node" ]; then
    warn "无可用线路切换"
    return 1
  fi

  info "切换线路：$now_name → $next_node"
  curl -s -X PUT "$api/proxies/$selector_name" \
    -d "{\"name\":\"${next_node}\"}" \
    -H "Content-Type: application/json" > /dev/null 2>&1 || true
  sleep 1
  return 0
}

# ============================================================
# 主流程
# ============================================================
main() {
  local commit_msg="${1:-}"

  # 🔧 2026-07-22 Claude：新增 --stop 模式 — 停止 VPN 并清理所有代理残留
  if [ "$commit_msg" = "--stop" ]; then
    echo ""
    info "====== VPN 停止 + 代理清理 ======"
    echo ""
    stop_v2ray_if_running
    unset_git_proxy
    unset_system_proxy
    echo ""
    info "====== 清理完成，请尝试重新登录钉钉 ======"
    return 0
  fi

  echo ""
  info "====== Git 推送（带 VPN 自动切换）======"
  echo ""

  # 第 1 次：直连
  warn "▶ 第 1 次尝试：直连推送"
  if do_git_push "$commit_msg"; then
    info "直连推送成功，无需 VPN"
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi
  warn "直连推送失败"

  # 第 2 次：开 VPN
  echo ""
  warn "▶ 第 2 次尝试：启动 v2rayN + 代理推送"
  start_v2ray || true
  set_git_proxy

  if do_git_push "$commit_msg"; then
    info "VPN 代理推送成功（trap 将自动清理代理）"
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi

  # 第 3 次：切换线路
  echo ""
  warn "▶ 第 3 次尝试：切换 VPN 线路后重试"
  switch_v2ray_line || true
  sleep 2

  if do_git_push "$commit_msg"; then
    info "切换线路后推送成功（trap 将自动清理代理）"
    echo ""
    info "====== 推送完成 ======"
    return 0
  fi

  # 全部失败
  echo ""
  error "====== 推送失败（已尝试直连 → VPN → 切换线路）======"
  error "v2rayN 仍在运行中（保留用于手动排查）"
  error "如需清理代理残留，运行：bash scripts/shell/vpn-cleanup.sh"
  return 1
}

main "$@"
