extends GutTest

const D := 1.0 / 60.0

func _ipt(dir: float, pressed := false, held := false) -> Dictionary:
	return {"dir": dir, "jump_pressed": pressed, "jump_held": held}

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
