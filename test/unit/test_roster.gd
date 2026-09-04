extends GutTest

## 角色名冊。三隻是純換皮——碰撞箱完全相同，所以關卡幾何的驗收不受影響。

func test_has_three_characters() -> void:
	assert_eq(Roster.COUNT, 3)

func test_every_character_has_a_name() -> void:
	for i in Roster.COUNT:
		assert_false(Roster.name_of(i).is_empty(), "第 %d 隻沒有名字" % i)

func test_names_are_distinct() -> void:
	var seen: Dictionary = {}
	for i in Roster.COUNT:
		var name := Roster.name_of(i)
		assert_false(seen.has(name), "名字重複：%s" % name)
		seen[name] = true

## 和 EnemyRules 的貼圖測試同一個道理：路徑寫錯要在測試裡就爆，
## 不是等玩家看到一隻透明的主角。
func test_every_texture_exists() -> void:
	for i in Roster.COUNT:
		var path := Roster.texture_path(i)
		assert_true(ResourceLoader.exists(path), "缺少貼圖 %s" % path)
		assert_true(ResourceLoader.exists(Roster.walk_texture_path(i)),
			"缺少走路貼圖 %s" % Roster.walk_texture_path(i))
		assert_true(ResourceLoader.exists(Roster.big_texture_path(i)),
			"缺少變身貼圖 %s" % Roster.big_texture_path(i))

func test_cycle_moves_forward_and_wraps() -> void:
	assert_eq(Roster.cycle(0, 1), 1)
	assert_eq(Roster.cycle(Roster.COUNT - 1, 1), 0)

func test_cycle_moves_backward_and_wraps() -> void:
	assert_eq(Roster.cycle(1, -1), 0)
	assert_eq(Roster.cycle(0, -1), Roster.COUNT - 1)

func test_cycle_with_zero_step_stays() -> void:
	assert_eq(Roster.cycle(2, 0), 2)

func test_out_of_range_index_is_clamped_to_a_valid_one() -> void:
	# 存檔或參數壞掉時不該讓主角變透明
	assert_true(ResourceLoader.exists(Roster.texture_path(-1)))
	assert_true(ResourceLoader.exists(Roster.texture_path(99)))
	assert_false(Roster.name_of(99).is_empty())

func test_default_is_the_bull() -> void:
	assert_eq(Roster.DEFAULT_INDEX, 0)
	assert_string_contains(Roster.texture_path(Roster.DEFAULT_INDEX), "red_bull")


# --- 角色差異 ---
# 三隻原本是純換皮：選角是玩家開始前的第一個決策點，但這個決策在機制上
# 是空的。現在給的差異全部是「一樣或更寬鬆」——跳躍高度與走路速度不動，
# 所以關卡的幾何驗收仍然只要跑一組數值。

func test_every_character_has_traits() -> void:
	for i in Roster.COUNT:
		var t := Roster.traits(i)
		assert_true(t.has("sprint_speed"), "%d 缺 sprint_speed" % i)
		assert_true(t.has("coyote_time"), "%d 缺 coyote_time" % i)
		assert_true(t.has("start_coins"), "%d 缺 start_coins" % i)
		assert_false(str(t.get("blurb", "")).is_empty(), "%d 缺一句說明" % i)

func test_traits_fall_back_for_bad_index() -> void:
	assert_eq(Roster.traits(-5), Roster.traits(Roster.DEFAULT_INDEX))
	assert_eq(Roster.traits(99), Roster.traits(Roster.DEFAULT_INDEX))

## 關鍵約束：沒有任何一隻比基準難玩。
## 差異只能往「一樣或更寬鬆」的方向走，否則同一張關卡對某隻角色
## 就可能有跳不上去、跨不過去的地方，而關卡測試只驗了一組數值。
func test_no_character_is_worse_than_the_baseline() -> void:
	for i in Roster.COUNT:
		var t := Roster.traits(i)
		assert_gte(float(t["sprint_speed"]), PlayerPhysics.SPRINT_SPEED,
			"%s 的衝刺速度比基準慢，關卡可能有跨不過去的坑" % Roster.name_of(i))
		assert_gte(float(t["coyote_time"]), PlayerPhysics.COYOTE_TIME,
			"%s 的土狼時間比基準短" % Roster.name_of(i))
		assert_gte(int(t["start_coins"]), 0)

## 至少要有一隻真的和別人不同，不然這層差異等於沒做。
func test_characters_are_actually_different() -> void:
	var seen: Dictionary = {}
	for i in Roster.COUNT:
		var t := Roster.traits(i)
		seen["%s|%s|%s" % [t["sprint_speed"], t["coyote_time"], t["start_coins"]]] = true
	assert_gt(seen.size(), 1, "三隻的數值一模一樣，選角這個決策仍然是空的")
