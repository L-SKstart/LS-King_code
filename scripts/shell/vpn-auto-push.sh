#!/bin/bash
# ============================================================================
# vpn-auto-push.sh — Git 推送失败时自动启动 VPN 并重试，不行则切换 VPN 线路
# ============================================================================
# 用法：
#   bash scripts/shell/vpn-auto-push.sh [git push 的额外参数]
#   或通过 git 别名：git push-vpn
#
# 工作流程：
#   1. 直接尝试 git push（不做任何 VPN 干预）
#   2. 失败 → 强制启用 TUN 模式 → 启动 v2rayN
#   3. 等待 VPN 连通（TUN 全局代理）→ 重试 push
#   4. 仍失败 → 切换 VPN 线路（修改 indexId 强制切换服务器）
#   5. 重启 v2rayN + 等待连通 → 再次重试 push
#   6. 全部失败 → 还原原始配置并报告
#
# 依赖：
#   - v2rayN.exe 路径：D:\v2rayN-With-Core\v2rayN.exe
#   - v2rayN 配置文件：D:\v2rayN-With-Core\guiConfigs\guiNConfig.json
#   - TUN 模式：强制启用（enableTun: true），系统级全局代理
#   - 代理端口：HTTP/SOCKS 混合端口 7890（TUN 模式下作为备用）
# ============================================================================

set -euo pipefail

# ============================================================
# 配置常量
# ============================================================
VPN_EXE="D:\\v2rayN-With-Core\\v2rayN.exe"
VPN_CONFIG="D:\\v2rayN-With-Core\\guiConfigs\\guiNConfig.json"
VPN_CONFIG_BACKUP="D:\\v2rayN-With-Core\\guiConfigs\\guiNConfig.json.bak"
PROXY_HOST="127.0.0.1"
PROXY_PORT="7890"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"
MAX_RETRIES=3
WAIT_PROXY_TIMEOUT=30  # 等待代理就绪的最长秒数
TEST_URL="https://github.com"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 工具函数
# ============================================================

# 打印带颜色的消息
log_info()  { echo -e "${GREEN}[vpn-push]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[vpn-push]${NC} $*"; }
log_error() { echo -e "${RED}[vpn-push]${NC} $*"; }
log_step()  { echo -e "${CYAN}[vpn-push]${NC} ==> $*"; }

# 检测 v2rayN.exe 是否正在运行（Windows 进程检测）
is_vpn_running() {
    # 使用 tasklist 检测 Windows 进程
    local result
    result=$(cmd.exe /c "tasklist /FI \"IMAGENAME eq v2rayN.exe\" 2>NUL" 2>/dev/null || true)
    if echo "$result" | grep -qi "v2rayN.exe"; then
        return 0
    fi
    return 1
}

# 检测 VPN 连通性（TUN 模式下直接测试，也支持代理端口测试）
is_vpn_connected() {
    # TUN 模式下所有流量走 VPN，直接 curl 测试即可
    if curl -s --max-time 5 "$TEST_URL" > /dev/null 2>&1; then
        return 0
    fi
    # 如果直接连接失败，尝试通过代理端口
    if curl -s --max-time 5 -x "$PROXY_URL" "$TEST_URL" > /dev/null 2>&1; then
        return 0
    fi
    # 也尝试 SOCKS5 端口 (10808)
    if curl -s --max-time 5 --socks5 "127.0.0.1:10808" "$TEST_URL" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# 等待 VPN 连通（循环检测，有超时）
wait_for_vpn() {
    local timeout="$1"
    local elapsed=0
    log_info "等待 VPN 连通（TUN 模式，最长 ${timeout}s）..."

    while [[ $elapsed -lt $timeout ]]; do
        if is_vpn_connected; then
            log_info "✓ VPN 已连通 (${elapsed}s)"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        # 每 10 秒打印一次进度
        if [[ $((elapsed % 10)) -eq 0 ]]; then
            log_info "  仍在等待 VPN 连通... (${elapsed}s/${timeout}s)"
        fi
    done

    log_warn "⚠ 等待 VPN 连通超时 (${timeout}s)"
    return 1
}

# 设置 git 使用代理
set_git_proxy() {
    log_info "设置 Git HTTP/HTTPS 代理 → ${PROXY_URL}"
    git config --local http.proxy "$PROXY_URL"
    git config --local https.proxy "$PROXY_URL"
}

# 取消 git 代理设置
unset_git_proxy() {
    log_info "取消 Git 代理设置"
    git config --local --unset http.proxy 2>/dev/null || true
    git config --local --unset https.proxy 2>/dev/null || true
}

# 确保 TUN 模式已启用（TUN 模式 = 全局代理，所有流量走 VPN，Git 推送必须）
# 修改 guiNConfig.json 中的 enableTun 字段为 true
enable_tun_mode() {
    log_info "检查 TUN 模式状态..."

    if [[ ! -f "$VPN_CONFIG" ]]; then
        log_warn "⚠ 找不到配置文件，无法检查 TUN 模式"
        return 1
    fi

    # 备份配置文件（如果尚未备份）
    if [[ ! -f "$VPN_CONFIG_BACKUP" ]]; then
        cp "$VPN_CONFIG" "$VPN_CONFIG_BACKUP"
        log_info "已备份原始配置 → ${VPN_CONFIG_BACKUP}"
    fi

    # 检查当前 TUN 模式状态
    local tun_status
    tun_status=$(grep -oP '"enableTun"\s*:\s*\K(true|false)' "$VPN_CONFIG" 2>/dev/null || echo "not_found")

    if [[ "$tun_status" == "true" ]]; then
        log_info "✓ TUN 模式已启用"
        return 0
    fi

    # 如果 enableTun 为 false 或不存在，设置为 true
    if [[ "$tun_status" == "false" ]]; then
        log_step "启用 TUN 模式（全局代理）..."
        sed -i 's/"enableTun"[[:space:]]*:[[:space:]]*false/"enableTun": true/' "$VPN_CONFIG"
    elif [[ "$tun_status" == "not_found" ]]; then
        log_step "TUN 配置项不存在，添加 TUN 模式配置..."
        # 在 tunModeItem 块中添加 enableTun: true
        sed -i 's/"enableTun":[[:space:]]*false,*/"enableTun": true,/' "$VPN_CONFIG" 2>/dev/null || true
        # 如果上面没匹配到，尝试在 tunModeItem 内插入
        if ! grep -q '"enableTun"' "$VPN_CONFIG"; then
            # 在 "tunModeItem" 的下一行插入 enableTun
            sed -i '/"tunModeItem"[[:space:]]*:/,/}/{s/"strictRoute"[[:space:]]*:[[:space:]]*true/"enableTun": true,\n      "strictRoute": true/}' "$VPN_CONFIG"
        fi
    fi

    # 验证修改
    tun_status=$(grep -oP '"enableTun"\s*:\s*\K(true|false)' "$VPN_CONFIG" 2>/dev/null || echo "not_found")
    if [[ "$tun_status" == "true" ]]; then
        log_info "✓ TUN 模式已启用（需重启 v2rayN 生效）"
        return 0
    else
        log_warn "⚠ TUN 模式启用可能失败，当前值: ${tun_status}"
        return 1
    fi
}

# 启动 v2rayN
start_vpn() {
    # 启动前确保 TUN 模式已配置
    enable_tun_mode

    if is_vpn_running; then
        log_info "v2rayN 已在运行中"
        # 检查是否需要重启以应用 TUN 模式变更
        local tun_status
        tun_status=$(grep -oP '"enableTun"\s*:\s*\K(true|false)' "$VPN_CONFIG" 2>/dev/null || echo "not_found")
        if [[ "$tun_status" == "true" ]]; then
            log_info "TUN 模式配置已就绪"
        fi
        return 0
    fi

    log_step "启动 v2rayN VPN（TUN 模式）..."
    # 使用 cmd.exe 启动 Windows 可执行文件（非阻塞，最小化）
    cmd.exe /c "start \"\" /MIN \"${VPN_EXE}\"" 2>/dev/null || true

    # 给 v2rayN 一些启动时间（TUN 模式需要更多初始化时间）
    sleep 5

    if is_vpn_running; then
        log_info "✓ v2rayN 已启动（TUN 模式）"
        return 0
    else
        log_warn "⚠ v2rayN 启动状态不确定，继续尝试..."
        return 0  # 不阻塞，因为可能是后台启动延迟
    fi
}

# 停止 v2rayN（强制杀进程）
stop_vpn() {
    if ! is_vpn_running; then
        log_info "v2rayN 未在运行，无需停止"
        return 0
    fi

    log_step "停止 v2rayN VPN..."
    # 使用 taskkill 强制终止
    cmd.exe /c "taskkill /F /IM v2rayN.exe 2>NUL" 2>/dev/null || true
    sleep 2

    if is_vpn_running; then
        log_warn "⚠ v2rayN 未能完全停止，继续尝试..."
        return 0
    fi
    log_info "✓ v2rayN 已停止"
    return 0
}

# 切换 VPN 线路：修改 guiNConfig.json 中的 indexId，强制 v2rayN 使用不同服务器
switch_vpn_line() {
    log_step "切换 VPN 线路..."

    # 备份原始配置
    if [[ -f "$VPN_CONFIG" ]]; then
        cp "$VPN_CONFIG" "$VPN_CONFIG_BACKUP"
        log_info "已备份原始配置 → ${VPN_CONFIG_BACKUP}"
    else
        log_error "找不到配置文件: ${VPN_CONFIG}"
        return 1
    fi

    # 读取当前 indexId
    local current_id
    current_id=$(grep -oP '"indexId"\s*:\s*"\K[^"]*' "$VPN_CONFIG" 2>/dev/null || echo "")
    log_info "当前服务器 indexId: ${current_id:-（空）}"

    # 切换策略：将 indexId 设为空字符串
    # v2rayN 在 indexId 为空时会使用数据库中的第一个可用服务器
    # 如果当前已经为空，则尝试设置 subIndexId 作为 indexId（切换到订阅中的服务器）
    if [[ -z "$current_id" || "$current_id" == "null" ]]; then
        # 当前为空，尝试使用 subIndexId 作为新 indexId
        local sub_id
        sub_id=$(grep -oP '"subIndexId"\s*:\s*"\K[^"]*' "$VPN_CONFIG" 2>/dev/null || echo "")
        if [[ -n "$sub_id" && "$sub_id" != "null" ]]; then
            # 用 sed 替换 indexId 为 subIndexId
            sed -i "s/\"indexId\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"indexId\": \"${sub_id}\"/" "$VPN_CONFIG"
            log_info "✓ 切换 indexId → subIndexId: ${sub_id}"
        else
            log_warn "⚠ 无法获取备用服务器 ID，跳过切换"
            return 1
        fi
    else
        # 当前有值，清空 indexId 让 v2rayN 使用第一个可用服务器
        sed -i 's/"indexId"[[:space:]]*:[[:space:]]*"[^"]*"/"indexId": ""/' "$VPN_CONFIG"
        log_info "✓ 已清除 indexId，v2rayN 将使用第一个可用服务器"
    fi

    return 0
}

# 还原 VPN 配置
restore_vpn_config() {
    if [[ -f "$VPN_CONFIG_BACKUP" ]]; then
        log_info "还原原始 VPN 配置..."
        cp "$VPN_CONFIG_BACKUP" "$VPN_CONFIG"
        rm -f "$VPN_CONFIG_BACKUP"
        log_info "✓ 配置已还原"
    fi
}

# 尝试 git push（捕获输出和退出码）
try_git_push() {
    local attempt_desc="$1"
    log_info "尝试 git push... (${attempt_desc})"

    local output
    local exit_code=0

    # 执行 git push，传递所有额外参数
    if output=$(git push "$@" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # 打印 git 输出（去除敏感信息）
    echo "$output" | head -20

    return $exit_code
}

# 判断是否网络错误
is_network_error() {
    local output="$1"
    # 匹配常见网络错误关键词
    if echo "$output" | grep -qiE "Could not resolve host|Network is unreachable|Connection timed out|Couldn't connect to server|Failed to connect|SSL.*connect|unable to access|reset by peer|Operation timed out|fatal: unable to access|fatal: Could not read from remote"; then
        return 0
    fi
    return 1
}

# ============================================================
# 清理函数（脚本退出时执行）
# ============================================================
cleanup() {
    local exit_code=$?
    # 无论成功失败，恢复 git 代理设置（不保留代理配置污染本地环境）
    unset_git_proxy
    # 退出时不自动停止 VPN（用户可能还在用）
    # 配置备份不自动还原（让下次启动自然恢复）
    exit $exit_code
}

trap cleanup EXIT

# ============================================================
# 主流程
# ============================================================

log_info "============================================"
log_info "  VPN 自动推送脚本"
log_info "  VPN 路径: ${VPN_EXE}"
log_info "  代理地址: ${PROXY_URL}"
log_info "============================================"
echo ""

# --------------------------------------------------
# Phase 1：直接尝试推送（不启用 VPN）
# --------------------------------------------------
log_step "Phase 1：直接推送尝试（无 VPN）"
push_output=$(git push "$@" 2>&1) && push_ok=true || push_ok=false

if $push_ok; then
    echo "$push_output"
    log_info "✅ 推送成功！无需启动 VPN。"
    exit 0
fi

echo "$push_output"

if ! is_network_error "$push_output"; then
    # 非网络错误（如 merge conflict、rejected 等），VPN 帮不上忙
    log_error "❌ 推送失败（非网络错误），VPN 无法解决此问题"
    log_error "   请检查错误信息并手动处理"
    exit 1
fi

log_warn "⚠ 检测到网络错误，启动 VPN 方案..."

# --------------------------------------------------
# Phase 2：启动 VPN 并重试
# --------------------------------------------------
log_step "Phase 2：启动 VPN + 设置代理 + 重试推送"

# 启动 v2rayN（如果已运行则跳过）
start_vpn

# 等待代理就绪
if wait_for_vpn "$WAIT_PROXY_TIMEOUT"; then
    # TUN 模式下系统流量自动走 VPN，也可设置 git 代理作为双重保障
    set_git_proxy

    # 重试推送
    if try_git_push "Phase 2: VPN TUN 模式 ${PROXY_URL}" "$@"; then
        log_info "✅ VPN 推送成功！"
        exit 0
    fi
    log_warn "⚠ VPN 推送失败，准备切换线路..."
else
    log_warn "⚠ VPN 未连通，尝试切换线路..."
fi

# --------------------------------------------------
# Phase 3：切换 VPN 线路并重试
# --------------------------------------------------
log_step "Phase 3：切换 VPN 线路 + 重启 + 重试推送"

# 停止 v2rayN
stop_vpn

# 切换线路
if switch_vpn_line; then
    log_info "✓ 线路已切换"
else
    log_error "⚠ 线路切换失败，将使用当前线路重试"
fi

# 重新启动 v2rayN
start_vpn

# 等待代理重新就绪
if wait_for_vpn "$WAIT_PROXY_TIMEOUT"; then
    # 确保代理设置仍在（TUN 模式作为双重保障）
    set_git_proxy

    # 再次重试推送
    if try_git_push "Phase 3: 切换线路后 TUN 模式" "$@"; then
        log_info "✅ 切换线路后推送成功！"
        exit 0
    fi
    log_error "❌ 切换线路后推送仍然失败"
else
    log_error "❌ 切换线路后 VPN 仍未连通"
fi

# --------------------------------------------------
# Phase 4：彻底失败，还原配置
# --------------------------------------------------
log_step "Phase 4：还原配置"

# 如果切换了线路，还原原始配置
if [[ -f "$VPN_CONFIG_BACKUP" ]]; then
    stop_vpn
    restore_vpn_config
    log_info "已还原原始 VPN 配置，重新启动 v2rayN..."
    start_vpn
    wait_for_vpn 15 || true
fi

log_error "============================================"
log_error "  ❌ 所有推送尝试均失败"
log_error "  可能的原因："
log_error "  1. VPN 服务不可用（检查 v2rayN 订阅是否过期）"
log_error "  2. GitHub 服务异常（访问 https://www.githubstatus.com 确认）"
log_error "  3. 认证凭据过期（检查 Token 是否有效）"
log_error ""
log_error "  手动排查命令："
log_error "    curl -x ${PROXY_URL} https://github.com"
log_error "    git push --no-verify $*"
log_error "============================================"

exit 1
