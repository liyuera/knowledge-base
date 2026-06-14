#!/bin/bash
# 共享配置解析 — knowledge-base skill 所有脚本 source 此文件

get_vault_path() {
    if [ -n "$OBSIDIAN_VAULT_PATH" ]; then
        echo "$OBSIDIAN_VAULT_PATH"
        return
    fi
    local config_file="$HOME/.claude/knowledge-base.json"
    if [ -f "$config_file" ]; then
        python3 -c "import json; print(json.load(open('$config_file')).get('vaultPath',''))" 2>/dev/null
    fi
}

get_kb_root() {
    if [ -n "$OBSIDIAN_KB_ROOT" ]; then
        echo "$OBSIDIAN_KB_ROOT"
        return
    fi
    local config_file="$HOME/.claude/knowledge-base.json"
    if [ -f "$config_file" ]; then
        python3 -c "import json; print(json.load(open('$config_file')).get('kbRoot','50-工作日志'))" 2>/dev/null
    else
        echo "50-工作日志"
    fi
}

get_language() {
    if [ -n "$OBSIDIAN_KB_LANGUAGE" ]; then
        echo "$OBSIDIAN_KB_LANGUAGE"
        return
    fi
    local config_file="$HOME/.claude/knowledge-base.json"
    if [ -f "$config_file" ]; then
        python3 -c "import json; print(json.load(open('$config_file')).get('language','zh'))" 2>/dev/null
    else
        echo "zh"
    fi
}

get_technical_category() {
    local config_file="$HOME/.claude/knowledge-base.json"
    if [ -f "$config_file" ]; then
        python3 -c "import json; print(json.load(open('$config_file')).get('categoryMapping',{}).get('technical','10-前端开发/技术学习/学习笔记'))" 2>/dev/null
    else
        echo "10-前端开发/技术学习/学习笔记"
    fi
}
