class_name TelemetryEvents
extends RefCounted

## 埋點事件的定義與清洗。純資料，所以「送得出去的到底是什麼」有測試守著。
##
## 為什麼需要埋點：專案原本沒有任何分析，於是「多少人撐過載入」「多少人
## 按了開始」「多少人通關」「多少人按分享」一項都量不到——所有決策都只能
## 靠推算，包括那份產品診斷裡對難度與流失的判斷。六個事件就能畫出完整漏斗。
##
## 為什麼要清洗：埋點是會把資料送出瀏覽器的東西。這一層的責任是讓它
## 「只送得出白名單裡的欄位，而且值只能是數字或短字串」——玩家的任何
## 個人資訊都不該有機會被夾帶出去，就算日後有人不小心多傳了一個參數。
##
## 預設不送到任何地方：scenes/telemetry.gd 只呼叫 window.pocketGameEvent，
## 而 HTML 殼裡那個函式預設是空的。要接哪一家分析服務由專案擁有者決定。

const LOADED := "loaded"
const STARTED := "start_pressed"
const CHARACTER := "character_confirmed"
const CHECKPOINT := "checkpoint"
const CLEARED := "cleared"
const GAME_OVER := "game_over"
const SHARED := "share_clicked"

## 字串欄位的長度上限。埋點的值應該是分類標籤，不是自由文字。
const MAX_STRING := 32

const _NAMES := [LOADED, STARTED, CHARACTER, CHECKPOINT, CLEARED,
	GAME_OVER, SHARED]

## 允許送出的欄位。加新欄位要想清楚它會不會夾帶個資。
const _ALLOWED := [
	"index",        # 選了第幾隻角色
	"cell",         # 走到第幾格（檢查點、結束時）
	"score",
	"coins",
	"collect_pct",
	"time_left",
	"lives",
	"flawless",
	"platform",     # 按了哪個分享按鈕
	"touch",        # 是不是觸控裝置
]


static func names() -> Array:
	return _NAMES.duplicate()


static func is_known(name: String) -> bool:
	return _NAMES.has(name)


## 認不得的事件名回空字串，呼叫端就不會送。
##
## 打錯字的事件如果照送，那個事件在報表上永遠是 0，而且不會有人發現——
## 和 Flow 的魔法字串是同一類問題。
static func sanitize_name(name: String) -> String:
	return name if is_known(name) else ""


## 只留白名單裡、而且值是數字或短字串的欄位。
static func sanitize(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in props:
		var name := str(key)
		if not _ALLOWED.has(name):
			continue
		var value: Variant = props[key]
		if value is int or value is float or value is bool:
			out[name] = value
		elif value is String:
			out[name] = (value as String).substr(0, MAX_STRING)
	return out
