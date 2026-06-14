#!/bin/bash
set -e

SKILL_DIR="$HOME/.claude/skills/knowledge-base"
CONFIG_FILE="$HOME/.claude/knowledge-base.json"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== knowledge-base skill 卸载 ==="
echo ""

# ---- 1. 清理 settings.json hooks ----
if [ -f "$SETTINGS_FILE" ]; then
    python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
with open(settings_path, 'r') as f:
    settings = json.load(f)

if 'hooks' not in settings:
    print("⏭️  settings.json 中无 hooks 配置")
    exit(0)

def is_kb_hook(hook):
    s = json.dumps(hook)
    return 'knowledge-base' in s

removed = False
for event in ['SessionStart', 'UserPromptSubmit', 'Stop']:
    if event in settings['hooks']:
        old_count = len(settings['hooks'][event])
        settings['hooks'][event] = [h for h in settings['hooks'][event] if not is_kb_hook(h)]
        if not settings['hooks'][event]:
            del settings['hooks'][event]
            print(f"✅ 已移除 {event} hook")
            removed = True
        elif len(settings['hooks'][event]) < old_count:
            print(f"✅ 已移除 {event} 中的 KB hook")
            removed = True

if not removed:
    print("⏭️  未发现 KB hooks")

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
PYEOF
    echo "✅ settings.json 已更新"
fi

# ---- 2. 询问是否保留配置 ----
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    printf "是否保留配置文件 ($CONFIG_FILE)? [Y/n]: "
    read -r KEEP_CONFIG
    if [ "$KEEP_CONFIG" = "n" ] || [ "$KEEP_CONFIG" = "N" ]; then
        rm -f "$CONFIG_FILE"
        echo "✅ 配置文件已删除"
    else
        echo "✅ 配置文件已保留"
    fi
fi

# ---- 3. 询问是否删除 skill 文件 ----
echo ""
printf "是否删除 skill 文件 ($SKILL_DIR)? [Y/n]: "
read -r KEEP_SKILL
if [ "$KEEP_SKILL" = "n" ] || [ "$KEEP_SKILL" = "N" ]; then
    rm -rf "$SKILL_DIR"
    echo "✅ Skill 文件已删除"
else
    echo "✅ Skill 文件已保留"
fi

echo ""
echo "=== 卸载完成 ==="
echo ""
echo "⚠️  注意：全局 CLAUDE.md 和项目级 CLAUDE.md 中的 KB 规则段落需手动清理。"
echo "   Vault 中的知识库文件未被删除。"
