#!/bin/bash
# SessionStart hook: 将 KB 文件内容注入为 additionalContext（系统级文件上下文）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_config.sh"

VAULT_PATH=$(get_vault_path)
KB_ROOT=$(get_kb_root)
TODAY=$(date +%Y%m%d)
PROJECT=$(basename "$PWD")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# 基础指令（保留原有 skill 加载提示）
INSTRUCTION="请使用 Skill 工具加载 knowledge-base。按 skill 规定执行前置检查：定位知识库路径、加载上下文、确认 MEMORY.md、扫描组件级规则、提取待办项，先完成后响应。"

KB_CONTEXT=""

if [ -n "$VAULT_PATH" ]; then
    # 1. 今日项目级 KB 文件
    KB_FILE="$VAULT_PATH/$KB_ROOT/$PROJECT/$BRANCH/$TODAY/$TODAY.md"
    if [ -f "$KB_FILE" ]; then
        KB_CONTEXT+="## 今日知识库 ($TODAY)
$(cat "$KB_FILE")

"
    fi

    # 2. 最近 3 天项目级 KB 摘要
    for i in 1 2 3; do
        if [ "$(uname)" = "Darwin" ]; then
            PREV_DATE=$(date -v-${i}d +%Y%m%d)
        else
            PREV_DATE=$(date -d "-${i} days" +%Y%m%d)
        fi
        PREV_FILE="$VAULT_PATH/$KB_ROOT/$PROJECT/$BRANCH/$PREV_DATE/$PREV_DATE.md"
        if [ -f "$PREV_FILE" ]; then
            KB_CONTEXT+="## 历史条目 ($PREV_DATE)
$(head -20 "$PREV_FILE")

"
        fi
    done
fi

# 3. 用户个人画像（含过期检查）
PROFILE_CONTEXT=""
if [ -n "$VAULT_PATH" ]; then
    PROFILE_FILE="$VAULT_PATH/$KB_ROOT/个人画像/个人画像.md"
    if [ -f "$PROFILE_FILE" ]; then
        # 计算文件年龄（天）
        if [ "$(uname)" = "Darwin" ]; then
            FILE_MTIME=$(stat -f %m "$PROFILE_FILE" 2>/dev/null)
        else
            FILE_MTIME=$(stat -c %Y "$PROFILE_FILE" 2>/dev/null)
        fi
        NOW=$(date +%s)
        FILE_AGE_DAYS=$(( (NOW - FILE_MTIME) / 86400 ))

        if [ "$FILE_AGE_DAYS" -gt 2 ]; then
            PROFILE_CONTEXT="### ⚠️ 个人画像已过期（${FILE_AGE_DAYS} 天未更新）

**本次会话应刷新画像**。请读取 \`个人画像/\` 下各项目的新消息记录（关注最近 ${FILE_AGE_DAYS} 天的增量），对照现有画像更新。

---
$(cat "$PROFILE_FILE")
"
        else
            PROFILE_CONTEXT="### 用户个人画像（${FILE_AGE_DAYS} 天前更新）
$(cat "$PROFILE_FILE")
"
        fi
    else
        PROFILE_CONTEXT="### 📋 个人画像未生成

本次会话中请读取 \`个人画像/\` 下各项目的用户消息记录，分析用户习惯、偏好与性格，按 SKILL.md 的画像模板生成 \`个人画像/个人画像.md\`。
"
    fi
fi

# 合并输出
FULL_CONTEXT="$INSTRUCTION"
if [ -n "$KB_CONTEXT" ] || [ -n "$PROFILE_CONTEXT" ]; then
    FULL_CONTEXT="$FULL_CONTEXT

---
📚 **系统注入上下文（已自动加载，无需手动 Read）**：

$PROFILE_CONTEXT
$KB_CONTEXT"
fi

# 通过 Python 安全 JSON 转义
ESCAPED=$(echo "$FULL_CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":$ESCAPED}}"
