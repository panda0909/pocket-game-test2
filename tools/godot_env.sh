#!/usr/bin/env bash
# Godot 執行檔的解析，以及一個可攜的逾時執行器。三支腳本共用。
#
# 用 source 引入，不要直接執行。
#
# 以前三支腳本各寫一份 GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/...}"，
# 預設值綁死在某一台機器的 Downloads 目錄——那是個隨時會被清理的地方。
# 換機器或整理下載資料夾之後，每個 --check-only 都會失敗、每個檔案都被報成
# 「語法錯誤」，而真正的原因只是找不到執行檔。

# 依序尋找：環境變數 → PATH → macOS 常見安裝位置。
resolve_godot() {
	if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then
		printf '%s' "$GODOT"
		return 0
	fi
	if [ -n "${GODOT:-}" ] && command -v "$GODOT" >/dev/null 2>&1; then
		command -v "$GODOT"
		return 0
	fi
	local candidate
	for candidate in godot godot4 Godot; do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
	done
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
		if [ -x "$candidate" ]; then
			printf '%s' "$candidate"
			return 0
		fi
	done
	return 1
}

if ! GODOT=$(resolve_godot); then
	echo "找不到 Godot 執行檔。" >&2
	echo "請安裝 Godot 4，或用環境變數指定路徑：" >&2
	echo "    GODOT=/path/to/Godot tools/$(basename "${0}")" >&2
	exit 2
fi
export GODOT

# 有時限地執行一個指令。macOS 預設沒有 coreutils 的 timeout，所以自己來。
# 逾時回傳 124，和 timeout(1) 一致。
run_with_timeout() {
	local seconds="$1"
	shift
	"$@" &
	local pid=$!
	local waited=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$waited" -ge "$seconds" ]; then
			kill -TERM "$pid" 2>/dev/null
			sleep 2
			kill -KILL "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
			return 124
		fi
		sleep 1
		waited=$((waited + 1))
	done
	wait "$pid"
}
