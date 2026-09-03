extends GutTest

func _big_state() -> PlayerState:
	var s := PlayerState.new()
	s.collect_milk()
	return s

func test_small_player_cannot_throw() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	assert_false(ThrowRules.can_fire(PlayerState.new(), stats))

func test_big_player_with_coin_can_throw() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	assert_true(ThrowRules.can_fire(_big_state(), stats))

func test_big_player_without_coin_cannot_throw() -> void:
	assert_false(ThrowRules.can_fire(_big_state(), RunStats.new(300)))

func test_fire_spends_exactly_one_coin() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	stats.add_coin()
	assert_true(ThrowRules.fire(_big_state(), stats))
	assert_eq(stats.coins, 1)

func test_fire_fails_and_spends_nothing_when_small() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	assert_false(ThrowRules.fire(PlayerState.new(), stats))
	assert_eq(stats.coins, 1, "不能丟的時候不該扣彈藥")

func test_fire_fails_when_out_of_ammo() -> void:
	var stats := RunStats.new(300)
	assert_false(ThrowRules.fire(_big_state(), stats))
	assert_eq(stats.coins, 0)
