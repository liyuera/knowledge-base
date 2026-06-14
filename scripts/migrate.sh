#!/bin/bash
# 迁移检测：检查旧配置残留（v1.x 分散配置模式 → v2.0 集中式）

echo "=== knowledge-base 迁移检测 ==="
echo ""

HAS_ISSUES=false

# 1. 检查 settings.json 中的旧格式 hooks
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    # 旧 Stop hook 特征：硬编码 vault 路径
    if grep -q "/50-工作日志/" "$SETTINGS_FILE" 2>/dev/null; then
        echo "⚠️  settings.json 中发现旧 Stop hook（硬编码 vault 路径）"
        echo "   建议: 运行 install.sh 自动清理"
        HAS_ISSUES=true
    fi
    # 旧 UserPromptSubmit hook 特征："禁止不输出" 措辞
    if grep -q "禁止不输出" "$SETTINGS_FILE" 2>/dev/null; then
        echo "⚠️  settings.json 中发现旧 UserPromptSubmit hook（旧版措辞）"
        echo "   建议: 运行 install.sh 自动清理"
        HAS_ISSUES=true
    fi
    # 旧 SessionStart 组合 hook（同时含 KB 和其他 skill 引用）
    if grep -q "knowledge-base" "$SETTINGS_FILE" 2>/dev/null && \
       grep -q "andrej-karpathy" "$SETTINGS_FILE" 2>/dev/null; then
        # 检查是否在同一个 hook 中（旧组合模式）
        if python3 -c "
import json
s = json.load(open('$SETTINGS_FILE'))
for h in s.get('hooks',{}).get('SessionStart',[]):
    c = json.dumps(h)
    if 'knowledge-base' in c and 'andrej-karpathy' in c:
        print('FOUND')
        break
" 2>/dev/null | grep -q "FOUND"; then
            echo "⚠️  settings.json 中发现旧组合 SessionStart hook（KB + 其他skill 合并）"
            echo "   建议: 手动拆分为独立 hook 或运行 install.sh 自动处理"
            HAS_ISSUES=true
        fi
    fi
fi

# 2. 检查全局 CLAUDE.md 中的旧 KB 规则段落
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    if grep -q "knowledge-base skill 运行日志" "$CLAUDE_MD" 2>/dev/null; then
        echo "⚠️  ~/.claude/CLAUDE.md 中存在 'knowledge-base skill 运行日志' 段落"
        echo "   建议: 手动删除该段落（规则已由 skill 接管）"
        HAS_ISSUES=true
    fi
    if grep -q "会话启动流程.*knowledge-base" "$CLAUDE_MD" 2>/dev/null; then
        echo "⚠️  ~/.claude/CLAUDE.md 中存在 '会话启动流程' KB 段落"
        echo "   建议: 手动删除该段落（hooks 已接管）"
        HAS_ISSUES=true
    fi
fi

# 3. 检查项目级 CLAUDE.md
if [ -f "CLAUDE.md" ] && grep -q "会话启动流程.*knowledge-base\|加载.*knowledge-base" "CLAUDE.md" 2>/dev/null; then
    echo "⚠️  项目级 CLAUDE.md 中存在旧 KB 规则段落"
    echo "   建议: 手动删除 '会话启动流程' 段落"
    HAS_ISSUES=true
fi

if [ "$HAS_ISSUES" = false ]; then
    echo "✅ 未发现旧配置残留"
fi

echo ""
echo "检测完成"
