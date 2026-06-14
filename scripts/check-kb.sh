#!/bin/bash
# Stop hook: 验证今日 KB 文件状态

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

VAULT_PATH=$(get_vault_path)
KB_ROOT=$(get_kb_root)

# Vault 未配置，静默跳过
if [ -z "$VAULT_PATH" ]; then
    exit 0
fi

TODAY=$(date +%Y%m%d)
PROJECT=$(basename "$PWD")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
KB_FILE="$VAULT_PATH/$KB_ROOT/$PROJECT/$BRANCH/$TODAY/$TODAY.md"

if [ ! -f "$KB_FILE" ]; then
    echo "{\"systemMessage\":\"⚠️ KB 兜底检查：今日知识库文件未创建($TODAY.md)，可能遗漏写入\"}"
elif ! grep -q "### #[0-9]" "$KB_FILE" 2>/dev/null; then
    echo "{\"systemMessage\":\"⚠️ KB 兜底检查：今日知识库文件存在但无变更条目($TODAY.md)\"}"
fi
# 文件存在且有条目 → 静默通过
