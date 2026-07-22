#!/bin/bash
# ============================================================================
# vpn-cleanup.sh — VPN 停止 + 系统代理清除 + 网络修复
# ============================================================================
# 🔧 2026-07-22 Claude：新建脚本，解决 VPN 停止后代理残留导致钉钉/浏览器无法联网
#
# 用法：
#   bash scripts/shell/vpn-cleanup.sh            # 停止 VPN + 清除所有代理残留
#   bash scripts/shell/vpn-cleanup.sh --dry-run  # 仅检查状态，不做实际操作
#
# 场景：
#   - VPN 推送脚本执行后网络异常 → 运行此脚本修复
#   - 钉钉无法登录 → 运行此脚本清除系统代理
#   - v2rayN 异常退出后网络全部不通 → 运行此脚本清理
# ============================================================================

# ============================================================
# 配置
# ============================================================
V2RAYN_PROCESS="v2rayN.exe"
V2RAYN_EXE="D:/v2rayN-windows-64/v2rayN.exe"
SOCKS5_PORT="10808"
HTTP_PORT="7890"
CLASH_API_PORT="9090"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[cleanup]${NC} $1"; }
warn()  { echo -e "${YELLOW}[cleanup]${NC} $1"; }
error() { echo -e "${RED}[cleanup]${NC} $1"; }
step()  { echo -e "${CYAN}[cleanup]${NC} ==> $1"; }
check() {
    if [ "$1" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${YELLOW}✗${NC} $2"
    fi
}

# ============================================================
# 检测函数
# ============================================================

# 检测 v2rayN 进程是否在运行
is_v2ray_running() {
    local result
    result=$(cmd.exe /c "tasklist /FI \"IMAGENAME eq ${V2RAYN_PROCESS}\" 2>NUL" 2>/dev/null || true)
    if echo "$result" | grep -qi "${V2RAYN_PROCESS}"; then
        return 0
    fi
    return 1
}

# 检测 Windows 系统代理是否开启（通过注册表）
is_system_proxy_enabled() {
    local result
    result=$(cmd.exe /c "reg query \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyEnable 2>NUL" 2>/dev/null || true)
    if echo "$result" | grep -qi "0x1"; then
        return 0
    fi
    return 1
}

# 检测 Git 全局代理是否设置
has_git_global_proxy() {
    local http_proxy
    http_proxy=$(git config --global http.proxy 2>/dev/null || echo "")
    if [ -n "$http_proxy" ]; then
        return 0
    fi
    return 1
}

# 检测代理端口是否在监听
is_port_listening() {
    local port="$1"
    timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/${port}" 2>/dev/null
}

# ============================================================
# 清理函数
# ============================================================

# 1. 停止 v2rayN 进程（优雅 → 强制）
stop_v2ray() {
    step "步骤 1/5：停止 v2rayN 进程"
    echo ""

    if ! is_v2ray_running; then
        info "v2rayN 未在运行，跳过"
        return 0
    fi

    info "检测到 v2rayN 正在运行，尝试优雅关闭..."

    # 尝试正常关闭（通过 Clash API 发送 shutdown 信号，如果可用）
    local api_ok
    api_ok=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://127.0.0.1:${CLASH_API_PORT}" 2>/dev/null || echo "000")
    if [ "$api_ok" != "000" ]; then
        info "通过 Clash API 发送关闭信号..."
        # 先关闭 TUN 模式，避免虚拟网卡残留
        curl -s -X PATCH "http://127.0.0.1:${CLASH_API_PORT}/configs" \
            -d '{"mode":"rule"}' \
            -H "Content-Type: application/json" > /dev/null 2>&1 || true
        sleep 2
    fi

    # 关闭 v2rayN 窗口（非强制）
    cmd.exe /c "taskkill /IM ${V2RAYN_PROCESS} 2>NUL" 2>/dev/null || true
    sleep 2

    # 检查是否已退出
    if ! is_v2ray_running; then
        info "v2rayN 已正常退出"
        return 0
    fi

    # 仍存活 → 强制终止
    warn "v2rayN 未正常退出，强制终止..."
    cmd.exe /c "taskkill /F /IM ${V2RAYN_PROCESS} 2>NUL" 2>/dev/null || true
    sleep 2

    if is_v2ray_running; then
        warn "v2rayN 未能完全停止（可能需要管理员权限）"
        return 1
    fi

    info "v2rayN 已强制终止"
    return 0
}

# 2. 清除 Windows 系统代理
unset_system_proxy() {
    step "步骤 2/5：清除 Windows 系统代理"
    echo ""

    if is_system_proxy_enabled; then
        warn "检测到系统代理已开启，正在关闭..."

        # 关闭代理开关（注册表 ProxyEnable → 0）
        cmd.exe /c "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyEnable /t REG_DWORD /d 0 /f" 2>/dev/null || true

        # 清除代理服务器地址（如果有残留）
        cmd.exe /c "reg delete \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyServer /f 2>NUL" 2>/dev/null || true
        cmd.exe /c "reg delete \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyOverride /f 2>NUL" 2>/dev/null || true

        # 验证
        if is_system_proxy_enabled; then
            warn "系统代理关闭可能未生效，请手动检查：设置 → 网络和 Internet → 代理"
        else
            info "系统代理已关闭"
        fi
    else
        info "系统代理未开启，跳过"
    fi
}

# 3. 重置 WinHTTP 代理
reset_winhttp_proxy() {
    step "步骤 3/5：重置 WinHTTP 代理"
    echo ""

    # netsh winhttp reset proxy → 清除 WinHTTP 层代理（影响部分系统服务和应用）
    local result
    result=$(cmd.exe /c "netsh winhttp reset proxy 2>&1" 2>/dev/null || true)
    echo "  $result"
    info "WinHTTP 代理已重置"
}

# 4. 清除 Git 全局代理
unset_git_proxy() {
    step "步骤 4/5：清除 Git 全局代理"
    echo ""

    local had_proxy=false

    if has_git_global_proxy; then
        had_proxy=true
        local hp
        hp=$(git config --global http.proxy 2>/dev/null || echo "")
        warn "Git 全局代理已设置：${hp}"
    fi

    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true

    # 同时清理本地仓库级别（如果在工作空间内执行）
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git config --local --unset http.proxy 2>/dev/null || true
        git config --local --unset https.proxy 2>/dev/null || true
    fi

    if $had_proxy; then
        info "Git 代理已清除"
    else
        info "Git 全局代理未设置，跳过"
    fi
}

# 5. 刷新 DNS
flush_dns() {
    step "步骤 5/5：刷新 DNS 缓存"
    echo ""

    local result
    result=$(cmd.exe /c "ipconfig /flushdns 2>&1" 2>/dev/null || true)
    echo "  $result" | head -3
    info "DNS 缓存已刷新"
}

# ============================================================
# 状态检查（--dry-run）
# ============================================================
dry_run() {
    echo ""
    echo -e "${CYAN}========== VPN 代理状态检查 ==========${NC}"
    echo ""

    # v2rayN 进程
    echo -n "v2rayN 进程：      "
    if is_v2ray_running; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${YELLOW}未运行${NC}"
    fi

    # 代理端口
    echo -n "SOCKS5 端口 10808："
    if is_port_listening "$SOCKS5_PORT"; then
        echo -e "${GREEN}监听中${NC}"
    else
        echo -e "${YELLOW}未监听${NC}"
    fi

    echo -n "HTTP 端口 7890：   "
    if is_port_listening "$HTTP_PORT"; then
        echo -e "${GREEN}监听中${NC}"
    else
        echo -e "${YELLOW}未监听${NC}"
    fi

    # 系统代理
    echo -n "Windows 系统代理： "
    if is_system_proxy_enabled; then
        echo -e "${RED}已开启 ← 可能导致钉钉/浏览器无法联网！${NC}"
        # 读取代理服务器地址
        local proxy_server
        proxy_server=$(cmd.exe /c "reg query \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\" /v ProxyServer 2>NUL" 2>/dev/null | grep -oP '[^\s]+$' || echo "（无）")
        echo "  代理地址：${proxy_server}"
    else
        echo -e "${GREEN}未开启${NC}"
    fi

    # Git 代理
    echo -n "Git 全局代理：     "
    if has_git_global_proxy; then
        echo -e "${RED}已设置 ← 可能影响 Git 操作${NC}"
        echo "  http.proxy = $(git config --global http.proxy 2>/dev/null || echo '(无)')"
    else
        echo -e "${GREEN}未设置${NC}"
    fi

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "如发现 ${RED}红色${NC} 项目，运行以下命令修复："
    echo "  bash scripts/shell/vpn-cleanup.sh"
    echo ""
    return 0
}

# ============================================================
# 主流程
# ============================================================
main() {
    local mode="${1:-}"

    # --dry-run 只检查状态
    if [ "$mode" = "--dry-run" ]; then
        dry_run
        return 0
    fi

    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  VPN 停止 + 网络代理清理${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    local all_ok=true

    # 执行 5 个步骤
    stop_v2ray || all_ok=false
    echo ""

    unset_system_proxy || all_ok=false
    echo ""

    reset_winhttp_proxy || all_ok=false
    echo ""

    unset_git_proxy || all_ok=false
    echo ""

    flush_dns || all_ok=false
    echo ""

    # ============================================================
    # 结果汇总
    # ============================================================
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  清理完成 — 状态检查${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    # 重新检测并报告
    echo "v2rayN 进程：      $(is_v2ray_running && echo -e '${GREEN}仍运行（可手动关闭）${NC}' || echo -e '${GREEN}已停止${NC}')"
    echo "Windows 系统代理： $(is_system_proxy_enabled && echo -e '${RED}仍开启⚠️${NC}' || echo -e '${GREEN}已关闭${NC}')"
    echo "Git 全局代理：     $(has_git_global_proxy && echo -e '${RED}仍设置⚠️${NC}' || echo -e '${GREEN}已清除${NC}')"

    echo ""
    if $all_ok; then
        info "全部清理操作已完成。请尝试重新登录钉钉。"
    else
        warn "部分操作未完全成功，如有网络问题请尝试手动："
        echo ""
        echo "  手动关闭代理："
        echo "    设置 → 网络和 Internet → 代理 → 关闭'使用代理服务器'"
        echo ""
        echo "  手动杀 v2rayN："
        echo "    任务管理器 → 找到 v2rayN.exe → 结束任务"
    fi

    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

main "$@"
