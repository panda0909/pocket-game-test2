class_name Enemy
extends CharacterBody2D

## 三種敵人共用一個場景，行為由 kind 參數化。規則在 scripts/enemy_rules.gd。
##
## 原點在腳底（和玩家一致），所以放到「格子底邊中央」就剛好站在地上，
## 建構器不必為每種敵人記不同的偏移。

const DEATH_TIME := 0.22

## 用 @export 而不是自製的 setup()：賦值時機完全一樣（instantiate 之後、
## 進樹之前），但 @export 額外換來編輯器面板可調、.tscn 存得了預設值、
## 型別受檢。以前那套 setup() 只是把 @export 手工重寫一遍，代價是每個
## 生成點都要記得呼叫，忘了不會有任何警告。
@export var kind := EnemyRules.KIND_BEAR
## 掉到這個 y 以下就釋放。預設 INF 代表不自動釋放。
@export var despawn_y := INF

var half_height := 25.0

var _direction := -1
var _alive := true
var _diving := false
var _home_y := 0.0
var _float_phase := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Shape
@onready var _wall_ray: RayCast2D = $WallRay
@onready var _floor_ray: RayCast2D = $FloorRay


func is_alive() -> bool:
	return _alive


func _ready() -> void:
	add_to_group("enemy")
	_home_y = global_position.y

	var size := EnemyRules.body_size(kind)
	half_height = size.y * 0.5
	(_shape.shape as RectangleShape2D).size = size
	_shape.position.y = -half_height

	_sprite.texture = EnemyRules.texture(kind)
	_sprite.position.y = -half_height

	_apply_ray_direction()


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	# 掉出關卡下緣就收掉。少了這個，被打碎磚台的敵人會永遠下墜，
	# 節點不釋放、_physics_process 也一直在跑。
	if global_position.y > despawn_y:
		queue_free()
		return

	if kind == EnemyRules.KIND_ARROW:
		_process_arrow(delta)
	else:
		_process_patrol(delta)

	move_and_slide()


## 巡邏：前方撞牆或前方沒地板就回頭。這讓小熊不會從平台邊緣走下去，
## 玩家因此可以預測牠的路線，而不是每次都要重新觀察。
func _process_patrol(delta: float) -> void:
	velocity.y = EnemyRules.apply_gravity(velocity.y, delta)
	var speed := EnemyRules.patrol_speed(kind)

	if is_on_floor():
		var blocked := _wall_ray.is_colliding()
		var floor_ahead := _floor_ray.is_colliding()
		var next := EnemyRules.turn_direction(_direction, blocked, floor_ahead)
		if next != _direction:
			_direction = next
			_apply_ray_direction()

	velocity.x = _direction * speed
	_sprite.scale.x = absf(_sprite.scale.x) * (1.0 if _direction > 0 else -1.0)


## 跌停箭頭：懸空上下浮動，玩家進入水平範圍才俯衝。
## 「站在原地不動也不一定安全」這件事由它負責教。
func _process_arrow(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	if not _diving:
		var distance := absf(player.global_position.x - global_position.x)
		if distance < EnemyRules.ARROW_TRIGGER_RANGE:
			_diving = true
		else:
			_float_phase += delta * EnemyRules.ARROW_FLOAT_SPEED
			velocity = EnemyRules.float_velocity(_float_phase)
			return

	velocity = EnemyRules.dive_velocity(global_position,
		player.global_position - EnemyRules.ARROW_AIM_OFFSET)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


func _apply_ray_direction() -> void:
	_wall_ray.position = Vector2(0, -half_height)
	_wall_ray.target_position = Vector2(_direction * 30, 0)
	_floor_ray.position = Vector2(_direction * 24, -6)
	_floor_ray.target_position = Vector2(0, 30)


## 被踩死或被金幣打中。壓扁後淡出，讓玩家看得到自己的成果。
func die() -> void:
	if not _alive:
		return
	_alive = false
	# 退出群組，玩家的每幀輪詢才不會再找上這具屍體。光把碰撞層歸零不夠：
	# die() 常常是在 body_entered 訊號回呼裡被同步呼叫的，而 Godot 在物理
	# in/out 訊號期間會擋掉對碰撞層的直接賦值——屍體看起來死了，撞上去
	# 卻還是會扣血。
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector2.ZERO

	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale:y", 0.15, DEATH_TIME)
	tween.tween_property(_sprite, "modulate:a", 0.0, DEATH_TIME)
	tween.chain().tween_callback(queue_free)
