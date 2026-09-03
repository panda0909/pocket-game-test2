class_name HUD
extends CanvasLayer

## 分數列與置中訊息。它只顯示，不決定任何事——所有狀態都由 Main 推進來。

@onready var _stats_row: HBoxContainer = $Top
@onready var _score: Label = $Top/Score
@onready var _coins: Label = $Top/Coins
@onready var _lives: Label = $Top/Lives
@onready var _time: Label = $Top/Time
@onready var _dim: ColorRect = $Dim
@onready var _message: VBoxContainer = $Message
@onready var _title: Label = $Message/Title
@onready var _subtitle: Label = $Message/Subtitle


func update_stats(stats: RunStats, is_big: bool) -> void:
	_score.text = "分數 %06d" % stats.score
	# 金幣同時是彈藥，大牛時標上彈匣符號提醒它可以丟
	_coins.text = "%s %d" % ["金幣◆" if is_big else "金幣", stats.coins]
	_lives.text = "生命 %d" % stats.lives
	_time.text = "時間 %03d" % stats.seconds_left()
	# 剩不到 30 秒轉紅，這是玩家唯一會注意到時間的時刻
	_time.modulate = Color(1, 0.45, 0.4) if stats.seconds_left() <= 30 \
		else Color(1, 1, 1)


## 上方那排數值只在真的在玩的時候有意義。標題與選角畫面顯示
## 「分數 000000　時間 300」只是雜訊，選角畫面還會和角色圖疊在一起。
func set_stats_visible(visible_now: bool) -> void:
	_stats_row.visible = visible_now


func show_message(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_message.visible = true
	_dim.visible = true


func hide_message() -> void:
	_message.visible = false
	_dim.visible = false
