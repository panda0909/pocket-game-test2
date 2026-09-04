#!/usr/bin/env bash
# 完整驗證：語法檢查 → 單元測試 → 整合測試。
#
# 整合測試採 headless-safe 的訊號流程，避免在沒有圖形 session 的 CI 或本機
# 驗證環境中被視窗驅動器中止。讓腳本自己 quit()，不加 --quit-after，避免
# 中途卡住時被強制結束而誤判為通過。

set -uo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=tools/godot_env.sh
. tools/godot_env.sh

# 整合測試最多跑多久。它是一串 await，任何一個環節卡住就永遠不會走到
# quit()，而 headless Godot 會無限等下去——本機是浪費一個下午，接上 CI
# 就是把 runner 佔到逾時。
INTEGRATION_TIMEOUT="${INTEGRATION_TIMEOUT:-300}"

status=0

echo "== 重新掃描專案 =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 語法檢查 =="
# 測試檔也要檢查。它們的剖析錯誤原本只能靠 run_tests.sh 的「載入檔數對不上」
# 間接抓到，而那只告訴你少了幾個檔，不告訴你是哪一個。
for f in scripts/*.gd scenes/*.gd tools/*.gd test/unit/*.gd; do
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
# 這個場景檔是專案的必要組成，不是可選項。以前它不存在時只印一行「略過」
# 然後可能 exit 0 並印「全部驗證通過」——整個測試策略最重的一塊（唯一驗證
# scenes/ 的東西）掛在一個不會失敗的存在性檢查上。
if [ ! -f tools/integration_check.tscn ]; then
	echo "失敗：找不到 tools/integration_check.tscn"
	echo
	echo "=== 有驗證項目失敗 ==="
	exit 1
fi
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
run_with_timeout "$INTEGRATION_TIMEOUT" \
	"$GODOT" --headless --path . tools/integration_check.tscn >"$LOG" 2>&1
integration_exit=$?
grep -E "^(通過|失敗)|^整合測試|^環境|^---" "$LOG"
if [ "$integration_exit" -eq 124 ]; then
	echo "整合測試逾時（超過 ${INTEGRATION_TIMEOUT} 秒還沒走到 quit）"
	tail -20 "$LOG"
	status=1
elif [ "$integration_exit" -ne 0 ]; then
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
