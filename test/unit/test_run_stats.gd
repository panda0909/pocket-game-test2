extends GutTest

var r: RunStats

func before_each() -> void:
	r = RunStats.new(10)

func test_starts_with_lives_and_time() -> void:
	assert_eq(r.lives, RunStats.START_LIVES)
	assert_almost_eq(r.time_left, 10.0, 0.001)
	assert_eq(r.score, 0)
	assert_eq(r.coins, 0)

func test_coin_adds_coin_and_score() -> void:
	r.add_coin()
	assert_eq(r.coins, 1)
	assert_eq(r.score, RunStats.COIN_SCORE)

func test_stomp_adds_score_only() -> void:
	r.add_stomp()
	assert_eq(r.score, RunStats.STOMP_SCORE)
	assert_eq(r.coins, 0)

func test_milk_bonus_adds_score() -> void:
	r.add_milk_bonus()
	assert_eq(r.score, RunStats.MILK_BONUS_SCORE)

func test_spend_coin_requires_a_coin() -> void:
	assert_false(r.spend_coin())
	r.add_coin()
	assert_true(r.spend_coin())
	assert_eq(r.coins, 0)

func test_spending_does_not_refund_score() -> void:
	r.add_coin()
	r.spend_coin()
	assert_eq(r.score, RunStats.COIN_SCORE)

func test_lose_life_reports_remaining() -> void:
	assert_true(r.lose_life())
	assert_eq(r.lives, RunStats.START_LIVES - 1)
	r.lose_life()
	assert_false(r.lose_life())
	assert_eq(r.lives, 0)

func test_lives_never_go_negative() -> void:
	for i in 10:
		r.lose_life()
	assert_eq(r.lives, 0)

func test_tick_reports_timeout() -> void:
	assert_false(r.tick(9.0))
	assert_true(r.tick(2.0))
	assert_almost_eq(r.time_left, 0.0, 0.001)

func test_finish_converts_time_to_score() -> void:
	r.tick(4.0)
	r.finish()
	assert_eq(r.score, 6 * RunStats.TIME_BONUS_PER_SECOND)
	assert_almost_eq(r.time_left, 0.0, 0.001)

func test_restart_level_resets_time_but_keeps_score() -> void:
	r.add_coin()
	r.tick(5.0)
	r.restart_level()
	assert_almost_eq(r.time_left, 10.0, 0.001)
	assert_eq(r.score, RunStats.COIN_SCORE)
	assert_eq(r.coins, 1, "彈藥不該因為死亡而歸零")

func test_seconds_left_rounds_up_for_display() -> void:
	r.tick(0.5)
	assert_eq(r.seconds_left(), 10)
	r.tick(0.6)
	assert_eq(r.seconds_left(), 9)
