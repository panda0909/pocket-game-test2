class_name CharacterSelect
extends CanvasLayer

## 選角畫面。三隻並排，選中的放大且不透明，旁邊兩隻縮小壓暗。
##
## 它只顯示與回報，不決定任何事——按鍵由 Main 讀，選到第幾隻也由 Main 保管。
## 這是專案一貫的「訊號單向往上」：子節點不知道 Main 存在。

signal moved(direction: int)
signal confirmed
signal cancelled

const SELECTED_SCALE := Vector2(1.0, 1.0)
const IDLE_SCALE := Vector2(0.72, 0.72)
const SELECTED_TINT := Color(1, 1, 1)
const IDLE_TINT := Color(0.55, 0.6, 0.7)
const TWEEN_TIME := 0.14

var _index := Roster.DEFAULT_INDEX
var _slots: Array[TextureRect] = []

@onready var _row: HBoxContainer = $Row
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	_build_slots()
	show_index(_index)


## 依 Roster 動態建出三個格子。角色數量改了這裡不必跟著改。
func _build_slots() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

	_slots.clear()
	for i in Roster.COUNT:
		var slot := TextureRect.new()
		slot.texture = load(Roster.texture_path(i))
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.custom_minimum_size = Vector2(200, 260)
		# 支點放在腳底中央，放大時往上長，三隻的腳因此站在同一條線上。
		# 放在正中央的話選中的那隻會往下長，看起來比另兩隻矮一截。
		slot.pivot_offset = Vector2(100, 260)
		_row.add_child(slot)
		_slots.append(slot)


func show_index(index: int) -> void:
	_index = Roster.clamp_index(index)
	# 名字底下寫一句這隻的特色。三隻有了各自的手感差異之後，
	# 選角才是一個真的決策而不是純造型。
	_name_label.text = "◀　%s　▶\n%s" % [
		Roster.name_of(_index), Roster.traits(_index)["blurb"]]
	for i in _slots.size():
		var slot := _slots[i]
		var chosen := i == _index
		var tween := slot.create_tween().set_parallel()
		tween.tween_property(slot, "scale",
			SELECTED_SCALE if chosen else IDLE_SCALE, TWEEN_TIME)
		tween.tween_property(slot, "modulate",
			SELECTED_TINT if chosen else IDLE_TINT, TWEEN_TIME)


## 由 Main 在 SELECT 狀態下把按鍵轉進來。畫面自己不讀 Input，
## 這樣它在其他流程狀態下不會偷吃按鍵。
func handle_action(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		Audio.play("menu_move")
		moved.emit(-1)
	elif event.is_action_pressed("move_right"):
		Audio.play("menu_move")
		moved.emit(1)
	elif event.is_action_pressed("jump"):
		Audio.play("menu_confirm")
		confirmed.emit()
	elif event.is_action_pressed("duck"):
		Audio.play("menu_move")
		cancelled.emit()
