#!/usr/bin/env bash
# 完整驗證：語法檢查 → 單元測試 → 整合測試。
#
# 整合測試採 headless-safe 的訊號流程，避免在沒有圖形 session 的 CI 或本機
# 驗證環境中被視窗驅動器中止。讓腳本自己 quit()，不加 --quit-after，避免
# 中途卡住時被強制結束而誤判為通過。

set -uo pipefail

GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

status=0

echo "== 重新掃描專案 =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 語法檢查 =="
for f in scripts/*.gd scenes/*.gd tools/*.gd; do
	[ -e "$f" ] || continue
	if ! "$GODOT" --headless --path . --check-only -s "$f" >/dev/null 2>&1; then
		echo "語法錯誤: $f"
		status=1
	fi
done
[ "$status" -eq 0 ] && echo "全部通過"

echo
echo "== 單元測試 =="
if ! tools/run_tests.sh; then
	status=1
fi

echo
echo "== 整合測試 =="
if [ ! -f tools/integration_check.tscn ]; then
	echo "尚未建立 tools/integration_check.tscn，略過"
	echo
	if [ "$status" -eq 0 ]; then
		echo "=== 全部驗證通過（不含整合測試）==="
	else
		echo "=== 有驗證項目失敗 ==="
	fi
	exit "$status"
fi
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
"$GODOT" --headless --path . tools/integration_check.tscn >"$LOG" 2>&1
integration_exit=$?
grep -E "^(通過|失敗)|^整合測試|^環境|^---" "$LOG"
if [ "$integration_exit" -ne 0 ]; then
	echo "整合測試結束碼 ${integration_exit}"
	grep -iE "SCRIPT ERROR|Parse Error" "$LOG" | head -10
	status=1
fi

echo
if [ "$status" -eq 0 ]; then
	echo "=== 全部驗證通過 ==="
else
	echo "=== 有驗證項目失敗 ==="
fi
exit "$status"
