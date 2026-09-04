class_name HUD
extends CanvasLayer

## 分數列與置中訊息。它只顯示，不決定任何事——所有狀態都由 Main 推進來。

@onready var _stats_row: HBoxContainer = $Top
@onready var _score: Label = $Top/Score
@onready var _coins: Label = $Top/Coins
@onready var _lives: Label = $Top/Lives
@onready var _time: Label = $Top/Time
@onready var _dim: ColorRect = $Dim
@onready var _boss_row: VBoxContainer = $Boss
@onready var _boss_bar: ProgressBar = $Boss/BossBar
@onready var _message: VBoxContainer = $Message
@onready var _title: Label = $Message/Title
@onready var _subtitle: Label = $Message/Subtitle


## 剩幾秒開始警告。Main 的警告音也用這個值，兩邊不會各寫一個 30。
const HURRY_SECONDS := 30

const NORMAL_COLOR := Color(1, 1, 1)
const HURRY_COLOR := Color(1, 0.45, 0.4)

## 上一幀的值。update_stats 是每幀被呼叫的，但四個數字裡只有時間會每秒
## 變一次——分數與金幣一整場可能都不變。不比對就等於每秒做 240 次
## 字串格式化與配置，在 Web 版的單執行緒環境是白繳的。
var _last_score := -1
var _last_coins := -1
var _last_lives := -1
var _last_seconds := -1
var _last_big := false


func update_stats(stats: RunStats, is_big: bool) -> void:
	if stats.score != _last_score:
		_last_score = stats.score
		_score.text = "分數 %06d" % stats.score
	if stats.coins != _last_coins or is_big != _last_big:
		_last_coins = stats.coins
		_last_big = is_big
		# 金幣同時是彈藥，大牛時標上彈匣符號提醒它可以丟
		_coins.text = "%s %d" % ["金幣◆" if is_big else "金幣", stats.coins]
	if stats.lives != _last_lives:
		_last_lives = stats.lives
		_lives.text = "生命 %d" % stats.lives
	var seconds := stats.seconds_left()
	if seconds != _last_seconds:
		_last_seconds = seconds
		_time.text = "時間 %03d" % seconds
		# 剩不到 30 秒轉紅，這是玩家唯一會注意到時間的時刻
		_time.modulate = HURRY_COLOR if seconds <= HURRY_SECONDS else NORMAL_COLOR


## 換一局要把快取清掉，不然新的一局數字剛好一樣時 Label 不會更新。
func reset_cache() -> void:
	_last_score = -1
	_last_coins = -1
	_last_lives = -1
	_last_seconds = -1


## 上方那排數值只在真的在玩的時候有意義。標題與選角畫面顯示
## 「分數 000000　時間 300」只是雜訊，選角畫面還會和角色圖疊在一起。
func set_stats_visible(visible_now: bool) -> void:
	_stats_row.visible = visible_now


## Boss 血條。玩家原本完全看不出自己打了幾下、還要打幾下——金幣路線要
## 六發，每發之間還有 0.8 秒無敵，而「打中了沒傷害」與「打中了有傷害」
## 在畫面上長得一模一樣。玩家會誤以為金幣打不動 Boss 而放棄那條路線，
## 但那正是設計的核心。
func set_boss_health(ratio: float) -> void:
	_boss_row.visible = true
	_boss_bar.value = clampf(ratio, 0.0, 1.0)


func hide_boss_health() -> void:
	_boss_row.visible = false


func _ready() -> void:
	_boss_row.visible = false


func show_message(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_message.visible = true
	_dim.visible = true


func hide_message() -> void:
	_message.visible = false
	_dim.visible = false
