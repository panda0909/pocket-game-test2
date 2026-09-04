class_name AudioLibrary
extends RefCounted

## 音效清單與音量換算。純資料，所以「宣告了卻沒有檔案」這種錯誤有測試守著。
##
## 播放本身需要場景樹（見 scenes/audio.gd 的 Audio 自動載入單例），
## 但「哪個事件配哪個聲音」「音量怎麼換算成分貝」不需要，就留在這裡。
##
## 所有音檔由 tools/prepare_audio.py 用純數學合成，和美術走同一套
## 「素材可重現、來源留在版本庫裡」的做法。

const DIR := "res://assets/audio/"
const MUSIC_PATH := DIR + "bgm.wav"

## 靜音的分貝值。不能用 linear_to_db(0) 的負無限大——那會讓 AudioServer
## 收到 -inf，某些平台上會變成 NaN 而整條匯流排靜默壞掉。
const SILENT_DB := -60.0

const _SOUNDS := [
	"boss_down", "boss_hit", "brick_break", "bump", "checkpoint", "clear",
	"coin", "death", "hurry", "hurt", "jump", "menu_confirm", "menu_move",
	"one_up", "pipe", "powerup", "stomp", "throw",
]


static func sound_names() -> Array:
	return _SOUNDS.duplicate()


static func sound_path(name: String) -> String:
	if not _SOUNDS.has(name):
		return ""
	return DIR + name + ".wav"


static func clamp_volume(linear: float) -> float:
	return clampf(linear, 0.0, 1.0)


## 線性音量（0..1，給滑桿用）換算成分貝。
static func linear_to_db(linear: float) -> float:
	var value := clamp_volume(linear)
	if value <= 0.0001:
		return SILENT_DB
	return maxf(SILENT_DB, linear_to_db_raw(value))


static func linear_to_db_raw(linear: float) -> float:
	return 20.0 * (log(linear) / log(10.0))
