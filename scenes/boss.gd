class_name Boss
extends CharacterBody2D

## 關底 Boss熊。在一段範圍內踱步，定期朝玩家丟跌停箭頭。
##
## 牠沿用小熊的造型放大加皇冠，而不是換一套寫實素材——關底該有壓迫感，
## 但壓迫感來自體型、皇冠與會反擊，不是來自畫風突然變了。

signal defeated
signal touched_player
signal spawned_projectile(position: Vector2, direction: Vector2)

## 移動、投擲與體型的數值全部在 BossRules，這裡只負責演出。
const BODY_SIZE := BossRules.BODY_SIZE

var hp := float(BossRules.MAX_HP)
var half_height := BODY_SIZE.y * 0.5
## Boss 也在 enemy 群組，所以玩家的踩踏判定會找上它；但它不是 Enemy，
## 踩到是扣血不是消失。
var kind := EnemyRules.KIND_BEAR

var _direction := -1
var _origin_x := 0.0
var _throw_timer := BossRules.THROW_INTERVAL
var _invincible_left := 0.0
var _alive := true

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	_origin_x = global_position.x
	(_shape.shape as RectangleShape2D).size = BODY_SIZE
	_shape.position.y = -half_height
	_sprite.position.y = -half_height


func is_alive() -> bool:
	return _alive


func _physics_process(delta: float) -> void:
	if not _alive:
		return

	_invincible_left = maxf(0.0, _invincible_left - delta)
	_sprite.modulate = Color(2, 2, 2) if _invincible_left > 0.0 else Color(1, 1, 1)

	velocity.y = minf(velocity.y + BossRules.GRAVITY * delta,
		EnemyRules.TERMINAL_FALL)
	_direction = BossRules.patrol_direction(global_position.x, _origin_x, _direction)
	velocity.x = _direction * BossRules.WALK_SPEED
	_sprite.scale.x = absf(_sprite.scale.x) * (1.0 if _direction > 0 else -1.0)
	move_and_slide()

	_throw_timer -= delta
	if _throw_timer <= 0.0:
		_throw_timer = BossRules.THROW_INTERVAL
		_throw_at_player()


func _throw_at_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var origin := global_position + Vector2(0, -half_height * 1.4)
	var target: Vector2 = players[0].global_position - BossRules.AIM_OFFSET
	spawned_projectile.emit(origin,
		BossRules.aim_velocity(origin, target, 1.0).normalized())


## 被踩。回傳是否真的吃到傷害（無敵中回 false，讓玩家還是會彈開但不扣血）。
func take_stomp() -> bool:
	return _damage(BossRules.apply_stomp(hp))


func take_shot() -> bool:
	return _damage(BossRules.apply_shot(hp))


func _damage(new_hp: float) -> bool:
	if not _alive or _invincible_left > 0.0:
		return false
	hp = new_hp
	_invincible_left = BossRules.HIT_INVINCIBLE_TIME
	var tween := create_tween()
	tween.tween_property(_sprite, "scale:y", _sprite.scale.y * 0.8, 0.08)
	tween.tween_property(_sprite, "scale:y", _sprite.scale.y, 0.14)
	if BossRules.is_dead(hp):
		_die()
	return true


func _die() -> void:
	_alive = false
	remove_from_group("enemy")
	# 只能延後改。_die 是在物理 in/out 訊號裡被同步呼叫的，直接賦值會被擋掉；
	# 底下那行直接賦值是舊寫法的殘留，正是會出問題的那一行。
	set_deferred("collision_layer", 0)
	velocity = Vector2.ZERO
	defeated.emit()
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale:y", 0.1, 0.4)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(_sprite, "rotation", 0.8, 0.4)
	tween.chain().tween_callback(queue_free)
