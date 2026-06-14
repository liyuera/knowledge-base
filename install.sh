#!/bin/bash
set -e

SKILL_SRC="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/knowledge-base"
CONFIG_FILE="$HOME/.claude/knowledge-base.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "=== knowledge-base skill v2.0.0 安装 ==="
echo ""

# ---- 1. 检测先决条件 ----
command -v python3 >/dev/null 2>&1 || { echo "❌ 需要 python3"; exit 1; }
echo "✅ python3 可用"

# ---- 2. 获取 vault 路径 ----
VAULT_PATH=""
if [ -n "$OBSIDIAN_VAULT_PATH" ]; then
    VAULT_PATH="$OBSIDIAN_VAULT_PATH"
    echo "✅ 从环境变量读取 vault 路径: $VAULT_PATH"
elif [ -f "$CONFIG_FILE" ]; then
    VAULT_PATH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('vaultPath',''))" 2>/dev/null || echo "")
    if [ -n "$VAULT_PATH" ]; then
        echo "✅ 从已有配置读取 vault 路径: $VAULT_PATH"
    fi
fi

if [ -z "$VAULT_PATH" ]; then
    echo ""
    echo "未检测到 Obsidian Vault 路径。你可以选择："
    echo "  1. 输入 vault 路径以启用 Obsidian 集成"
    echo "  2. 直接回车跳过，知识库将存储在项目 .claude/knowledge-base/ 目录"
    echo ""
    printf "请输入 Obsidian Vault 路径 (可选): "
    read -r VAULT_PATH
fi

# ---- 3. 写入配置 ----
if [ -n "$VAULT_PATH" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << JSONEOF
{
  "version": "2.0.0",
  "vaultPath": "$VAULT_PATH",
  "kbRoot": "${OBSIDIAN_KB_ROOT:-50-工作日志}",
  "language": "zh"
}
JSONEOF
    echo "✅ 配置文件已创建: $CONFIG_FILE"
else
    echo "⏭️  跳过 vault 配置，将使用项目本地存储模式"
    # 确保旧配置文件不残留
    rm -f "$CONFIG_FILE"
fi

# ---- 4. 部署 skill 文件到 ~/.claude/skills/ ----
if [ "$SKILL_SRC" != "$SKILL_DIR" ]; then
    rm -rf "$SKILL_DIR"
    mkdir -p "$SKILL_DIR"
    cp "$SKILL_SRC/SKILL.md" "$SKILL_DIR/"
    cp -r "$SKILL_SRC/scripts" "$SKILL_DIR/"
    cp -r "$SKILL_SRC/templates" "$SKILL_DIR/"
    cp "$SKILL_SRC/LICENSE" "$SKILL_DIR/" 2>/dev/null || true
    echo "✅ Skill 文件已部署到: $SKILL_DIR"
else
    echo "✅ Skill 已在目标位置"
fi

# 确保脚本可执行
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$SKILL_DIR/install.sh" 2>/dev/null || true
chmod +x "$SKILL_DIR/uninstall.sh" 2>/dev/null || true

# ---- 5. 备份并配置 settings.json hooks ----
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{"hooks":{}}' > "$SETTINGS_FILE"
    echo "✅ 创建 settings.json"
fi

# 使用 python3 安全操作 JSON
python3 << 'PYEOF'
import json, os, re

settings_path = os.path.expanduser("~/.claude/settings.json")

with open(settings_path, 'r') as f:
    settings = json.load(f)

if 'hooks' not in settings:
    settings['hooks'] = {}

# ---- 处理组合 hook（同时包含 KB 和其他 skill 引用） ----
# 例如: "请使用 Skill 工具加载 andrej-karpathy-skills:karpathy-guidelines 和 knowledge-base"
# 保留组合 hook（因为包含其他 skill 引用，不应删除），后续会单独添加新 KB hook
OTHER_SKILLS = ['andrej-karpathy', 'karpathy-guidelines', 'planning-with-files',
                'frontend-design', 'brainstorming', 'figma', 'find-skills']

# 识别 KB 相关 hook 的关键词（含中文变体）
KB_KEYWORDS = ['knowledge-base', '知识库', '📋 KB']

def contains_kb_ref(s):
    """检查字符串是否包含 KB 相关引用"""
    return any(kw in s for kw in KB_KEYWORDS)

def contains_other_skill(s):
    """检查字符串是否包含其他 skill 引用"""
    return any(skill in s for skill in OTHER_SKILLS)

def preserve_combined_hooks():
    """SessionStart 中保留同时引用 KB 和其他 skill 的组合 hook"""
    event = 'SessionStart'
    if event not in settings['hooks']:
        return
    new_hooks = []
    for hook in settings['hooks'][event]:
        s = json.dumps(hook)
        if contains_kb_ref(s) and contains_other_skill(s):
            print("⚠️  检测到组合 SessionStart hook (KB + 其他skill)，保留原 hook。请手动清理其中冗余的 KB 引用")
            new_hooks.append(hook)
        else:
            new_hooks.append(hook)
    settings['hooks'][event] = new_hooks

preserve_combined_hooks()

# 移除纯 KB hooks（不含其他 skill 引用的）
def is_kb_only_hook(hook):
    s = json.dumps(hook)
    if not contains_kb_ref(s):
        return False
    return not contains_other_skill(s)

for event in ['SessionStart', 'UserPromptSubmit', 'Stop']:
    if event in settings['hooks']:
        old_count = len(settings['hooks'][event])
        settings['hooks'][event] = [h for h in settings['hooks'][event] if not is_kb_only_hook(h)]
        if not settings['hooks'][event]:
            del settings['hooks'][event]
        elif len(settings['hooks'][event]) < old_count:
            print(f"✅ 已清理 {event} 中的旧 KB hooks")

# 新 hooks 定义
session_start_hook = {
    "hooks": [{
        "type": "command",
        "command": "echo '{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"请使用 Skill 工具加载 knowledge-base。按 skill 规定执行前置检查：定位知识库路径、加载上下文、确认 MEMORY.md、扫描组件级规则、提取待办项，先完成后响应。\"}}'"
    }]
}

user_prompt_hook = {
    "hooks": [{
        "type": "command",
        "command": "echo '{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"本轮回答末尾输出 KB 运行日志（📋 KB | <操作> | <详情>），日期使用 date +%Y%m%d 获取。日志为回复最后一行。\"}}'"
    }]
}

stop_hook = {
    "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/skills/knowledge-base/scripts/check-kb.sh"
    }]
}

# 检查是否已存在相同的 hook（避免重复添加）
def hook_exists(event, target_hook):
    if event not in settings['hooks']:
        return False
    target_cmd = target_hook['hooks'][0]['command']
    for h in settings['hooks'][event]:
        if isinstance(h, dict) and 'hooks' in h:
            for inner in h['hooks']:
                if inner.get('command') == target_cmd:
                    return True
    return False

if not hook_exists('SessionStart', session_start_hook):
    settings['hooks']['SessionStart'] = settings['hooks'].get('SessionStart', []) + [session_start_hook]
    print("✅ 已添加 SessionStart hook")

if not hook_exists('UserPromptSubmit', user_prompt_hook):
    settings['hooks']['UserPromptSubmit'] = settings['hooks'].get('UserPromptSubmit', []) + [user_prompt_hook]
    print("✅ 已添加 UserPromptSubmit hook")

if not hook_exists('Stop', stop_hook):
    settings['hooks']['Stop'] = settings['hooks'].get('Stop', []) + [stop_hook]
    print("✅ 已添加 Stop hook")

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("✅ settings.json hooks 配置完成")
PYEOF

# ---- 6. 全局 CLAUDE.md 提示 ----
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q "knowledge-base" "$CLAUDE_MD" 2>/dev/null; then
    echo ""
    echo "⚠️  检测到 ~/.claude/CLAUDE.md 中有旧 KB 规则段落"
    echo "   新版本不再需要这些规则（已合并到 skill 自身），建议手动删除以下段落："
    echo "   - '## 会话启动流程（阻断级，最高优先级）'"
    echo "   - '## knowledge-base skill 运行日志（阻断级，禁止跳过）'"
    echo "   备份已保存: $CLAUDE_MD.kb-backup-$TIMESTAMP"
    cp "$CLAUDE_MD" "$CLAUDE_MD.kb-backup-$TIMESTAMP"
fi

# ---- 7. 项目级 CLAUDE.md 提示 ----
if [ -f "CLAUDE.md" ] && grep -q "knowledge-base" "CLAUDE.md" 2>/dev/null; then
    echo ""
    echo "⚠️  检测到项目级 CLAUDE.md 中有旧 KB 规则段落"
    echo "   建议手动删除 '会话启动流程' 段落（内容已由 skill 接管）"
fi

# ---- 8. 完成 ----
echo ""
echo "=== 安装完成 ==="
echo ""
echo "安装摘要:"
echo "  Skill:      $SKILL_DIR"
echo "  配置:       $CONFIG_FILE"
if [ -n "$VAULT_PATH" ]; then
    echo "  Vault:      $VAULT_PATH"
else
    echo "  存储模式:   项目本地 (.claude/knowledge-base/)"
fi
echo ""
echo "请重启 Claude Code 或 /clear 使配置生效。"
echo "运行 bash $SKILL_DIR/scripts/migrate.sh 可检测旧配置残留。"
