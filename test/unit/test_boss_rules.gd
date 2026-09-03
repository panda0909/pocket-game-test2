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
