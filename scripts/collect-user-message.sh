#!/bin/bash
# UserPromptSubmit hook: 收集用户消息到个人画像目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

VAULT_PATH=$(get_vault_path)
KB_ROOT=$(get_kb_root)
TODAY=$(date +%Y%m%d)
PROJECT=$(basename "$PWD")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# 读取 UserPromptSubmit hook 发送的 JSON（stdin），提取 prompt 文本
RAW_INPUT=$(cat)

if [ -z "$RAW_INPUT" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"回答结束前必须执行 KB 自检：1) 本次是否修改了代码？是→判断是否命中跳过规则（仅纯格式/位置/UI文案可跳过，bug fix 不可跳过）；2) 需要写入→立即写入 KB 文件并验证；3) 最后输出 KB 运行日志（📋 KB | <操作> | <详情>），日期用 date +%Y%m%d 获取。日志为回复最后一行。禁止跳过步骤 1 直接输出日志。"}}'
    exit 0
fi

# 解析 JSON，提取 prompt 和 cwd 字段
PROMPT=$(echo "$RAW_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('prompt',''))" 2>/dev/null)
if [ -z "$PROMPT" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"回答结束前必须执行 KB 自检：1) 本次是否修改了代码？是→判断是否命中跳过规则（仅纯格式/位置/UI文案可跳过，bug fix 不可跳过）；2) 需要写入→立即写入 KB 文件并验证；3) 最后输出 KB 运行日志（📋 KB | <操作> | <详情>），日期用 date +%Y%m%d 获取。日志为回复最后一行。禁止跳过步骤 1 直接输出日志。"}}'
    exit 0
fi

# 使用 JSON 中的 cwd 覆盖 shell PWD（更准确反映用户当前项目）
HOOK_CWD=$(echo "$RAW_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
if [ -n "$HOOK_CWD" ]; then
    PROJECT=$(basename "$HOOK_CWD")
fi

# Vault 未配置时静默跳过收集，但仍输出 KB 日志提醒
if [ -z "$VAULT_PATH" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"回答结束前必须执行 KB 自检：1) 本次是否修改了代码？是→判断是否命中跳过规则（仅纯格式/位置/UI文案可跳过，bug fix 不可跳过）；2) 需要写入→立即写入 KB 文件并验证；3) 最后输出 KB 运行日志（📋 KB | <操作> | <详情>），日期用 date +%Y%m%d 获取。日志为回复最后一行。禁止跳过步骤 1 直接输出日志。"}}'
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

printf '## %s\n\n' "$TIMESTAMP" >> "$LOG_FILE"
printf '%s\n\n' "$PROMPT" >> "$LOG_FILE"

# 输出 KB 日志提醒（三段式强制流程）
echo '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"回答结束前必须执行 KB 自检：1) 本次是否修改了代码？是→判断是否命中跳过规则（仅纯格式/位置/UI文案可跳过，bug fix 不可跳过）；2) 需要写入→立即写入 KB 文件并验证；3) 最后输出 KB 运行日志（📋 KB | <操作> | <详情>），日期用 date +%Y%m%d 获取。日志为回复最后一行。禁止跳过步骤 1 直接输出日志。"}}'
