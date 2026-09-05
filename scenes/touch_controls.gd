class_name TouchControls
extends CanvasLayer

## 行動裝置的虛擬按鍵。
##
## 為什麼非有不可：發佈目標是 GitHub Pages，而連結最常見的開啟方式就是
## 手機點一下。以前輸入表五個動作全部只綁鍵盤，手機玩家會下載 46 MB、
## 看到選單、選好角色，然後發現不能移動也不能跳——成本全付了，價值零。
##
## 用 TouchScreenButton 而不是 Button：Button 靠滑鼠模擬，一次只認得一個
## 觸點，玩家沒辦法一邊按右一邊跳。TouchScreenButton 原生支援多點觸控，
## 而平台遊戲不能同時移動與跳躍等於不能玩。
##
## 按鍵只在真的有觸控螢幕時出現，桌面版不會被一排半透明圓圈擋住畫面。

## 每顆鍵：動作、圓心、半徑、標籤。座標是 1280x720 的設計解析度，
## stretch 模式會幫忙縮放。
const BUTTONS := [
	{"action": "move_left", "at": Vector2(100, 570), "r": 58.0, "label": "◀"},
	{"action": "move_right", "at": Vector2(248, 570), "r": 58.0, "label": "▶"},
	{"action": "duck", "at": Vector2(174, 672), "r": 44.0, "label": "▼"},
	{"action": "jump", "at": Vector2(1170, 580), "r": 68.0, "label": "跳"},
	{"action": "throw", "at": Vector2(1020, 636), "r": 50.0, "label": "丟"},
	{"action": "sprint", "at": Vector2(1030, 490), "r": 50.0, "label": "衝"},
	{"action": "pause", "at": Vector2(1216, 60), "r": 38.0, "label": "停"},
]

const FILL := Color(1, 1, 1, 0.18)
const EDGE := Color(1, 1, 1, 0.42)
const LABEL_COLOR := Color(1, 1, 1, 0.72)
const FONT_PATH := "res://assets/fonts/NotoSansTC-Bold.subset.otf"


## 只有在真的觸控裝置上，而且真的在玩的時候才顯示。
##
## 以前 visible 只在 _ready() 設一次，之後從不切換，而這一層的 layer 高於
## 所有選單——標題、選角、暫停、結束畫面上都掛著七顆半透明圓圈，選角畫面的
## 「丟」鍵直接壓在提示文字上，結束畫面的跳鍵範圍與「再玩一次」按鈕重疊。
var _available := false


## 標題與選角也要看得到按鍵——那兩個畫面都得靠「跳」鍵確定、靠「◀▶」
## 換角色。只有在有自己按鈕的畫面（暫停、結束選單）才收起來，那裡的
## 跳鍵範圍會壓到「再玩一次」按鈕上。
func set_active(active: bool) -> void:
	visible = _available and active


func _ready() -> void:
	layer = 4
	_available = should_show()
	visible = false
	if not _available:
		return
	var painter := _Painter.new()
	add_child(painter)
	for spec in BUTTONS:
		add_child(_make_button(spec))


## 只在有觸控螢幕的裝置上顯示。
##
## 抽成 static 是為了讓測試問得到判斷條件，不必真的生出一堆節點。
static func should_show() -> bool:
	return DisplayServer.is_touchscreen_available()


func _make_button(spec: Dictionary) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.action = spec["action"]
	button.position = spec["at"]
	var shape := CircleShape2D.new()
	shape.radius = spec["r"]
	button.shape = shape
	# 手指會滑動，passby_press 讓按住之後滑進另一顆鍵也算按下。
	button.passby_press = true
	return button


## 圓圈與字自己畫，不必為了六顆按鍵準備六張圖。
class _Painter extends Node2D:
	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		var font := load(TouchControls.FONT_PATH) as Font
		for spec in TouchControls.BUTTONS:
			var at: Vector2 = spec["at"]
			var r: float = spec["r"]
			draw_circle(at, r, TouchControls.FILL)
			draw_arc(at, r, 0.0, TAU, 48, TouchControls.EDGE, 3.0, true)
			if font == null:
				continue
			var text: String = spec["label"]
			var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, 30)
			draw_string(font, at + Vector2(-size.x * 0.5, size.y * 0.32),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30,
				TouchControls.LABEL_COLOR)
