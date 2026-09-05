class_name CoinShot
extends Area2D

## 大牛丟出去的金幣。碰到敵人就打死它，碰到地形或飛出關卡就消失。
##
## 它會受重力影響並在地上彈跳兩下——直線飛的話玩家可以站在原地掃平整條路，
## 拋物線逼他要選位置和時機。

signal hit_enemy(kind: int)
signal hit_boss

const SPEED := 460.0
const GRAVITY := 900.0
const BOUNCE := -420.0
const MAX_BOUNCES := 2
const LIFETIME := 3.0

var _velocity := Vector2.ZERO
var _bounces := 0
var _age := 0.0

@onready var _ground_ray: RayCast2D = $GroundRay


func launch(direction: int) -> void:
	_velocity = Vector2(direction * SPEED, -160.0)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	rotation += delta * 12.0 * signf(_velocity.x)

	if _ground_ray.is_colliding() and _velocity.y > 0.0:
		_bounces += 1
		if _bounces > MAX_BOUNCES:
			queue_free()
			return
		position.y = _ground_ray.get_collision_point().y - 8.0
		_velocity.y = BOUNCE


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boss"):
		body.take_shot()
		hit_boss.emit()
		queue_free()
	elif body.is_in_group("enemy"):
		var enemy := body as Enemy
		var kind := enemy.kind
		enemy.die()
		hit_enemy.emit(kind)
		queue_free()
	else:
		# 其他任何實心物體（地形、問號磚、水管、移動平台）都當牆看。
		# 以前只認 TileMapLayer，於是金幣會直接穿過問號磚與水管飛走。
		# 撞到牆（不是地板）就消失，不然它會卡在牆裡一直彈。
		if absf(_velocity.y) < 60.0:
			queue_free()
