extends GutTest

## 最高分紀錄的合併規則。
##
## 存檔原本完全不存在：全專案唯一的 FileAccess 用法是唯讀的關卡載入。
## 而結束畫面的分享按鈕預設玩家想刷分——重開瀏覽器分數歸零，刷分沒有對照組。

func test_new_save_starts_empty() -> void:
	var save := SaveData.new()
	assert_eq(save.best_score, 0)
	assert_eq(save.best_coins, 0)
	assert_false(save.cleared)

func test_first_run_becomes_the_record() -> void:
	var save := SaveData.new()
	assert_true(save.record_run(1200, 8, false, 42))
	assert_eq(save.best_score, 1200)
	assert_eq(save.best_coins, 8)

func test_better_score_replaces_the_record() -> void:
	var save := SaveData.new()
	save.record_run(1200, 8, false, 42)
	assert_true(save.record_run(3000, 4, false, 10))
	assert_eq(save.best_score, 3000)

func test_worse_score_does_not_replace_the_record() -> void:
	var save := SaveData.new()
	save.record_run(3000, 4, false, 10)
	assert_false(save.record_run(1200, 8, false, 42))
	assert_eq(save.best_score, 3000)

## 金幣與分數各自留各自的最佳，一局分數低但金幣多也該被記下來。
func test_best_coins_is_tracked_independently() -> void:
	var save := SaveData.new()
	save.record_run(3000, 4, false, 10)
	save.record_run(1200, 8, false, 42)
	assert_eq(save.best_score, 3000)
	assert_eq(save.best_coins, 8)

## 通關過就永遠是通關過，之後打不完也不會被清掉。
func test_cleared_is_sticky() -> void:
	var save := SaveData.new()
	save.record_run(3000, 4, true, 120)
	save.record_run(100, 0, false, 0)
	assert_true(save.cleared)

## 通關時間要留最短的；沒通關的那局不該污染紀錄。
func test_best_time_keeps_the_fastest_clear() -> void:
	var save := SaveData.new()
	save.record_run(3000, 4, true, 90)
	save.record_run(3200, 4, true, 140)
	assert_eq(save.best_time_left, 140, "剩餘秒數越多代表越快")
	save.record_run(9999, 9, false, 200)
	assert_eq(save.best_time_left, 140, "沒通關的局不該動到通關紀錄")

func test_round_trips_through_a_dictionary() -> void:
	var save := SaveData.new()
	save.record_run(4321, 7, true, 88)
	var restored := SaveData.from_dict(save.to_dict())
	assert_eq(restored.best_score, 4321)
	assert_eq(restored.best_coins, 7)
	assert_true(restored.cleared)
	assert_eq(restored.best_time_left, 88)

## 存檔檔案被改壞或欄位缺漏時要退回預設，不能崩。
func test_broken_dictionary_falls_back_to_defaults() -> void:
	var save := SaveData.from_dict({"best_score": "不是數字"})
	assert_eq(save.best_score, 0)
	var empty := SaveData.from_dict({})
	assert_eq(empty.best_score, 0)
	assert_false(empty.cleared)

# --- 收集率與無傷的紀錄 ---

func test_records_best_collect_percent() -> void:
	var save := SaveData.new()
	save.record_run(1000, 5, false, 0, 40, false)
	assert_eq(save.best_collect_pct, 40)
	save.record_run(9999, 9, true, 60, 25, false)
	assert_eq(save.best_collect_pct, 40, "收集率各留各的最佳，不會被高分那局蓋掉")
	save.record_run(100, 1, false, 0, 88, false)
	assert_eq(save.best_collect_pct, 88)

## 無傷只有真的通關才算。半路無傷死掉不是成就。
func test_flawless_requires_clearing() -> void:
	var save := SaveData.new()
	save.record_run(5000, 5, false, 0, 50, true)
	assert_false(save.flawless_clear, "沒通關的無傷不算")
	save.record_run(5000, 5, true, 30, 50, true)
	assert_true(save.flawless_clear)

func test_flawless_is_sticky() -> void:
	var save := SaveData.new()
	save.record_run(5000, 5, true, 30, 50, true)
	save.record_run(9999, 9, true, 60, 90, false)
	assert_true(save.flawless_clear, "拿過就永遠是拿過")

func test_new_fields_round_trip() -> void:
	var save := SaveData.new()
	save.record_run(4321, 7, true, 88, 73, true)
	var restored := SaveData.from_dict(save.to_dict())
	assert_eq(restored.best_collect_pct, 73)
	assert_true(restored.flawless_clear)

func test_broken_new_fields_fall_back() -> void:
	var save := SaveData.from_dict({"best_collect_pct": "壞掉", "flawless_clear": 7})
	assert_eq(save.best_collect_pct, 0)
	assert_false(save.flawless_clear)
