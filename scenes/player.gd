class_name Player
extends CharacterBody2D

## 玩家節點。它只做三件事：讀輸入、把數字交給 PlayerPhysics、把結果畫出來。
## 所有手感規則都在 scripts/player_physics.gd 裡，那邊有完整單元測試。
##
## 動畫沒有逐格圖，全是擠壓拉伸。紅牛是圓球造型，squash-stretch 在它身上
## 特別討喜，而且換成 AnimatedSprite2D 時遊戲邏輯一行都不用動。

signal died
signal enemy_stomped(kind: int)
signal enemy_touched
signal coin_collected
signal milk_collected
signal goal_reached
signal hazard_touched
signal throw_requested(direction: int, origin: Vector2)
signal checkpoint_reached(position: Vector2)
signal pipe_entered(target: String)

## 紅牛原圖 131×180，縮到小牛高 128 px（兩格）。
const SPRITE_SOURCE_HEIGHT := 180.0
const SMALL_HEIGHT := 128.0
const BASE_SPRITE_SCALE := SMALL_HEIGHT / SPRITE_SOURCE_HEIGHT

const SMALL_BODY := Vector2(56, 120)
const CAMERA_LOOKAHEAD := 120.0

## 跑步時的身體起伏。頻率隨速度變化，站著不動時完全靜止。
const RUN_BOB_HEIGHT := 5.0
const RUN_CYCLE_SPEED := 11.0
const IDLE_BREATH := 0.03
const IDLE_CYCLE_SPEED := 3.9

var state := PlayerState.new()
var control_enabled := true

var _timers := PlayerPhysics.new_timers()
var _facing := 1
var _cycle := 0.0
var _impulse_scale := Vector2.ONE
var _was_on_floor := true
var _standing_pipe := ""

@onready var _sprite: Sprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("player")
	$TouchBox.area_entered.connect(_on_area_entered)
	_apply_size()


func _physics_process(delta: float) -> void:
	var input := _read_input()
	var result := PlayerPhysics.step(velocity, input, is_on_floor(), delta, _timers)
	velocity = result["velocity"]
	_timers = result["timers"]

	if result["jumped"]:
		_punch_scale(Vector2(0.82, 1.22), 0.15)

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_punch_scale(Vector2(1.25, 0.78), 0.18)
	_was_on_floor = is_on_floor()

	_resolve_ceiling_hits()
	_resolve_enemy_contacts()
	state.advance(delta)
	_update_visual(delta)

	if control_enabled and Input.is_action_just_pressed("throw") and state.can_throw():
		throw_requested.emit(_facing, global_position + Vector2(_facing * 34, -70))

	if control_enabled and Input.is_action_just_pressed("duck") and not _standing_pipe.is_empty():
		pipe_entered.emit(_standing_pipe)


func _read_input() -> Dictionary:
	if not control_enabled:
		return {"dir": 0.0, "jump_pressed": false, "jump_held": false}
	return {
		"dir": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
	}


## 踩到敵人後的回彈。由 Main 或敵人呼叫，帶入「跳鍵是否按住」——
## 按住能連踩爬高，這是馬利歐最爽的一招。
func apply_stomp(jump_held: bool) -> void:
	velocity.y = PlayerPhysics.stomp_velocity(jump_held)
	_punch_scale(Vector2(1.3, 0.7), 0.2)


## 受傷。回傳 PlayerState 的結果字串，讓 Main 決定是扣命還是只變小。
func take_hit() -> String:
	var outcome := state.take_hit()
	if outcome == "shrank":
		_apply_size()
		_punch_scale(Vector2(1.35, 0.65), 0.25)
	elif outcome == "died":
		died.emit()
	return outcome


func grow() -> String:
	var outcome := state.collect_milk()
	if outcome == "grew":
		_apply_size()
		_punch_scale(Vector2(0.7, 1.35), 0.28)
	return outcome


func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_timers = PlayerPhysics.new_timers()
	state.reset()
	control_enabled = true
	_impulse_scale = Vector2.ONE
	_apply_size()


## 相機邊界。關卡建構完才知道關卡多大，所以由 Main 呼叫。
func set_camera_bounds(level_size: Vector2) -> void:
	# 關卡比視窗矮或窄時硬夾邊界，Godot 會兩邊都滿足不了而露出關卡外的空白。
	# 這時把邊界撐到至少一個視窗大，讓相機有地方站。
	var viewport := Vector2(get_viewport_rect().size)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(maxf(level_size.x, viewport.x))
	_camera.limit_bottom = int(maxf(level_size.y, viewport.y))
	_camera.reset_smoothing()


func set_standing_pipe(target: String) -> void:
	_standing_pipe = target


## 體型改變時同步碰撞箱。碰撞箱底邊固定在原點，所以變大是往上長，
## 不會因為變大而卡進地板裡。
func _apply_size() -> void:
	var scale_factor := state.body_scale()
	var size := SMALL_BODY * scale_factor
	var shape := _body_shape.shape as RectangleShape2D
	shape.size = size
	_body_shape.position.y = -size.y * 0.5
	($TouchBox/TouchShape.shape as RectangleShape2D).size = size * 0.86
	$TouchBox/TouchShape.position.y = -size.y * 0.5


func _punch_scale(target: Vector2, duration: float) -> void:
	_impulse_scale = target
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "_impulse_scale", Vector2.ONE, duration)


func _update_visual(delta: float) -> void:
	if not is_zero_approx(velocity.x):
		_facing = signi(int(velocity.x))

	var speed_ratio := absf(velocity.x) / PlayerPhysics.MAX_RUN_SPEED
	var cycle_scale := Vector2.ONE
	var bob := 0.0

	if is_on_floor() and speed_ratio > 0.05:
		_cycle += delta * RUN_CYCLE_SPEED * maxf(speed_ratio, 0.35)
		var wave := sin(_cycle)
		bob = -absf(wave) * RUN_BOB_HEIGHT * speed_ratio
		cycle_scale = Vector2(1.0 + 0.06 * wave, 1.0 - 0.06 * wave)
	elif is_on_floor():
		_cycle += delta * IDLE_CYCLE_SPEED
		var breath := (sin(_cycle) + 1.0) * 0.5
		cycle_scale = Vector2(1.0 - IDLE_BREATH * breath * 0.5,
			1.0 + IDLE_BREATH * breath)
	else:
		# 上升時拉長、下墜時微拉長，讓空中姿態不是一顆僵硬的球
		cycle_scale = Vector2(0.94, 1.06)

	var base := BASE_SPRITE_SCALE * state.body_scale()
	_sprite.scale = Vector2(
		base * _impulse_scale.x * cycle_scale.x * _facing,
		base * _impulse_scale.y * cycle_scale.y)
	_sprite.position.y = bob
	_sprite.modulate.a = 0.35 if state.is_invincible() and int(_cycle * 24.0) % 2 == 0 else 1.0

	_camera.offset.x = move_toward(_camera.offset.x, _facing * CAMERA_LOOKAHEAD,
		240.0 * delta)


## 頂磚塊。撞到天花板時碰撞法線是朝下的（從表面指向玩家）。
func _resolve_ceiling_hits() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.7:
			continue
		var collider := collision.get_collider()
		if collider != null and collider.has_method("hit_from_below"):
			collider.hit_from_below(state.is_big())


## 每幀輪詢重疊的敵人，而不是只靠 body_entered 訊號。
## 訊號只在「進入」的那一幀發，玩家站在敵人身上不動時就再也不會觸發；
## 輪詢才能處理持續接觸。
func _resolve_enemy_contacts() -> void:
	if state.is_invincible():
		return
	for body in $TouchBox.get_overlapping_bodies():
		if not body.is_in_group("enemy"):
			continue
		var half: float = body.half_height
		var relative_y: float = global_position.y - (body.global_position.y - half)
		var stompable: bool = body.is_in_group("boss") \
			or EnemyRules.is_stompable(body.kind)
		if not (stompable and EnemyRules.is_stomp(velocity.y, relative_y, half)):
			enemy_touched.emit()
			return

		apply_stomp(Input.is_action_pressed("jump"))
		if body.has_method("take_stomp"):
			# Boss 踩了是扣血不是消失，回彈照給——不然玩家會黏在牠頭上。
			body.take_stomp()
		else:
			var kind: int = body.kind
			body.die()
			enemy_stomped.emit(kind)
		return


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("coin"):
		area.queue_free()
		coin_collected.emit()
	elif area.is_in_group("powerup"):
		area.queue_free()
		milk_collected.emit()
	elif area.is_in_group("goal"):
		goal_reached.emit()
	elif area.is_in_group("hazard"):
		hazard_touched.emit()
	elif area.is_in_group("checkpoint"):
		checkpoint_reached.emit(area.global_position)
