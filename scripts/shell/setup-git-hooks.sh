#!/bin/bash
# Git Hooks 安装/卸载脚本
# 用法:
#   bash scripts/shell/setup-git-hooks.sh          安装 pre-push hook
#   bash scripts/shell/setup-git-hooks.sh --remove  卸载 pre-push hook

set -euo pipefail

HOOK_NAME="pre-push"
SOURCE="scripts/shell/git-pre-push-hook.sh"
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || {
    echo "错误：当前目录不是 git 仓库。请在仓库根目录运行此脚本。"
    exit 1
}
HOOK_PATH="${GIT_DIR}/hooks/${HOOK_NAME}"

ACTION="${1:-install}"

# ============================================================
# 安装模式
# ============================================================
if [[ "$ACTION" == "install" ]] || [[ -z "$ACTION" ]]; then
    echo "=== Git Hook 安装: ${HOOK_NAME} ==="

    # 检查源文件
    if [[ ! -f "$SOURCE" ]]; then
        echo "错误：找不到 hook 源文件 '$SOURCE'。"
        echo "请确保在仓库根目录运行此脚本。"
        exit 1
    fi

    # 检查是否已安装且内容一致
    if [[ -f "$HOOK_PATH" ]]; then
        if cmp -s "$SOURCE" "$HOOK_PATH"; then
            echo "✓ ${HOOK_NAME} hook 已安装且是最新版本，无需操作。"
            exit 0
        else
            # 备份现有 hook
            BACKUP_NAME="${HOOK_PATH}.bak.$(date +%Y%m%d%H%M%S)"
            echo "⚠ 检测到不同的已有 hook，备份到: ${BACKUP_NAME}"
            cp "$HOOK_PATH" "$BACKUP_NAME"
        fi
    fi

    # 复制源文件
    cp "$SOURCE" "$HOOK_PATH"
    chmod +x "$HOOK_PATH" 2>/dev/null || true
    echo "✓ ${HOOK_NAME} hook 安装成功: ${HOOK_PATH}"
    echo ""
    echo "现在每次 git push 将会："
    echo "  1. 只允许推送到 main 分支"
    echo "  2. 推送前自动创建 backup/main-YYYYMMDD-HHmmss 备份"
    echo "  3. 自动清理超过 180 天的过期备份"
    echo ""
    echo "跳过 hook: git push --no-verify"

# ============================================================
# 卸载模式
# ============================================================
elif [[ "$ACTION" == "--remove" ]]; then
    echo "=== Git Hook 卸载: ${HOOK_NAME} ==="

    if [[ ! -f "$HOOK_PATH" ]]; then
        echo "✓ ${HOOK_NAME} hook 未安装，无需操作。"
        exit 0
    fi

    # 检查是否是我们的 hook（通过特征标识）
    if grep -q "BACKUP_PREFIX=\"backup/main-\"" "$HOOK_PATH" 2>/dev/null; then
        rm "$HOOK_PATH"
        echo "✓ ${HOOK_NAME} hook 已卸载。"
    else
        echo "⚠ ${HOOK_PATH} 不像是本工具安装的 hook，跳过删除。"
        echo "  如需手动删除，请执行: rm ${HOOK_PATH}"
        exit 1
    fi

    # 检查是否有备份可恢复
    shopt -s nullglob
    backups=("${GIT_DIR}/hooks/${HOOK_NAME}.bak."*)
    if [[ ${#backups[@]} -gt 0 ]]; then
        latest="${backups[${#backups[@]}-1]}"
        echo "⚠ 检测到之前的 hook 备份: ${latest}"
        echo "  恢复命令: cp '${latest}' '${HOOK_PATH}' && chmod +x '${HOOK_PATH}'"
    fi
    shopt -u nullglob

else
    echo "用法: bash scripts/shell/setup-git-hooks.sh [--remove]"
    echo "  无参数    安装 pre-push hook"
    echo "  --remove  卸载 pre-push hook"
    exit 1
fi
