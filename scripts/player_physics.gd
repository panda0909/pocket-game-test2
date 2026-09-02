class_name PlayerPhysics
extends RefCounted

## 玩家的速度積分。純函式，不碰場景樹，因此手感的每一條都能單元測試。
##
## 馬利歐手感不是玄學，是幾條具體規則的疊加：
##   1. 下降重力比上升重力大 —— 跳躍弧線才俐落，不會像在月球上飄
##   2. 放開跳鍵就砍掉剩餘上升速度 —— 這就是「可變跳躍高度」
##   3. 土狼時間 —— 踏出平台邊緣後還有 0.1 秒能跳，玩家不會覺得自己被判太嚴
##   4. 跳躍緩衝 —— 落地前 0.12 秒內按的跳，落地瞬間自動生效
##   5. 空中加速比地面弱，空中不煞停 —— 跳出去就得為那個方向負責
##
## 3 和 4 是「明明按了卻沒跳」這種挫敗感的解藥，玩家永遠不會注意到它們存在，
## 但拿掉之後整個遊戲會變得很難操作。

const MAX_RUN_SPEED := 280.0
const GROUND_ACCEL := 1600.0
const GROUND_BRAKE := 2000.0
const AIR_ACCEL := 1100.0
const JUMP_VELOCITY := -720.0
const GRAVITY_RISE := 1100.0
const GRAVITY_FALL := 1800.0
const JUMP_CUT_VELOCITY := -420.0
const TERMINAL_FALL := 900.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const STOMP_BOUNCE := -480.0
const STOMP_BOUNCE_HELD := -640.0


## 推進一幀。
##
## input:  {"dir": float（-1/0/1）, "jump_pressed": bool, "jump_held": bool}
## timers: {"coyote": float, "buffer": float}
## 回傳：  {"velocity": Vector2, "timers": Dictionary, "jumped": bool}
static func step(velocity: Vector2, input: Dictionary, on_floor: bool,
		delta: float, timers: Dictionary) -> Dictionary:
	var dir: float = input.get("dir", 0.0)
	var jump_pressed: bool = input.get("jump_pressed", false)
	var jump_held: bool = input.get("jump_held", false)

	var coyote: float = timers.get("coyote", 0.0)
	var buffer: float = timers.get("buffer", 0.0)

	coyote = COYOTE_TIME if on_floor else coyote - delta
	buffer = JUMP_BUFFER if jump_pressed else buffer - delta

	var new_velocity := velocity

	if not is_zero_approx(dir):
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		new_velocity.x = move_toward(new_velocity.x, dir * MAX_RUN_SPEED, accel * delta)
	elif on_floor:
		new_velocity.x = move_toward(new_velocity.x, 0.0, GROUND_BRAKE * delta)

	var jumped := false
	if buffer > 0.0 and coyote > 0.0:
		new_velocity.y = JUMP_VELOCITY
		coyote = 0.0
		buffer = 0.0
		jumped = true

	var gravity := GRAVITY_RISE if new_velocity.y < 0.0 else GRAVITY_FALL
	new_velocity.y += gravity * delta

	# 只砍「還在快速上升」的情況。已經接近頂點時砍它會讓跳躍看起來卡一下。
	if not jump_held and new_velocity.y < JUMP_CUT_VELOCITY:
		new_velocity.y = JUMP_CUT_VELOCITY

	new_velocity.y = minf(new_velocity.y, TERMINAL_FALL)

	return {
		"velocity": new_velocity,
		"timers": {"coyote": coyote, "buffer": buffer},
		"jumped": jumped,
	}


static func stomp_velocity(jump_held: bool) -> float:
	return STOMP_BOUNCE_HELD if jump_held else STOMP_BOUNCE


## 理論最大跳躍高度，供關卡排版與測試對照設計值。
static func jump_height() -> float:
	return (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY_RISE)


static func new_timers() -> Dictionary:
	return {"coyote": 0.0, "buffer": 0.0}
