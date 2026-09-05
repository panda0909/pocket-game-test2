extends GutTest

## 收集率與無傷紀錄。
##
## 硬派玩家的第三輪需要「一個新的失敗條件」。原本只有一個最高分數字，
## 而且那個數字被無限刷分毀掉過——修好之後它仍然只有一條軸。
## 收集率與無傷各提供一條，而資料本來就都在手上。

func _stats() -> RunStats:
	var stats := RunStats.new(150)
	stats.set_targets(10, 4, 2)
	return stats

func test_targets_start_at_zero_progress() -> void:
	assert_eq(_stats().collect_percent(), 0)

func test_collecting_everything_is_a_hundred_percent() -> void:
	var stats := _stats()
	for i in 10:
		stats.add_coin()
	for i in 4:
		stats.count_enemy_defeated()
	for i in 2:
		stats.count_milk_found()
	assert_eq(stats.collect_percent(), 100)

## 三類各佔三分之一，不是「加起來除以總數」——否則金幣多的關卡
## 會讓敵人與牛奶的權重被稀釋到看不見。
func test_each_category_weighs_the_same() -> void:
	var coins_only := _stats()
	for i in 10:
		coins_only.add_coin()
	var enemies_only := _stats()
	for i in 4:
		enemies_only.count_enemy_defeated()
	assert_almost_eq(float(coins_only.collect_percent()), 33.0, 1.0)
	assert_almost_eq(float(enemies_only.collect_percent()), 33.0, 1.0)

func test_progress_never_exceeds_a_hundred() -> void:
	var stats := _stats()
	for i in 50:
		stats.add_coin()
		stats.count_enemy_defeated()
		stats.count_milk_found()
	assert_eq(stats.collect_percent(), 100)

## 沒有目標時不該除以零。
func test_no_targets_reports_zero_not_a_crash() -> void:
	var stats := RunStats.new(150)
	stats.add_coin()
	assert_eq(stats.collect_percent(), 0)

## 花掉的金幣仍然算「撿過」——收集率問的是走過多少內容，不是手上還剩多少。
func test_spending_a_coin_does_not_undo_collection() -> void:
	var stats := _stats()
	for i in 10:
		stats.add_coin()
	var before := stats.collect_percent()
	stats.spend_coin()
	stats.spend_coin()
	assert_eq(stats.collect_percent(), before)
	assert_eq(stats.found["coin"], 10)
	assert_eq(stats.coins, 8, "手上的彈藥要真的少掉兩枚")

# --- 無傷 ---

func test_a_fresh_run_is_flawless() -> void:
	assert_true(_stats().flawless)

func test_taking_damage_ends_flawless() -> void:
	var stats := _stats()
	stats.count_damage_taken()
	assert_false(stats.flawless)

## 無傷是一整局的事，死一次重生也不會洗掉。
func test_flawless_is_not_reset_by_respawning() -> void:
	var stats := _stats()
	stats.count_damage_taken()
	stats.restart_level()
	assert_false(stats.flawless)
