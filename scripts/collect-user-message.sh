#!/bin/bash
# UserPromptSubmit hook: 收集用户消息到个人画像目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

VAULT_PATH=$(get_vault_path)
KB_ROOT=$(get_kb_root)
TODAY=$(date +%Y%m%d)
PROJECT=$(basename "$PWD")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# 读取用户消息（stdin）
PROMPT=$(cat)

if [ -z "$PROMPT" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"本轮回答末尾输出 KB 运行日志（📋 KB | <操作> | <详情>），日期使用 date +%Y%m%d 获取。日志为回复最后一行。"}}'
    exit 0
fi

# Vault 未配置时静默跳过收集，但仍输出 KB 日志提醒
if [ -z "$VAULT_PATH" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"本轮回答末尾输出 KB 运行日志（📋 KB | <操作> | <详情>），日期使用 date +%Y%m%d 获取。日志为回复最后一行。"}}'
    exit 0
fi

# 保存用户消息到个人画像目录
PROFILE_DIR="$VAULT_PATH/$KB_ROOT/个人画像/$PROJECT/$BRANCH/$TODAY"
mkdir -p "$PROFILE_DIR"
LOG_FILE="$PROFILE_DIR/$TODAY.md"

TIMESTAMP=$(date +%H:%M:%S)

# 首条消息写入文件头
if [ ! -f "$LOG_FILE" ]; then
    echo "# $TODAY 用户消息记录" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

echo "## $TIMESTAMP" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "$PROMPT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 输出 KB 日志提醒
echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"本轮回答末尾输出 KB 运行日志（📋 KB | <操作> | <详情>），日期使用 date +%Y%m%d 获取。日志为回复最后一行。"}}'
