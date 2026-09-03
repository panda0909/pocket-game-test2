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
