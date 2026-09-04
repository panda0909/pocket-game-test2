class_name PauseMenu
extends CanvasLayer

## 暫停選單：繼續、音效音量、音樂音量、回標題。
##
## 為什麼需要它：這是網頁遊戲，玩家隨時可能要切分頁或接電話。以前唯一的
## 「暫停」方式是把角色停在安全地面上，但計時器仍然在倒數，回來可能已經
## 時間到；也沒有任何方式主動放棄一局回標題。
##
## 和其他兩個選單不同，這個選單自己讀輸入而不是由 Main 轉進來——
## 樹被暫停時 Main 的 _unhandled_input 根本不會跑。process_mode 因此
## 設成 ALWAYS，選單的音效也才聽得到。
##
## 音量用「按一下降一階」而不是滑桿：←→ 已經是選項之間的移動，
## 再拿來調數值會讓兩件事搶同一個鍵。

signal resumed
signal quit_to_title

const ITEMS := ["resume", "sfx", "music", "quit"]
const VOLUME_STEPS := [0.0, 0.25, 0.5, 0.75, 1.0]

const SELECTED_TINT := Color(1, 1, 1)
const IDLE_TINT := Color(0.62, 0.67, 0.76)
const BUTTON_FONT := "res://assets/fonts/NotoSansTC-Bold.otf"
const BUTTON_FONT_SIZE := 22

var _index := 0
var _buttons: Array[Button] = []

@onready var _row: VBoxContainer = $Panel/Row


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_buttons()
	_refresh()


func _build_buttons() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for i in ITEMS.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(360, 62)
		button.add_theme_font_override("font", load(BUTTON_FONT))
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.pressed.connect(_on_button_pressed.bind(i))
		_row.add_child(button)
		_buttons.append(button)


func open() -> void:
	_index = 0
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_activate("resume")
		return
	if event.is_action_pressed("move_left"):
		_move(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("duck"):
		_move(1)
	elif event.is_action_pressed("jump"):
		_activate(ITEMS[_index])
	else:
		return
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	Audio.play("menu_move")
	_index = posmod(_index + step, ITEMS.size())
	_refresh()


func _on_button_pressed(index: int) -> void:
	_index = index
	_refresh()
	_activate(ITEMS[index])


func _activate(item: String) -> void:
	Audio.play("menu_confirm")
	match item:
		"resume":
			close()
			resumed.emit()
		"sfx":
			Audio.set_sfx_volume(_next_step(Audio.sfx_volume))
			Audio.save_settings()
			_refresh()
		"music":
			Audio.set_music_volume(_next_step(Audio.music_volume))
			Audio.save_settings()
			_refresh()
		"quit":
			close()
			quit_to_title.emit()


## 下一階音量。到頂就繞回靜音，玩家只用一個鍵就能走遍所有檔位。
func _next_step(current: float) -> float:
	var nearest := 0
	for i in VOLUME_STEPS.size():
		if absf(VOLUME_STEPS[i] - current) < absf(VOLUME_STEPS[nearest] - current):
			nearest = i
	return VOLUME_STEPS[(nearest + 1) % VOLUME_STEPS.size()]


func _refresh() -> void:
	if _buttons.is_empty():
		return
	_buttons[0].text = "繼續遊戲"
	_buttons[1].text = "音效音量　%d%%" % roundi(Audio.sfx_volume * 100.0)
	_buttons[2].text = "音樂音量　%d%%" % roundi(Audio.music_volume * 100.0)
	_buttons[3].text = "放棄這局，回標題"
	for i in _buttons.size():
		var chosen_now := i == _index
		_buttons[i].modulate = SELECTED_TINT if chosen_now else IDLE_TINT
		_buttons[i].scale = Vector2(1.0, 1.0) if chosen_now else Vector2(0.96, 0.96)


## 給測試與除錯讀目前狀態用。
func current_item() -> String:
	return ITEMS[_index]
