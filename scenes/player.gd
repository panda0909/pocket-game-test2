class_name Player
extends CharacterBody2D

## 玩家節點。它只做三件事：讀輸入、把數字交給 PlayerPhysics、把結果畫出來。
## 所有手感規則都在 scripts/player_physics.gd 裡，那邊有完整單元測試。
##
## 動畫沒有逐格圖，全是擠壓拉伸。紅牛是圓球造型，squash-stretch 在它身上
## 特別討喜，而且換成 AnimatedSprite2D 時遊戲邏輯一行都不用動。

signal died
signal enemy_stomped(kind: int)
## 碰到會傷人的東西：敵人或地刺。以前是 enemy_touched 與 hazard_touched
## 兩個訊號，Main 兩個都接到同一個處理器、行為從頭到尾一模一樣——
## 多出來的那個只讓讀的人以為 Main 對兩者有不同處理。
signal damaged
signal coin_collected
signal milk_collected
signal goal_reached
signal throw_requested(direction: int, origin: Vector2)
## 按了丟金幣但條件不成立（還是小牛）。
##
## 以前這個情況連訊號都不發：沒有音效、沒有動畫、數字不動。新手的結論是
## 「這個鍵是壞的」，然後就再也沒按過——等他後來真的變大了，早就放棄了。
## 這不是「沒被發現」，是主動教玩家這個機制不存在。
signal throw_denied
signal checkpoint_reached(world_position: Vector2)
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
## 死亡時往上拋多高、轉多少、掉多深。
## 場景檔裡的碰撞層與遮罩。死亡表演會暫時關掉，復原時要放回這兩個值。
const PHYSICS_LAYER := 64
const PHYSICS_MASK := 1

const DEATH_TOSS_HEIGHT := 220.0
const DEATH_TOSS_TIME := 0.22
const DEATH_FALL_TIME := 0.42
const DEATH_SPIN := 2.4
const DEATH_FALL_HEIGHT := 900.0

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
## 無敵閃爍的相位。與 _cycle 分開，因為 _cycle 只在地面上走。
var _blink_phase := 0.0
var _impulse_scale := Vector2.ONE
var _was_on_floor := true
## 上一幀腳底的位置。踩踏判定要用它，用當幀位置會被幀間位移跳過去。
var _previous_feet_y := 0.0
var _standing_pipe := ""
## 剛拿回控制權的那一幀先忽略輸入。選角的確認鍵是在同一幀被 parse 的，
## 緊接著的物理步裡 Input.is_action_just_pressed("jump") 仍然為真——
## 玩家一開場就會無故跳一下。
var _input_grace_frames := 0
var _traits := Roster.traits(Roster.DEFAULT_INDEX)
var _death_tween: Tween = null
var _active_texture: Texture2D = null

@onready var _sprite: Sprite2D = $Sprite
@onready var _body_shape: CollisionShape2D = $BodyShape
@onready var _camera: Camera2D = $Camera
@onready var _touch_box: Area2D = $TouchBox
@onready var _touch_shape: CollisionShape2D = $TouchBox/TouchShape


## 換主角貼圖。碰撞箱與物理參數三隻共用，所以這裡只動 texture——
## 這就是「純換皮」的全部內容，也是關卡幾何驗收不必重跑三遍的原因。
func set_character(index: int) -> void:
	character_index = Roster.clamp_index(index)
	_traits = Roster.traits(character_index)
	if _sprite != null:
		_refresh_sprite_texture(false)


## 交還控制權。一律走這裡，不要直接寫 control_enabled = true。
func begin_control() -> void:
	control_enabled = true
	_input_grace_frames = 1


func accepts_input() -> bool:
	return control_enabled and _input_grace_frames <= 0


func _ready() -> void:
	add_to_group("player")
	set_character(character_index)
	_touch_box.area_entered.connect(_on_area_entered)
	_apply_size()


func _physics_process(delta: float) -> void:
	var previous_feet_y := global_position.y
	var input := _read_input()
	var result := PlayerPhysics.step(velocity, input, is_on_floor(), delta, _timers)
	velocity = result["velocity"]
	_timers = result["timers"]

	if result["jumped"]:
		_punch_scale(Vector2(0.82, 1.22), 0.15)
		Audio.play("jump")

	move_and_slide()
	_previous_feet_y = previous_feet_y

	if is_on_floor() and not _was_on_floor:
		_punch_scale(Vector2(1.25, 0.78), 0.18)
	_was_on_floor = is_on_floor()

	_resolve_ceiling_hits()
	_resolve_enemy_contacts()
	state.advance(delta)
	_update_visual(delta)

	if accepts_input() and Input.is_action_just_pressed("throw"):
		if state.can_throw():
			throw_requested.emit(_facing, global_position + Vector2(_facing * 34, -70))
		else:
			_punch_scale(Vector2(1.15, 0.88), 0.16)
			throw_denied.emit()

	if accepts_input() and Input.is_action_just_pressed("duck") \
			and not _standing_pipe.is_empty():
		Audio.play("pipe")
		pipe_entered.emit(_standing_pipe)

	_input_grace_frames = maxi(0, _input_grace_frames - 1)


func _read_input() -> Dictionary:
	if not accepts_input():
		return PlayerPhysics.new_input(0.0, false, false, false,
			_traits["sprint_speed"], _traits["coyote_time"])
	# 衝刺與丟金幣是兩個獨立的 action。以前 sprint 直接讀 throw，大牛每次
	# 起衝都會丟掉一枚金幣，而金幣是有限彈藥（Boss 要六發）——習慣按住
	# Shift 跑的玩家會在抵達關底前把彈藥灑光。
	# 衝刺不需要變大，不然小牛全程只能慢走。
	return PlayerPhysics.new_input(
		Input.get_axis("move_left", "move_right"),
		Input.is_action_just_pressed("jump"),
		Input.is_action_pressed("jump"),
		Input.is_action_pressed("sprint"),
		_traits["sprint_speed"],
		_traits["coyote_time"])


## 踩到敵人後的回彈。由 Main 或敵人呼叫，帶入「跳鍵是否按住」——
## 按住能連踩爬高，這是馬利歐最爽的一招。
func apply_stomp(jump_held: bool) -> void:
	velocity.y = PlayerPhysics.stomp_velocity(jump_held)
	_punch_scale(Vector2(1.3, 0.7), 0.2)
	Audio.play("stomp")


## 受傷。變小在這裡處理完，死亡則另外發 died 訊號讓 Main 走死亡流程。
##
## 回傳值只給測試與除錯看——Main 不讀它。以前註解寫「讓 Main 決定是扣命
## 還是只變小」，但 Main 從來沒有讀過這個回傳值，兩者不符已經很久了。
func take_hit() -> String:
	var outcome := state.take_hit()
	if outcome == PlayerState.SHRANK:
		Audio.play("hurt")
		_apply_size()
		_refresh_sprite_texture(false)
		_punch_scale(Vector2(1.35, 0.65), 0.25)
	elif outcome == PlayerState.DIED:
		died.emit()
	return outcome


## 死亡表演。以前死亡只是原地凍住 0.9 秒然後瞬移——沒有任何一幀告訴
## 玩家「你死了」，那段靜止很容易被誤讀成遊戲卡住。
##
## 關掉碰撞讓屍體直接穿過地板掉出畫面，是這類遊戲的慣例做法：
## 玩家看得到自己掉下去，死因與結果都清楚。
func play_death() -> void:
	control_enabled = false
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_physics_process(false)
	var top := position.y - DEATH_TOSS_HEIGHT
	_death_tween = create_tween()
	# 拋起、翻轉、墜落三段合計必須短於 Main 的 DEATH_PAUSE。超過的話重生
	# 之後 tween 還在寫 position，會把玩家再推回關卡外——那正是「一次死亡
	# 扣光三條命」的成因。revive() 另外會 kill 它，時間再怎麼調都不會重演。
	_death_tween.tween_property(self, "position:y", top, DEATH_TOSS_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_death_tween.parallel().tween_property(_sprite, "rotation", DEATH_SPIN,
		DEATH_TOSS_TIME + DEATH_FALL_TIME)
	_death_tween.tween_property(self, "position:y", top + DEATH_FALL_HEIGHT,
		DEATH_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 死亡表演之後把節點復原，重生才不會是一具旋轉的屍體。
func revive() -> void:
	# tween 一定要先停。它還活著的話會在重生之後繼續寫 position。
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	set_physics_process(true)
	set_deferred("collision_layer", PHYSICS_LAYER)
	set_deferred("collision_mask", PHYSICS_MASK)
	_sprite.rotation = 0.0


func grow() -> String:
	var outcome := state.collect_milk()
	if outcome == PlayerState.GREW:
		Audio.play("powerup")
		_apply_size()
		_refresh_sprite_texture(false)
		_punch_scale(Vector2(0.7, 1.35), 0.28)
	return outcome


## 換場：只搬位置，保留變身狀態與能力。
##
## 進水管暗房走的是這條。以前換場也呼叫 respawn_at，於是按 ↓ 的瞬間
## state.reset() 就把大牛打回小牛——玩家完全不知道自己為什麼縮水了。
func enter_level(pos: Vector2) -> void:
	_place_at(pos)


## 重生：換場再加上狀態重設（變回小牛、清掉無敵）。
func respawn_at(pos: Vector2) -> void:
	state.reset()
	_place_at(pos)


func _place_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_timers = PlayerPhysics.new_timers()
	_previous_feet_y = pos.y
	_impulse_scale = Vector2.ONE
	_standing_pipe = ""
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
	(_touch_shape.shape as RectangleShape2D).size = touch
	_touch_shape.position.y = -size.y * 0.5 + TOUCH_FOOT_MARGIN


func _punch_scale(target: Vector2, duration: float) -> void:
	_impulse_scale = target
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "_impulse_scale", Vector2.ONE, duration)


func _update_visual(delta: float) -> void:
	_facing = PlayerPhysics.facing_from_velocity(velocity.x, _facing)

	# 分母用衝刺速度，否則衝刺時比值會超過 1，跑步循環與彈跳幅度都算爆。
	var speed_ratio := minf(absf(velocity.x) / PlayerPhysics.SPRINT_SPEED, 1.0)
	var cycle_scale := Vector2.ONE
	var bob := 0.0
	var walk_frame := 0
	var walking := false

	# _cycle 每幀都要走。以前只在站在地面上時才遞增，於是空中受傷後
	# 無敵閃爍會凍結在單一透明度，玩家看不出自己還在無敵中，
	# 白白浪費那 1.2 秒的容錯。
	_blink_phase += delta

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
	_sprite.modulate.a = 0.35 if state.is_invincible() \
		and int(_blink_phase * 24.0) % 2 == 0 else 1.0

	_camera.offset.x = move_toward(_camera.offset.x, _facing * CAMERA_LOOKAHEAD,
		240.0 * delta)


func _refresh_sprite_texture(walking: bool) -> void:
	if _sprite == null:
		return
	var texture := Roster.texture(character_index)
	_sprite.flip_h = Roster.flip_h(character_index)
	if walking:
		texture = Roster.walk_texture(character_index)
	elif state.is_big():
		texture = Roster.big_texture(character_index)
	if texture == _active_texture:
		return
	_sprite.texture = texture
	_active_texture = texture


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
	for body in _touch_box.get_overlapping_bodies():
		if not body.is_in_group("enemy"):
			continue
		# 屍體在 0.22 秒的淡出期間還在場上，退群組是延後生效的，多擋一道。
		if body.has_method("is_alive") and not body.is_alive():
			continue
		# 原點在腳底，所以頭頂 = 原點往上兩個半高
		var half: float = body.half_height
		var enemy_top: float = body.global_position.y - half * 2.0
		var stompable: bool = body.is_in_group("boss") \
			or EnemyRules.is_stompable(body.kind)
		if not (stompable
				and EnemyRules.is_stomp(velocity.y, _previous_feet_y, enemy_top)):
			damaged.emit()
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
		Audio.play("coin")
		coin_collected.emit()
	elif area.is_in_group("powerup"):
		area.queue_free()
		milk_collected.emit()
	elif area.is_in_group("goal"):
		goal_reached.emit()
	elif area.is_in_group("hazard"):
		damaged.emit()
	elif area.is_in_group("checkpoint"):
		Audio.play("checkpoint")
		checkpoint_reached.emit(area.global_position)
