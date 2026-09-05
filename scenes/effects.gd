class_name Effects
extends Node2D

## 短命的表演物件：頂磚彈出的金幣、得分浮字、投射物。
##
## 從 Main 抽出來的理由不是行數，是職責——Main 原本同時管關卡載入、訊號
## 接線、流程狀態機、分享選單文案「和」這些 tween。改任何一件事都要進同一
## 個檔案，而那正是「用一個旗標同時控制關卡切換與成績重建」那類 bug 的溫床。
##
## 這裡只生成與播放，不知道分數、流程或關卡是什麼。

const POWERUP_SCENE := preload("res://scenes/powerup.tscn")
const COIN_SHOT_SCENE := preload("res://scenes/coin_shot.tscn")
const BOSS_SHOT_SCENE := preload("res://scenes/boss_shot.tscn")
const COIN_TEXTURE := preload("res://assets/coin.png")

## 程式建立的 Label 用內建字型會變成一排方塊，所以自己指定。
const POPUP_FONT := preload("res://assets/fonts/NotoSansTC-Bold.subset.otf")
const POPUP_FONT_SIZE := 26

## 頂出來的金幣飛多高、多久。飛完就消失，不必玩家再去撿——
## 他已經頂到了，再讓他追一顆金幣只是多餘的操作。
const COIN_POP_HEIGHT := 96.0
const COIN_POP_TIME := 0.45
## 加分與扣分要一眼分得出來。
const GAIN_COLOR := Color(1, 1, 1)
const LOSS_COLOR := Color(1, 0.55, 0.5)

const SCORE_POP_HEIGHT := 76.0
const SCORE_POP_TIME := 0.7


## 頂磚彈出的金幣。
func coin_pop(world_position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = COIN_TEXTURE
	sprite.position = world_position
	add_child(sprite)
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "position:y",
		world_position.y - COIN_POP_HEIGHT, COIN_POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, COIN_POP_TIME)
	tween.chain().tween_callback(sprite.queue_free)


## 得分浮字。整個計分系統是為了分享成績而存在，但玩家在遊玩中得不到
## 「這個動作值 200 分」的即時知識，也就無從發展刷分策略——踩刺球值最多分
## 這件事幾乎不可能被發現。
## 得分浮字。負分也要跳——丟金幣會退還撿到時記的 50 分，那是計分系統的
## 核心取捨，但以前 amount <= 0 直接 return，玩家完全看不到它發生。
func score_popup(world_position: Vector2, amount: int) -> void:
	if amount == 0:
		return
	var label := Label.new()
	label.text = ("+%d" % amount) if amount > 0 else ("%d" % amount)
	label.add_theme_color_override("font_color",
		GAIN_COLOR if amount > 0 else LOSS_COLOR)
	label.add_theme_font_override("font", POPUP_FONT)
	label.add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.14))
	label.add_theme_constant_override("outline_size", 8)
	label.position = world_position
	label.z_index = 10
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y",
		world_position.y - SCORE_POP_HEIGHT, SCORE_POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, SCORE_POP_TIME)
	tween.chain().tween_callback(label.queue_free)


## 問號磚頂出來的牛奶。落點由關卡資料決定——「底下第一格實心地面在哪」
## 本來就該問資料，在場景裡打射線只會先打到磚塊自己。
func drop_milk(cell: Vector2i, map: LevelMap) -> void:
	var milk := POWERUP_SCENE.instantiate()
	milk.position = LevelBuilder.cell_center(cell) + Vector2(0, -TileGlossary.SIZE * 0.4)
	add_child(milk)
	milk.drop_to(float(map.ground_surface_row_below(cell) * TileGlossary.SIZE),
		map.drift_direction(cell))


func boss_projectile(origin: Vector2, direction: Vector2) -> void:
	var shot := BOSS_SHOT_SCENE.instantiate()
	shot.position = origin
	add_child(shot)
	shot.launch(direction)


## 玩家丟出的金幣。回傳節點讓 Main 接命中訊號——命中要記分，
## 而記分不是這裡的事。
func coin_shot(origin: Vector2, direction: int) -> CoinShot:
	var shot: CoinShot = COIN_SHOT_SCENE.instantiate()
	shot.position = origin
	add_child(shot)
	shot.launch(direction)
	return shot


## 清掉場上所有短命物件。換場時用——暗房裡頂出來卻沒撿的牛奶、
## 還在飛的金幣，都不該跟著玩家穿過水管。
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
