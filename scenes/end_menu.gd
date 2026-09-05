class_name EndMenu
extends CanvasLayer

## 結束畫面的選單：三個分享動作加上再玩一次。
##
## 操作和選角畫面一致（←→ 選、空白鍵確定），滑鼠也能點。游標預設停在
## 「再玩一次」上，所以「連按兩下空白鍵重來」這個舊習慣仍然有效。

signal chosen(action: String)

const ACTIONS := ["facebook", "threads", "copy", "card", "again"]
const LABELS := ["分享到 Facebook", "分享到 Threads", "複製成績文字",
	"存成績卡圖片", "再玩一次"]
const DEFAULT_ACTION := "again"

const SELECTED_TINT := Color(1, 1, 1)
const IDLE_TINT := Color(0.62, 0.67, 0.76)

## 程式建立的 Button 用的是 Godot 內建字型，那套沒有中文字形，
## 選單文字會變成一排方塊。Label 有 label_settings 指定字型，Button 得自己覆寫。
const BUTTON_FONT := "res://assets/fonts/NotoSansTC-Bold.subset.otf"
const BUTTON_FONT_SIZE := 22

var _index := ACTIONS.find(DEFAULT_ACTION)
var _buttons: Array[Button] = []

@onready var _title: Label = $Panel/Title
@onready var _score: Label = $Panel/Score
@onready var _share_preview: TextureRect = $Panel/SharePreview
@onready var _row: HBoxContainer = $Panel/Row
@onready var _note: Label = $Panel/Note
@onready var _detail: Label = $Panel/Detail


func _ready() -> void:
	_build_buttons()
	_refresh()


func _build_buttons() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for i in ACTIONS.size():
		var button := Button.new()
		button.text = LABELS[i]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(208, 66)
		button.add_theme_font_override("font", load(BUTTON_FONT))
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.pressed.connect(_on_button_pressed.bind(i))
		_row.add_child(button)
		_buttons.append(button)


## 結算。收下整個 RunStats 而不是幾個散裝數字——成績有四條軸
## （分數、金幣、收集率、無傷），再往上加就會變成一長串參數。
func show_result(cleared: bool, stats: RunStats) -> void:
	_title.text = "通關！" if cleared else "遊戲結束"
	_score.text = "分數 %d　　金幣 %d 枚" % [stats.score, stats.found["coin"]]
	# 收集率與無傷是給第二輪、第三輪的理由。第一次通關看到「收集率 58%」
	# 才會知道自己漏了什麼。
	var marks: Array[String] = ["收集率 %d%%" % stats.collect_percent()]
	if cleared and stats.flawless:
		marks.append("全程無傷")
	_detail.text = "　　".join(marks)
	_share_preview.tooltip_text = "這張成績卡就是你這一局的紀錄，存下來可以貼到 IG"
	_note.text = ""
	_index = ACTIONS.find(DEFAULT_ACTION)
	_refresh()


## 由 Main 在結束狀態下轉進按鍵。畫面自己不讀 Input，
## 免得它在其他流程狀態偷吃按鍵。
func handle_action(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_move(-1)
	elif event.is_action_pressed("move_right"):
		_move(1)
	elif event.is_action_pressed("jump"):
		Audio.play("menu_confirm")
		chosen.emit(ACTIONS[_index])


## 換上這一局的成績卡。以前這裡固定顯示三隻角色的合照，還配一行
## 「社群分享預覽」——等於在按下分享之前就告訴玩家「你分享出去的跟你這局
## 無關」。誠實，但直接殺掉分享動機。
func set_card(texture: Texture2D) -> void:
	if texture != null:
		_share_preview.texture = texture


func show_note(text: String) -> void:
	_note.text = text


## 給測試與除錯讀目前狀態用。
func current_action() -> String:
	return ACTIONS[_index]


func current_note() -> String:
	return _note.text


func _move(step: int) -> void:
	Audio.play("menu_move")
	_index = posmod(_index + step, ACTIONS.size())
	_refresh()


func _on_button_pressed(index: int) -> void:
	_index = index
	_refresh()
	Audio.play("menu_confirm")
	chosen.emit(ACTIONS[_index])


func _refresh() -> void:
	for i in _buttons.size():
		var chosen_now := i == _index
		_buttons[i].modulate = SELECTED_TINT if chosen_now else IDLE_TINT
		_buttons[i].scale = Vector2(1.0, 1.0) if chosen_now else Vector2(0.94, 0.94)
