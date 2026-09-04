extends GutTest

func test_three_stomps_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 3:
		hp = BossRules.apply_stomp(hp)
	assert_true(BossRules.is_dead(hp))

func test_two_stomps_do_not_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	hp = BossRules.apply_stomp(hp)
	hp = BossRules.apply_stomp(hp)
	assert_false(BossRules.is_dead(hp))

func test_six_coin_shots_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 6:
		hp = BossRules.apply_shot(hp)
	assert_true(BossRules.is_dead(hp))

func test_five_coin_shots_do_not_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 5:
		hp = BossRules.apply_shot(hp)
	assert_false(BossRules.is_dead(hp))

func test_damage_never_goes_below_zero() -> void:
	var hp := 0.0
	assert_almost_eq(BossRules.apply_stomp(hp), 0.0, 0.001)

func test_mixed_damage_adds_up() -> void:
	var hp := float(BossRules.MAX_HP)
	hp = BossRules.apply_stomp(hp)
	hp = BossRules.apply_shot(hp)
	hp = BossRules.apply_stomp(hp)
	assert_false(BossRules.is_dead(hp), "踩兩次加一發還剩半格")
	hp = BossRules.apply_shot(hp)
	assert_true(BossRules.is_dead(hp))

func test_health_ratio_for_display() -> void:
	assert_almost_eq(BossRules.health_ratio(float(BossRules.MAX_HP)), 1.0, 0.001)
	assert_almost_eq(BossRules.health_ratio(0.0), 0.0, 0.001)


# --- 踱步與投擲：原本這些數值留在 boss.gd，沒有單一出處也沒有測試 ---

func test_turns_back_at_the_right_edge() -> void:
	var d := BossRules.patrol_direction(
		1000.0, 800.0 - BossRules.PATROL_HALF_WIDTH - 1.0, 1)
	assert_eq(d, -1)

func test_turns_back_at_the_left_edge() -> void:
	var d := BossRules.patrol_direction(
		0.0, BossRules.PATROL_HALF_WIDTH + 1.0, -1)
	assert_eq(d, 1)

func test_keeps_walking_inside_the_range() -> void:
	assert_eq(BossRules.patrol_direction(500.0, 500.0, -1), -1)
	assert_eq(BossRules.patrol_direction(500.0, 500.0, 1), 1)

func test_aim_is_never_a_zero_vector() -> void:
	var v := BossRules.aim_velocity(Vector2(200, 200), Vector2(200, 200), 300.0)
	assert_almost_eq(v.length(), 300.0, 0.01)
