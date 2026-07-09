#!/bin/bash
# Git pre-push hook：推送前自动备份 main 分支，强制只推 main，清理过期备份
# 用法：由 git 在 git push 时自动调用，不要手动运行
# 安装：bash scripts/shell/setup-git-hooks.sh

# ============================================================
# Phase 0：防递归
# ============================================================
if [[ "${SKIP_BACKUP_HOOK:-}" == "1" ]]; then
    exit 0
fi

REMOTE="$1"
REMOTE_URL="$2"
BACKUP_PREFIX="backup/main-"
RETENTION_DAYS=180
ZERO_OID="0000000000000000000000000000000000000000"

# ANSI 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================
# Phase 1：读取 stdin 并强制分支策略
# ============================================================

# 先收集所有 stdin 行，避免提前 exit 导致管道破裂
ref_lines=()
while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
    # 跳过空行（空 stdin）
    [[ -z "$remote_ref" ]] && continue
    ref_lines+=("$local_ref $local_sha $remote_ref $remote_sha")
done

pushing_main=false
pushing_other=false
push_target_ref=""
is_deleting_main=false
main_local_sha=""
main_remote_sha=""

for line in "${ref_lines[@]}"; do
    read -r local_ref local_sha remote_ref remote_sha <<< "$line"

    # 推送到 backup/ 分支的递归调用直接放行
    if [[ "$local_ref" == refs/heads/backup/* ]]; then
        exit 0
    fi

    # 检测是否在删除分支（local_sha 为全零表示删除）
    if [[ "$local_sha" == "$ZERO_OID" ]]; then
        if [[ "$remote_ref" == "refs/heads/main" ]]; then
            is_deleting_main=true
            push_target_ref="$remote_ref"
        fi
        # 删除非 main 分支：直接跳过（允许），不记录为 pushing_other
        continue
    fi

    # 记录推送目标
    if [[ "$remote_ref" != "refs/heads/main" ]]; then
        pushing_other=true
        push_target_ref="$remote_ref"
    else
        pushing_main=true
        main_local_sha="$local_sha"
        main_remote_sha="$remote_sha"
    fi
done

# 阻止删除 main 分支
if $is_deleting_main; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}[pre-push] 错误：不允许删除远程 'main' 分支。${NC}"
    echo -e "${RED}[pre-push] 如确需此操作，请使用: git push --no-verify${NC}"
    echo -e "${RED}============================================${NC}"
    exit 1
fi

# 阻止推送到非 main 分支
if $pushing_other; then
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}[pre-push] 错误：不允许推送到 'main' 以外的分支。${NC}"
    echo -e "${RED}[pre-push] 当前目标: $push_target_ref${NC}"
    echo -e "${RED}[pre-push] 本仓库只接受推送到 main 分支。操作步骤:${NC}"
    echo -e "${RED}[pre-push]   1. 切换到 main: git checkout main${NC}"
    echo -e "${RED}[pre-push]   2. 合并你的改动: git merge <你的分支>${NC}"
    echo -e "${RED}[pre-push]   3. 推送到 main: git push origin main${NC}"
    echo -e "${RED}[pre-push] 或跳过检查: git push --no-verify${NC}"
    echo -e "${RED}============================================${NC}"
    exit 1
fi

# 没有推送到 main 的情况（如删除其他分支），直接放行
if ! $pushing_main; then
    exit 0
fi

# ============================================================
# Phase 2：为当前远程 main 创建备份
# ============================================================

echo -e "${GREEN}[pre-push] 开始推送前检查...${NC}"

if [[ "$main_remote_sha" == "$ZERO_OID" ]]; then
    echo -e "${YELLOW}[pre-push] 检测到首次推送到 main — 无需备份。${NC}"
else
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_BRANCH="${BACKUP_PREFIX}${TIMESTAMP}"

    # 处理同秒冲突（极少见但可能发生）
    if git rev-parse --verify "refs/heads/$BACKUP_BRANCH" >/dev/null 2>&1; then
        BACKUP_BRANCH="${BACKUP_PREFIX}${TIMESTAMP}-2"
    fi

    echo -e "${GREEN}[pre-push] 正在创建备份: $BACKUP_BRANCH${NC}"

    # 拉取确保本地有远程 main 的对象
    git fetch "$REMOTE" refs/heads/main:refs/remotes/$REMOTE/main 2>/dev/null || true

    # 尝试用远程 SHA 创建备份分支
    if ! git branch "$BACKUP_BRANCH" "$main_remote_sha" 2>/dev/null; then
        # fallback: 尝试用 refs/remotes/origin/main
        if ! git branch "$BACKUP_BRANCH" "refs/remotes/$REMOTE/main" 2>/dev/null; then
            echo -e "${RED}[pre-push] 错误：无法创建本地备份分支。远程 main 对象可能不可用。${NC}"
            echo -e "${RED}[pre-push] 推送已中止 — 无法在没有备份的情况下推送。${NC}"
            exit 1
        fi
    fi

    # 推送备份到远程
    echo -e "${GREEN}[pre-push] 正在推送备份到远程...${NC}"
    if SKIP_BACKUP_HOOK=1 git push "$REMOTE" "refs/heads/$BACKUP_BRANCH" 2>/dev/null; then
        echo -e "${GREEN}[pre-push] ✓ 备份已推送: $BACKUP_BRANCH${NC}"
        # 删除本地备份（远程已有）
        git branch -D "$BACKUP_BRANCH" 2>/dev/null || true
    else
        echo -e "${RED}[pre-push] 错误：推送备份分支到远程失败。${NC}"
        echo -e "${RED}[pre-push] 推送已中止 — 无法在没有备份的情况下推送 main。${NC}"
        echo -e "${RED}[pre-push] 请检查网络连接后重试。${NC}"
        git branch -D "$BACKUP_BRANCH" 2>/dev/null || true
        exit 1
    fi
fi

# ============================================================
# Phase 3：清理过期备份（超过 180 天）
# ============================================================

echo -e "${GREEN}[pre-push] 检查过期备份分支（保留 ${RETENTION_DAYS} 天）...${NC}"

# 计算截止日期
CUTOFF_DATE=""
if cutoff_date=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d 2>/dev/null); then
    CUTOFF_DATE="$cutoff_date"
elif command -v perl >/dev/null 2>&1; then
    CUTOFF_DATE=$(perl -MPOSIX -e "print POSIX::strftime('%Y%m%d', localtime(time() - ${RETENTION_DAYS}*86400))" 2>/dev/null)
fi

if [[ -z "$CUTOFF_DATE" ]]; then
    echo -e "${YELLOW}[pre-push] 警告：无法计算截止日期，跳过清理。${NC}"
else
    local_deleted=0
    remote_deleted=0

    # --- 本地清理 ---
    branches=$(git branch --list "${BACKUP_PREFIX}*" 2>/dev/null || true)
    if [[ -n "$branches" ]]; then
        while IFS= read -r branch_line; do
            # 去掉前导空格和 *
            branch_name=$(echo "$branch_line" | sed 's/^[* ]*//')
            if [[ "$branch_name" == ${BACKUP_PREFIX}* ]]; then
                date_part="${branch_name#${BACKUP_PREFIX}}"
                branch_date="${date_part:0:8}"
                if [[ "$branch_date" =~ ^[0-9]{8}$ && "$branch_date" < "$CUTOFF_DATE" ]]; then
                    echo -e "${YELLOW}[pre-push] 删除过期本地备份: $branch_name${NC}"
                    git branch -D "$branch_name" 2>/dev/null && local_deleted=$((local_deleted + 1)) || true
                fi
            fi
        done <<< "$branches"
    fi

    # --- 远程清理 ---
    remote_refs=$(git ls-remote --heads "$REMOTE" "${BACKUP_PREFIX}*" 2>/dev/null || true)
    if [[ -n "$remote_refs" ]]; then
        while IFS= read -r ref_line; do
            [[ -z "$ref_line" ]] && continue
            sha=$(echo "$ref_line" | awk '{print $1}')
            ref=$(echo "$ref_line" | awk '{print $2}')
            branch_name="${ref#refs/heads/}"
            if [[ "$branch_name" == ${BACKUP_PREFIX}* ]]; then
                date_part="${branch_name#${BACKUP_PREFIX}}"
                branch_date="${date_part:0:8}"
                if [[ "$branch_date" =~ ^[0-9]{8}$ && "$branch_date" < "$CUTOFF_DATE" ]]; then
                    echo -e "${YELLOW}[pre-push] 删除过期远程备份: $branch_name${NC}"
                    if git push "$REMOTE" --delete "$branch_name" 2>/dev/null; then
                        remote_deleted=$((remote_deleted + 1))
                    else
                        echo -e "${YELLOW}[pre-push] 警告：删除远程分支 '$branch_name' 失败，已跳过。${NC}"
                    fi
                fi
            fi
        done <<< "$remote_refs"
    fi

    total_deleted=$((local_deleted + remote_deleted))
    if [[ $total_deleted -gt 0 ]]; then
        echo -e "${GREEN}[pre-push] ✓ 清理完成：删除 $local_deleted 个本地、$remote_deleted 个远程过期备份。${NC}"
    else
        echo -e "${GREEN}[pre-push] 没有过期备份需要清理。${NC}"
    fi
fi

# ============================================================
# Phase 4：放行
# ============================================================
echo -e "${GREEN}[pre-push] ✓ 推送前检查完毕，正在推送到 main...${NC}"
exit 0
