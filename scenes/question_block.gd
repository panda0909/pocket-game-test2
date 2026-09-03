class_name QuestionBlock
extends StaticBody2D

## 從下方頂得動的磚塊：問號磚、牛奶磚、可破磚。規則在 scripts/block_rules.gd。
##
## 為什麼這三種不進 TileMapLayer：它們各自要記住「被頂過了沒」，還要能單獨
## 播動畫、單獨消失。圖磚沒有狀態，節點才有。

signal popped_coin(position: Vector2)
signal popped_milk(position: Vector2)

const TILE := 64
const BUMP_HEIGHT := 12.0
const BUMP_TIME := 0.09

var kind := TileGlossary.KIND_QUESTION

var _used := false
var _home_y := 0.0

@onready var _sprite: Sprite2D = $Sprite


func setup(block_kind: int) -> void:
	kind = block_kind


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
			popped_milk.emit(global_position + Vector2(0, -TILE))
			_bump()
		"broke":
			_break()
		_:
			_bump()
	return outcome


## 頂一下往上跳再回位。這個小動作是「我頂到了」的唯一回饋，
## 沒有它玩家會分不清是頂到了還是撞到牆。
func _bump() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", _home_y - BUMP_HEIGHT, BUMP_TIME)
	tween.tween_property(self, "position:y", _home_y, BUMP_TIME * 1.6) \
		.set_trans(Tween.TRANS_BOUNCE)


func _break() -> void:
	collision_layer = 0
	set_deferred("collision_layer", 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", Vector2(1.4, 1.4), 0.18)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_property(_sprite, "rotation", 0.6, 0.18)
	tween.chain().tween_callback(queue_free)


func _apply_column(column: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/tiles.png")
	atlas.region = Rect2(column * TILE, 0, TILE, TILE)
	_sprite.texture = atlas
