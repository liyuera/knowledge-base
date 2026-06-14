# knowledge-base skill

Claude Code 的 Obsidian 知识库自动收集、整理、写入 skill。

每次会话自动加载上下文，代码修改后自动提醒写入知识库条目，会话结束时兜底校验遗漏。

## 安装

```bash
# 1. 克隆到 skills 目录
git clone <repo-url> ~/.claude/skills/knowledge-base/

# 2. 运行安装脚本
bash ~/.claude/skills/knowledge-base/install.sh
```

安装脚本会自动：
- 引导你配置 Obsidian Vault 路径（可选，跳过则使用项目本地存储）
- 将 hooks 添加到 `~/.claude/settings.json`
- 部署 skill 文件到正确位置
- 检测并提示清理旧配置残留

## 配置

安装脚本会创建 `~/.claude/knowledge-base.json`：

```json
{
  "version": "2.0.0",
  "vaultPath": "/Users/you/ObsidianVault/",
  "kbRoot": "50-工作日志",
  "language": "zh"
}
```

也可以使用环境变量覆盖（优先级高于配置文件）：

| 环境变量 | 说明 | 示例 |
|----------|------|------|
| `OBSIDIAN_VAULT_PATH` | Vault 根目录 | `/Users/you/Docs/` |
| `OBSIDIAN_KB_ROOT` | Vault 内的知识库目录名 | `50-工作日志` |
| `OBSIDIAN_KB_LANGUAGE` | 界面语言 | `zh` / `en` |

## 目录结构

**有 vault 配置时：**
```
<Vault>/<KB_ROOT>/<项目名>/<分支>/<YYYYMMDD>/<YYYYMMDD>.md
```

**无 vault 配置时（项目本地模式）：**
```
<项目>/.claude/knowledge-base/<分支>/<YYYYMMDD>/<YYYYMMDD>.md
```

## 功能

- **前置检查**：每次会话自动加载知识库上下文、MEMORY.md、组件规则、待办项
- **自动提醒**：代码修改完成后自动提醒写入知识库条目
- **兜底校验**：会话结束时检查今日 KB 文件状态
- **MEMORY.md 自动管理**：从 CLAUDE.md + git log 自动生成和同步
- **技术问题分类**：技术性问题自动归类到技术学习笔记
- **项目本地 fallback**：无 Obsidian vault 时自动使用项目本地存储
- **可配置路径**：支持环境变量和配置文件两种方式配置路径

## 写入格式

```markdown
### #N [类型] 一句话概述
- **操作**: 具体做了什么
- **文件**: `path/to/file.js:行号`
- **原因**: 为什么这样做
- **结果**: 解决了什么

---
```

类型枚举：`[修复]` `[新增]` `[重构]` `[决策]`

## 卸载

```bash
bash ~/.claude/skills/knowledge-base/uninstall.sh
```

卸载脚本支持选择性保留配置文件和 skill 文件。

## 迁移

从旧版（v1.x，规则分散在 settings.json / CLAUDE.md 中）迁移：

```bash
# 检测旧配置残留
bash ~/.claude/skills/knowledge-base/scripts/migrate.sh

# 如检测到问题，重新运行安装脚本自动清理
bash ~/.claude/skills/knowledge-base/install.sh
```

## 文件结构

```
skills/knowledge-base/
├── SKILL.md              # 主 skill 定义（唯一规则来源）
├── install.sh            # 一键安装脚本
├── uninstall.sh          # 卸载脚本
├── LICENSE               # MIT
├── README.md             # 本文档
├── scripts/
│   ├── _config.sh        # 路径解析公共函数
│   ├── check-kb.sh       # Stop hook 调用的兜底校验
│   └── migrate.sh        # 旧配置迁移检测
└── templates/
    └── knowledge-base.json  # 配置文件模板
```

## License

MIT
