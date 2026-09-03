extends GutTest

const D := 1.0 / 60.0

func _ipt(dir: float, pressed := false, held := false) -> Dictionary:
	return {"dir": dir, "jump_pressed": pressed, "jump_held": held}


func _sprint(dir: float, pressed := false, held := false) -> Dictionary:
	var input := _ipt(dir, pressed, held)
	input["sprint"] = true
	return input


## 跑到速度不再變化為止，回傳最終水平速度。
func _run_until_stable(input: Dictionary, frames := 180) -> float:
	var v := Vector2.ZERO
	var t := _timers(PlayerPhysics.COYOTE_TIME)
	for i in frames:
		var r := PlayerPhysics.step(v, input, true, D, t)
		v = r["velocity"]
		t = r["timers"]
	return v.x

func _timers(coyote := 0.0, buffer := 0.0) -> Dictionary:
	return {"coyote": coyote, "buffer": buffer}

func test_accelerates_toward_max_speed() -> void:
	var v := Vector2.ZERO
	var t := _timers(PlayerPhysics.COYOTE_TIME)
	for i in 120:
		var r := PlayerPhysics.step(v, _ipt(1.0), true, D, t)
		v = r["velocity"]
		t = r["timers"]
	assert_almost_eq(v.x, PlayerPhysics.MAX_RUN_SPEED, 1.0)

func test_never_exceeds_max_speed() -> void:
	var r := PlayerPhysics.step(Vector2(PlayerPhysics.MAX_RUN_SPEED, 0),
		_ipt(1.0), true, D, _timers(0.1))
	assert_almost_eq(r["velocity"].x, PlayerPhysics.MAX_RUN_SPEED, 0.01)

func test_brakes_to_zero_without_ipt() -> void:
	var v := Vector2(PlayerPhysics.MAX_RUN_SPEED, 0)
	var t := _timers(0.1)
	for i in 60:
		var r := PlayerPhysics.step(v, _ipt(0.0), true, D, t)
		v = r["velocity"]
		t = r["timers"]
	assert_almost_eq(v.x, 0.0, 0.01)

func test_air_accel_is_weaker_than_ground() -> void:
	var air := PlayerPhysics.step(Vector2.ZERO, _ipt(1.0), false, D, _timers())
	var ground := PlayerPhysics.step(Vector2.ZERO, _ipt(1.0), true, D, _timers(0.1))
	assert_lt(air["velocity"].x, ground["velocity"].x)

func test_no_braking_in_air() -> void:
	var r := PlayerPhysics.step(Vector2(200, 0), _ipt(0.0), false, D, _timers())
	assert_almost_eq(r["velocity"].x, 200.0, 0.01)

func test_jump_from_floor_sets_jump_velocity() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _ipt(0.0, true, true), true, D, _timers())
	assert_true(r["jumped"])
	assert_lt(r["velocity"].y, PlayerPhysics.JUMP_VELOCITY * 0.5)

func test_jump_height_matches_design() -> void:
	assert_almost_eq(PlayerPhysics.jump_height(), 236.0, 4.0)

func test_jump_clears_three_tiles() -> void:
	assert_gt(PlayerPhysics.jump_height(), 3.0 * 64.0)

func test_fall_gravity_stronger_than_rise() -> void:
	var rise := PlayerPhysics.step(Vector2(0, -300), _ipt(0.0, false, true), false, D, _timers())
	var fall := PlayerPhysics.step(Vector2(0, 300), _ipt(0.0), false, D, _timers())
	var rise_delta: float = rise["velocity"].y - (-300.0)
	var fall_delta: float = fall["velocity"].y - 300.0
	assert_lt(rise_delta, fall_delta)

func test_releasing_jump_cuts_rise() -> void:
	var r := PlayerPhysics.step(Vector2(0, -700), _ipt(0.0, false, false), false, D, _timers())
	assert_almost_eq(r["velocity"].y, PlayerPhysics.JUMP_CUT_VELOCITY, 0.01)

func test_holding_jump_does_not_cut_rise() -> void:
	var r := PlayerPhysics.step(Vector2(0, -700), _ipt(0.0, false, true), false, D, _timers())
	assert_lt(r["velocity"].y, PlayerPhysics.JUMP_CUT_VELOCITY)

func test_release_does_not_speed_up_a_slow_rise() -> void:
	var r := PlayerPhysics.step(Vector2(0, -100), _ipt(0.0, false, false), false, D, _timers())
	assert_gt(r["velocity"].y, PlayerPhysics.JUMP_CUT_VELOCITY)

func test_coyote_time_allows_jump_just_after_leaving_ground() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _ipt(0.0, true, true), false, D, _timers(0.05))
	assert_true(r["jumped"])

func test_coyote_time_expires() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _ipt(0.0, true, true), false, D, _timers(0.0))
	assert_false(r["jumped"])

func test_jump_buffer_fires_on_landing() -> void:
	var mid := PlayerPhysics.step(Vector2(0, 300), _ipt(0.0, true, true), false, D, _timers())
	assert_false(mid["jumped"])
	var landed := PlayerPhysics.step(mid["velocity"], _ipt(0.0, false, true), true, D,
		mid["timers"])
	assert_true(landed["jumped"])

func test_jump_buffer_expires_before_landing() -> void:
	var t := _timers(0.0, PlayerPhysics.JUMP_BUFFER)
	var v := Vector2(0, 300)
	for i in 20:
		var r := PlayerPhysics.step(v, _ipt(0.0, false, true), false, D, t)
		v = r["velocity"]
		t = r["timers"]
	var landed := PlayerPhysics.step(v, _ipt(0.0, false, true), true, D, t)
	assert_false(landed["jumped"], "0.33 秒前按的跳躍不該還留著")

func test_cannot_double_jump_in_one_press() -> void:
	var first := PlayerPhysics.step(Vector2.ZERO, _ipt(0.0, true, true), true, D, _timers())
	assert_true(first["jumped"])
	var second := PlayerPhysics.step(first["velocity"], _ipt(0.0, false, true), false, D,
		first["timers"])
	assert_false(second["jumped"])

func test_terminal_fall_speed_capped() -> void:
	var r := PlayerPhysics.step(Vector2(0, 5000), _ipt(0.0), false, D, _timers())
	assert_almost_eq(r["velocity"].y, PlayerPhysics.TERMINAL_FALL, 0.01)

func test_stomp_bounce_higher_when_jump_held() -> void:
	assert_lt(PlayerPhysics.stomp_velocity(true), PlayerPhysics.stomp_velocity(false))


## --- 衝刺 ---

func test_sprint_is_faster_than_walking() -> void:
	assert_gt(PlayerPhysics.SPRINT_SPEED, PlayerPhysics.MAX_RUN_SPEED)

func test_holding_sprint_reaches_sprint_speed() -> void:
	assert_almost_eq(_run_until_stable(_sprint(1.0)),
		PlayerPhysics.SPRINT_SPEED, 1.0)

func test_without_sprint_caps_at_walk_speed() -> void:
	assert_almost_eq(_run_until_stable(_ipt(1.0)),
		PlayerPhysics.MAX_RUN_SPEED, 1.0)

## 沒有 sprint 這個鍵的舊呼叫要當走路處理，現有的測試才不用全部改。
func test_missing_sprint_key_defaults_to_walking() -> void:
	var r := PlayerPhysics.step(Vector2(PlayerPhysics.MAX_RUN_SPEED, 0),
		{"dir": 1.0, "jump_pressed": false, "jump_held": false}, true, D, _timers(0.1))
	assert_almost_eq(r["velocity"].x, PlayerPhysics.MAX_RUN_SPEED, 0.01)

## 放開 Shift 要自然減速回走路速度，不是瞬間掉一截。
func test_releasing_sprint_decelerates_instead_of_snapping() -> void:
	var v := Vector2(PlayerPhysics.SPRINT_SPEED, 0)
	var t := _timers(0.1)
	var first := PlayerPhysics.step(v, _ipt(1.0), true, D, t)
	var after_one_frame: float = first["velocity"].x
	assert_lt(after_one_frame, PlayerPhysics.SPRINT_SPEED, "應該開始減速")
	assert_gt(after_one_frame, PlayerPhysics.MAX_RUN_SPEED,
		"一幀就掉到走路速度等於瞬間掉速")

	v = first["velocity"]
	t = first["timers"]
	for i in 60:
		var r := PlayerPhysics.step(v, _ipt(1.0), true, D, t)
		v = r["velocity"]
		t = r["timers"]
	assert_almost_eq(v.x, PlayerPhysics.MAX_RUN_SPEED, 1.0)

func test_sprint_works_in_both_directions() -> void:
	assert_almost_eq(_run_until_stable(_sprint(-1.0)),
		-PlayerPhysics.SPRINT_SPEED, 1.0)

## 關卡「所有坑不超過 4 格」那條約束是照走路速度算的。衝刺讓坑更好跳，
## 所以約束仍然成立——但如果有人把 SPRINT_SPEED 設得比走路慢，那條約束
## 就會靜靜失效。這條測試防的是那個。
func test_sprint_only_ever_lengthens_the_jump() -> void:
	assert_gte(PlayerPhysics.jump_distance(PlayerPhysics.SPRINT_SPEED),
		PlayerPhysics.jump_distance(PlayerPhysics.MAX_RUN_SPEED))

func test_walk_jump_still_clears_a_four_cell_gap() -> void:
	assert_gt(PlayerPhysics.jump_distance(PlayerPhysics.MAX_RUN_SPEED),
		4.0 * 64.0)
