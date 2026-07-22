#!/bin/bash
# ============================================================
# GDScript 编译扫描（--check-only）
# 用途：抓 headless 场景自检覆盖不到的编辑器级错误（类型推断、
#       标识符缺失等）。案例：PR#2 修复的 "Cannot infer the type
#       of chosen"——语法解析(gdparse)和逻辑自检都抓不到这类错误。
#
# 用法：
#   GODOT=/path/to/godot tests/check_scripts.sh [file.gd ...]
#   不传参数时扫描默认清单（棋盘玩法相关脚本）。
#
# 已知局限：--check-only 不加载 autoload 单例，对 autoload 的引用
# 会误报 "Identifier not found"——脚本自动从 project.godot 读取
# autoload 名单做白名单过滤。若某文件同时存在真错误和 autoload
# 引用，编译在首个错误处停止，可能互相遮蔽；编辑器仍是最终权威。
# ============================================================
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! "$GODOT" --version >/dev/null 2>&1; then
	echo "错误: 未找到 Godot 可执行文件，请设置 GODOT 环境变量" >&2
	exit 2
fi

# 从 project.godot 提取 autoload 名单（误报白名单）
AUTOLOADS=$(sed -n '/^\[autoload\]/,/^\[/p' project.godot | grep -o '^[A-Za-z_][A-Za-z0-9_]*=' | tr -d '=' | paste -sd'|')

# 默认扫描清单：棋盘玩法全部脚本 + 触及的核心系统 + 测试
DEFAULT_FILES=(
	scripts/board_game/*.gd
	scenes/S14_BoardGame.gd
	core/InteractionSystem.gd
	tests/board_game_selfcheck.gd
	tests/level_state_manager_selfcheck.gd
	tests/board_montecarlo.gd
)

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
	FILES=("${DEFAULT_FILES[@]}")
fi

fail=0
for f in "${FILES[@]}"; do
	[ -f "$f" ] || continue
	out=$("$GODOT" --headless --path . --check-only --script "$f" 2>&1 | grep "SCRIPT ERROR")
	# 过滤 autoload 误报
	if [ -n "$AUTOLOADS" ]; then
		real=$(echo "$out" | grep -v -E "Identifier not found: ($AUTOLOADS)$" | grep -v '^$')
	else
		real="$out"
	fi
	if [ -n "$real" ]; then
		echo "FAIL: $f"
		echo "$real" | sed 's/^/  /'
		fail=1
	else
		echo "PASS: $f"
	fi
done

if [ $fail -ne 0 ]; then
	echo "-- 编译扫描存在错误 --"
	exit 1
fi
echo "-- 编译扫描全部通过 --"
exit 0
