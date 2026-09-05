class_name MovingPlatform
extends AnimatableBody2D

## 來回移動的平台。用 AnimatableBody2D 加 sync_to_physics，站在上面的玩家
## 才會被一起帶著走——換成 StaticBody2D 的話玩家會在平台上滑掉。

const TILE := TileGlossary.SIZE
const SPEED := 80.0
const TRAVEL_H := 4
const TRAVEL_V := 3

@export var vertical := false

var _origin := Vector2.ZERO


func _ready() -> void:
	add_to_group("platform")
	_origin = position
	if vertical:
		$Sprite.scale.x = 0.5
		($Shape.shape as RectangleShape2D).size.x = 96.0
	_start_cycle()


func _start_cycle() -> void:
	var travel := TILE * (TRAVEL_V if vertical else TRAVEL_H)
	var offset := Vector2(0, -travel) if vertical else Vector2(travel, 0)
	var duration := travel / SPEED

	var tween := create_tween().set_loops()
	tween.tween_property(self, "position", _origin + offset, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _origin, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
