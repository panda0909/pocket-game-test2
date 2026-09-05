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
const MUSIC := preload("res://assets/audio/bgm.wav")
const MUSIC_PATH := DIR + "bgm.wav"

## 靜音的分貝值。不能用 linear_to_db(0) 的負無限大——那會讓 AudioServer
## 收到 -inf，某些平台上會變成 NaN 而整條匯流排靜默壞掉。
const SILENT_DB := -60.0

const _SOUNDS := {
	"boss_down": preload("res://assets/audio/boss_down.wav"),
	"boss_hit": preload("res://assets/audio/boss_hit.wav"),
	"brick_break": preload("res://assets/audio/brick_break.wav"),
	"bump": preload("res://assets/audio/bump.wav"),
	"checkpoint": preload("res://assets/audio/checkpoint.wav"),
	"clear": preload("res://assets/audio/clear.wav"),
	"coin": preload("res://assets/audio/coin.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"denied": preload("res://assets/audio/denied.wav"),
	"hurry": preload("res://assets/audio/hurry.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"jump": preload("res://assets/audio/jump.wav"),
	"menu_confirm": preload("res://assets/audio/menu_confirm.wav"),
	"menu_move": preload("res://assets/audio/menu_move.wav"),
	"one_up": preload("res://assets/audio/one_up.wav"),
	"pipe": preload("res://assets/audio/pipe.wav"),
	"powerup": preload("res://assets/audio/powerup.wav"),
	"stomp": preload("res://assets/audio/stomp.wav"),
	"throw": preload("res://assets/audio/throw.wav"),
}


static func sound_names() -> Array:
	return _SOUNDS.keys()


## 音效資源本身。用 preload 而不是執行期 load 是必要的，不是偏好：
## export_presets.cfg 的 export_filter 是 "resources"，只匯出 main.tscn
## 的相依樹，其餘全靠 include_filter 手動列白名單。執行期 load 的檔案
## 沒有任何靜態參考，漏列就是「線上版沒聲音、本機正常」。
static func sound(name: String) -> AudioStream:
	return _SOUNDS.get(name)


static func sound_path(name: String) -> String:
	var stream: AudioStream = _SOUNDS.get(name)
	return "" if stream == null else stream.resource_path


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
