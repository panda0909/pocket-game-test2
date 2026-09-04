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
## 接觸框比身體往下多伸出的距離，讓腳底剛碰到敵人的那一幀就偵測得到。
const TOUCH_FOOT_MARGIN := 8.0
## 衝刺時的前傾角度與收放速度（弧度）。
const SPRINT_LEAN := 0.09
const LEAN_SPEED := 0.7

## 跑步時的身體起伏。頻率隨速度變化，站著不動時完全靜止。
const RUN_BOB_HEIGHT := 5.0
const RUN_CYCLE_SPEED := 11.0
const IDLE_BREATH := 0.03
const IDLE_CYCLE_SPEED := 3.9

var state := PlayerState.new()
var control_enabled := true
var character_index := Roster.DEFAULT_INDEX

var _timers := PlayerPhysics.new_timers()
var _facing := 1
var _cycle := 0.0
var _impulse_scale := Vector2.ONE
var _was_on_floor := true
## 上一幀腳底的位置。踩踏判定要用它，用當幀位置會被幀間位移跳過去。
var _previous_feet_y := 0.0
var _standing_pipe := ""
var _active_texture_path := ""

@onready var _sprite: Sprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _camera: Camera2D = $Camera


## 換主角貼圖。碰撞箱與物理參數三隻共用，所以這裡只動 texture——
## 這就是「純換皮」的全部內容，也是關卡幾何驗收不必重跑三遍的原因。
func set_character(index: int) -> void:
	character_index = Roster.clamp_index(index)
	if _sprite != null:
		_refresh_sprite_texture(false)


func _ready() -> void:
	add_to_group("player")
	set_character(character_index)
	$TouchBox.area_entered.connect(_on_area_entered)
	_apply_size()


func _physics_process(delta: float) -> void:
	var previous_feet_y := global_position.y
	var input := _read_input()
	var result := PlayerPhysics.step(velocity, input, is_on_floor(), delta, _timers)
	velocity = result["velocity"]
	_timers = result["timers"]

	if result["jumped"]:
		_punch_scale(Vector2(0.82, 1.22), 0.15)

	move_and_slide()
	_previous_feet_y = previous_feet_y

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
		return {"dir": 0.0, "jump_pressed": false, "jump_held": false, "sprint": false}
	return {
		"dir": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		# Shift 一鍵兩用：按住是衝刺，按下的那一幀才丟金幣（見下方 throw）。
		# 衝刺不需要變大，不然小牛全程只能慢走。
		"sprint": Input.is_action_pressed("throw"),
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
		_refresh_sprite_texture(false)
		_punch_scale(Vector2(1.35, 0.65), 0.25)
	elif outcome == "died":
		died.emit()
	return outcome


func grow() -> String:
	var outcome := state.collect_milk()
	if outcome == "grew":
		_apply_size()
		_refresh_sprite_texture(false)
		_punch_scale(Vector2(0.7, 1.35), 0.28)
	return outcome


func respawn_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_timers = PlayerPhysics.new_timers()
	_previous_feet_y = pos.y
	state.reset()
	control_enabled = true
	_impulse_scale = Vector2.ONE
	_refresh_sprite_texture(false)
	_apply_size()
	# 重生要瞬間切鏡，不然相機會從死亡地點慢慢滑回檢查點，
	# 玩家有一秒鐘不知道自己在哪。
	_camera.offset.x = _facing * CAMERA_LOOKAHEAD
	_camera.reset_smoothing()


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

	# 接觸框要一路蓋到腳底、再往下多留一點。原本它比身體矮 14%，下緣停在
	# 腳底上方 8 px，於是要等玩家陷進敵人體內才開始偵測到重疊——踩踏的
	# 判定窗因此被壓到只剩幾個像素。
	var touch := Vector2(size.x * 0.85, size.y + TOUCH_FOOT_MARGIN * 2.0)
	($TouchBox/TouchShape.shape as RectangleShape2D).size = touch
	$TouchBox/TouchShape.position.y = -size.y * 0.5 + TOUCH_FOOT_MARGIN


func _punch_scale(target: Vector2, duration: float) -> void:
	_impulse_scale = target
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "_impulse_scale", Vector2.ONE, duration)


func _update_visual(delta: float) -> void:
	if not is_zero_approx(velocity.x):
		_facing = signi(int(velocity.x))

	# 分母用衝刺速度，否則衝刺時比值會超過 1，跑步循環與彈跳幅度都算爆。
	var speed_ratio := minf(absf(velocity.x) / PlayerPhysics.SPRINT_SPEED, 1.0)
	var cycle_scale := Vector2.ONE
	var bob := 0.0
	var walk_frame := 0
	var walking := false

	if is_on_floor() and speed_ratio > 0.05:
		walking = true
		_cycle += delta * RUN_CYCLE_SPEED * maxf(speed_ratio, 0.35)
		var wave := sin(_cycle)
		bob = -absf(wave) * RUN_BOB_HEIGHT * speed_ratio
		cycle_scale = Vector2(1.0 + 0.06 * wave, 1.0 - 0.06 * wave)
		walk_frame = int(floor(_cycle / PI)) % 2
	elif is_on_floor():
		_cycle += delta * IDLE_CYCLE_SPEED
		var breath := (sin(_cycle) + 1.0) * 0.5
		cycle_scale = Vector2(1.0 - IDLE_BREATH * breath * 0.5,
			1.0 + IDLE_BREATH * breath)
	else:
		# 上升時拉長、下墜時微拉長，讓空中姿態不是一顆僵硬的球
		cycle_scale = Vector2(0.94, 1.06)

	var base := BASE_SPRITE_SCALE * state.body_scale()
	_refresh_sprite_texture(walking and walk_frame == 1)
	_sprite.scale = Vector2(
		base * _impulse_scale.x * cycle_scale.x * _facing,
		base * _impulse_scale.y * cycle_scale.y)
	_sprite.position.y = bob

	# 衝刺時整個身體往前傾。這是「我在衝」的唯一視覺提示——
	# 光靠位移變快，玩家在捲動的背景前面分辨不出來。
	var lean := 0.0
	if absf(velocity.x) > PlayerPhysics.MAX_RUN_SPEED + 10.0:
		lean = SPRINT_LEAN * _facing
	_sprite.rotation = move_toward(_sprite.rotation, lean, LEAN_SPEED * delta)
	_sprite.modulate.a = 0.35 if state.is_invincible() and int(_cycle * 24.0) % 2 == 0 else 1.0

	_camera.offset.x = move_toward(_camera.offset.x, _facing * CAMERA_LOOKAHEAD,
		240.0 * delta)


func _refresh_sprite_texture(walking: bool) -> void:
	if _sprite == null:
		return
	var path := Roster.texture_path(character_index)
	if walking:
		path = Roster.walk_texture_path(character_index)
	elif state.is_big():
		path = Roster.big_texture_path(character_index)
	if path == _active_texture_path:
		return
	_sprite.texture = load(path)
	_active_texture_path = path


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
		# 原點在腳底，所以頭頂 = 原點往上兩個半高
		var half: float = body.half_height
		var enemy_top: float = body.global_position.y - half * 2.0
		var stompable: bool = body.is_in_group("boss") \
			or EnemyRules.is_stompable(body.kind)
		if not (stompable
				and EnemyRules.is_stomp(velocity.y, _previous_feet_y, enemy_top)):
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
