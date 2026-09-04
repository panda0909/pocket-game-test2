class_name QuestionBlock
extends StaticBody2D

## 從下方頂得動的磚塊：問號磚、牛奶磚、可破磚。規則在 scripts/block_rules.gd。
##
## 為什麼這三種不進 TileMapLayer：它們各自要記住「被頂過了沒」，還要能單獨
## 播動畫、單獨消失。圖磚沒有狀態，節點才有。

signal popped_coin(world_position: Vector2)
signal popped_milk(cell: Vector2i)

const TILE := TileGlossary.SIZE
const BUMP_HEIGHT := 12.0
const BUMP_TIME := 0.09

@export var kind := TileGlossary.KIND_QUESTION
## 自己在關卡格線上的位置。建構器本來就知道，所以直接存起來——
## 以前是從像素座標反推回來的，而那個反推有兩個隱患：用的是 local
## position（只因為 Entities 剛好在原點才等價，加個關卡震動就全錯），
## 而整數除法對負座標是往零截斷不是往下取整。
@export var cell := Vector2i.ZERO

var _used := false
var _home_y := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("block")
	_home_y = position.y
	_apply_column(TileGlossary.atlas_column(kind))


## 玩家從下方頂上來。回傳 BlockRules 的結果字串，方便測試與除錯。
func hit_from_below(player_is_big: bool) -> String:
	var outcome := BlockRules.resolve_hit(kind, player_is_big, _used)
	match outcome:
		"coin":
			_used = true
			_apply_column(BlockRules.spent_column(kind))
			popped_coin.emit(global_position + Vector2(0, -TILE))
			_bump()
		"milk":
			_used = true
			_apply_column(BlockRules.spent_column(kind))
			popped_milk.emit(cell)
			_bump()
		"broke":
			_break()
		_:
			_bump()
	return outcome


## 頂一下往上跳再回位。這個小動作是「我頂到了」的唯一回饋，
## 沒有它玩家會分不清是頂到了還是撞到牆。
func _bump() -> void:
	Audio.play("bump")
	var tween := create_tween()
	tween.tween_property(self, "position:y", _home_y - BUMP_HEIGHT, BUMP_TIME)
	tween.tween_property(self, "position:y", _home_y, BUMP_TIME * 1.6) \
		.set_trans(Tween.TRANS_BOUNCE)


func _break() -> void:
	Audio.play("brick_break")
	# 只能延後改。_break 是在玩家的碰撞回呼裡被同步呼叫的，直接賦值會被
	# 「Function blocked during in/out signal」擋掉——底下那行直接賦值是
	# 舊寫法的殘留，正是會出問題的那一行。
	set_deferred("collision_layer", 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", Vector2(1.4, 1.4), 0.18)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_property(_sprite, "rotation", 0.6, 0.18)
	tween.chain().tween_callback(queue_free)


func _apply_column(column: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = LevelBuilder.TILES_TEXTURE
	atlas.region = Rect2(column * TILE, 0, TILE, TILE)
	_sprite.texture = atlas
