extends GutTest

## 主關卡的內容驗收。關卡是資料，所以它的「規格」也能寫成測試——
## 排版排壞了（少了機制、教學段就丟高階危險物、跳不過去的坑）會在這裡被抓到。

var m: LevelMap

func before_all() -> void:
	m = LevelMap.load_from("res://levels/level1.txt")

func test_level1_parses_cleanly() -> void:
	assert_true(m.is_valid(), str(m.errors))

func test_level1_is_a_long_level() -> void:
	assert_gt(m.width, 260)
	assert_lt(m.width, 340)
	assert_eq(m.height, 14)

func test_level1_has_every_mechanic() -> void:
	var types: Dictionary = {}
	for e in m.entities:
		types[e["type"]] = int(types.get(e["type"], 0)) + 1
	for needed in ["coin", "bear", "spikeball", "arrow", "platform_h",
			"platform_v", "pipe", "checkpoint", "goal", "boss"]:
		assert_true(types.has(needed), "主關卡缺少 %s" % needed)

func test_level1_has_blocks_of_each_kind() -> void:
	var kinds: Dictionary = {}
	for y in m.height:
		for x in m.width:
			kinds[m.terrain_at(Vector2i(x, y))] = true
	for needed in [TileGlossary.KIND_GROUND, TileGlossary.KIND_BRICK,
			TileGlossary.KIND_QUESTION, TileGlossary.KIND_MILK_BRICK,
			TileGlossary.KIND_BREAKABLE, TileGlossary.KIND_SPIKE]:
		assert_true(kinds.has(needed), "主關卡缺少地形 %d" % needed)

func test_teaching_section_has_no_advanced_hazards() -> void:
	for e in m.entities:
		if e["type"] in ["spikeball", "arrow"]:
			assert_gt(e["cell"].x, 60, "前 60 格不該有進階危險物")

func test_spawn_is_near_the_start() -> void:
	assert_lt(m.spawn.x, 10)

func test_goal_is_at_the_end() -> void:
	for e in m.entities:
		if e["type"] == "goal":
			assert_gt(e["cell"].x, m.width - 12)

func test_boss_comes_before_the_goal() -> void:
	var boss_x := -1
	var goal_x := -1
	for e in m.entities:
		if e["type"] == "boss":
			boss_x = e["cell"].x
		elif e["type"] == "goal":
			goal_x = e["cell"].x
	assert_gt(boss_x, 0)
	assert_lt(boss_x, goal_x, "Boss 要在旗竿之前")

## 跳躍高度 236 px（3.7 格）、跑速 280 px/s，滿跳滯空約 1.17 秒，
## 水平最遠約 5.1 格。留一格安全邊際，任何坑都不該超過 4 格。
func test_no_gap_is_wider_than_four_cells() -> void:
	var floor_row := m.height - 1
	var run := 0
	var worst := 0
	var worst_x := -1
	for x in m.width:
		var solid := TileGlossary.is_solid(m.terrain_at(Vector2i(x, floor_row)))
		if solid:
			run = 0
			continue
		run += 1
		if run > worst:
			worst = run
			worst_x = x
	assert_lte(worst, 4, "第 %d 格附近的坑有 %d 格寬，跳不過去" % [worst_x, worst])

func test_has_at_least_two_checkpoints() -> void:
	var count := 0
	for e in m.entities:
		if e["type"] == "checkpoint":
			count += 1
	assert_gte(count, 2, "十五個畫面寬的關卡至少要兩個檢查點")
