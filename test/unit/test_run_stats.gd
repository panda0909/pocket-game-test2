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


# --- 金幣的取捨要真的成立 ---
# README 與 run_stats 的註解都把「金幣是分數也是彈藥」說成一個真的取捨，
# 但 add_coin 在撿到當下就記了 50 分、spend_coin 又不扣分，
# 於是最優解永遠是「撿到就丟」——分數已經入袋，留著只是佔位。

func test_spending_a_coin_gives_back_the_score_it_earned() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	var after_pickup := stats.score
	assert_true(stats.spend_coin())
	assert_eq(stats.score, after_pickup - RunStats.COIN_SCORE,
		"丟出去的金幣要把撿到時記的分數退掉，取捨才成立")
	assert_eq(stats.coins, 0)

func test_spending_never_pushes_score_below_zero() -> void:
	var stats := RunStats.new(300)
	stats.add_coin()
	stats.add_score(-40)
	stats.spend_coin()
	assert_gte(stats.score, 0, "分數不該被扣成負的")

func test_cannot_spend_without_coins() -> void:
	var stats := RunStats.new(300)
	var before := stats.score
	assert_false(stats.spend_coin())
	assert_eq(stats.score, before, "沒彈藥時不該動到分數")


# --- 加命 ---
# 原本全專案沒有任何增加 lives 的程式碼：15 個畫面的關卡配 3 條命、
# 沒有補命管道也沒有續關，三次失誤就從第 0 欄重來。

func test_score_milestone_grants_an_extra_life() -> void:
	var stats := RunStats.new(300)
	var before := stats.lives
	stats.add_score(RunStats.EXTRA_LIFE_SCORE)
	assert_eq(stats.lives, before + 1, "跨過里程碑要送一條命")

func test_extra_life_is_granted_once_per_milestone() -> void:
	var stats := RunStats.new(300)
	var before := stats.lives
	stats.add_score(RunStats.EXTRA_LIFE_SCORE)
	stats.add_score(10)
	assert_eq(stats.lives, before + 1, "同一個里程碑不該重複送")
	stats.add_score(RunStats.EXTRA_LIFE_SCORE)
	assert_eq(stats.lives, before + 2, "下一個里程碑要再送一條")

func test_add_life_is_capped() -> void:
	var stats := RunStats.new(300)
	for i in 50:
		stats.add_life()
	assert_lte(stats.lives, RunStats.MAX_LIVES, "生命數要有上限")
