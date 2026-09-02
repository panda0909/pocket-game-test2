#!/usr/bin/env bash
# 執行 GUT 單元測試。
#
# 為什麼不直接呼叫 gut_cmdln.gd？因為 GUT 有兩個會讓測試靜靜爛掉的行為：
#   1. 測試檔剖析失敗時，GUT 直接略過該檔，摘要仍顯示「All tests passed」
#   2. 剖析錯誤不影響結束碼，CI 也不會擋下來
# 所以這裡額外比對「GUT 實際載入的測試檔數」與「磁碟上存在的測試檔數」，
# 對不上就視為失敗。

set -uo pipefail

GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

# 先重掃專案。新增 class_name 之後若不重掃，全域類別快取
# (.godot/global_script_class_cache.cfg) 不會更新，測試會以
# 「Identifier not declared」失敗，而原因跟測試本身無關。
"$GODOT" --headless --path . --import >/dev/null 2>&1

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit >"$LOG" 2>&1
gut_exit=$?

# 去掉 ANSI 色碼才好解析
clean=$(sed $'s/\033\\[[0-9;]*m//g' "$LOG")

expected=$(find test/unit -name 'test_*.gd' | wc -l | tr -d ' ')
loaded=$(printf '%s\n' "$clean" | awk '/^Scripts +[0-9]+/ {print $2; exit}')
passing=$(printf '%s\n' "$clean" | awk '/^Passing Tests +[0-9]+/ {print $3; exit}')
failing=$(printf '%s\n' "$clean" | awk '/^Failing Tests +[0-9]+/ {print $3; exit}')
loaded=${loaded:-0}
passing=${passing:-0}
failing=${failing:-0}

echo "測試檔 ${loaded}/${expected} 載入　通過 ${passing}　失敗 ${failing}"

status=0

if [ "$gut_exit" -ne 0 ]; then
	echo "失敗：GUT 結束碼 ${gut_exit}"
	status=1
fi

if [ "$loaded" -ne "$expected" ]; then
	echo "失敗：有 $((expected - loaded)) 個測試檔沒有被載入（多半是剖析錯誤）"
	printf '%s\n' "$clean" | grep -E "SCRIPT ERROR|Parse Error" | head -20
	status=1
fi

if [ "$failing" -ne 0 ]; then
	echo "失敗：${failing} 個測試未通過"
	printf '%s\n' "$clean" | grep -B2 -A6 "^\[Failed\]" | head -60
	status=1
fi

if [ "$status" -ne 0 ]; then
	echo "--- 完整輸出 ---"
	printf '%s\n' "$clean" | tail -40
else
	echo "全部通過"
fi

exit "$status"
