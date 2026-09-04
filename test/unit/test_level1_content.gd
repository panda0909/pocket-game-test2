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
			assert_gt(e["cell"].x, m.width - SCREEN_CELLS)

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
##
## 每一站得住的列都要掃，不是只掃最底一列。level1 的第 12、13 列內容完全相同，
## 舊版只掃 height-1 等於只驗了地面層——高處磚台中間開一個六格的洞，
## 測試全綠但玩家卡死。
func test_no_gap_is_wider_than_four_cells_on_any_walkable_row() -> void:
	var rows_checked := 0
	for y in m.height:
		if not _row_has_footing(y):
			continue
		rows_checked += 1
		var run := 0
		var worst := 0
		var worst_x := -1
		var first := _first_solid_x(y)
		var last := _last_solid_x(y)
		for x in range(first, last + 1):
			if TileGlossary.is_solid(m.terrain_at(Vector2i(x, y))):
				run = 0
				continue
			run += 1
			if run > worst:
				worst = run
				worst_x = x
		assert_lte(worst, 4,
			"第 %d 列第 %d 格附近的坑有 %d 格寬，跳不過去" % [y, worst_x, worst])
	assert_gt(rows_checked, 1, "應該掃到不只一列")

## 這一列算不算「連續地面」。
##
## 坑寬的規則只對走得完的地面成立。第 8、9 列那種分散的磚台之間本來就是空的，
## 那不是坑，是兩座島——拿坑寬去要求它們只會製造誤報。判準是：實心格要覆蓋
## 首尾之間一半以上。
func _row_has_footing(y: int) -> bool:
	var first := -1
	var last := -1
	var count := 0
	for x in m.width:
		if not TileGlossary.is_solid(m.terrain_at(Vector2i(x, y))):
			continue
		if first < 0:
			first = x
		last = x
		count += 1
	if first < 0 or last - first < 10:
		return false
	return float(count) / float(last - first + 1) >= 0.5

func _first_solid_x(y: int) -> int:
	for x in m.width:
		if TileGlossary.is_solid(m.terrain_at(Vector2i(x, y))):
			return x
	return 0

func _last_solid_x(y: int) -> int:
	for i in m.width:
		var x := m.width - 1 - i
		if TileGlossary.is_solid(m.terrain_at(Vector2i(x, y))):
			return x
	return m.width - 1

func test_has_at_least_two_checkpoints() -> void:
	var count := 0
	for e in m.entities:
		if e["type"] == "checkpoint":
			count += 1
	assert_gte(count, 2, "十五個畫面寬的關卡至少要兩個檢查點")


## 每一個畫面都要有東西。
##
## 一個 1280 px 畫面剛好 20 格。整整一個畫面除了平地什麼都沒有的話，
## 玩家在那一段只是按住右鍵等待。
const SCREEN_CELLS := 20

func test_no_screen_is_completely_empty() -> void:
	var interest: Array[int] = []
	interest.resize(m.width)
	interest.fill(0)
	for e in m.entities:
		interest[e["cell"].x] += 1
	for y in m.height:
		for x in m.width:
			var kind := m.terrain_at(Vector2i(x, y))
			if kind in [TileGlossary.KIND_QUESTION, TileGlossary.KIND_MILK_BRICK,
					TileGlossary.KIND_BREAKABLE, TileGlossary.KIND_SPIKE,
					TileGlossary.KIND_BRICK]:
				interest[x] += 1

	var screens := int(ceil(float(m.width) / float(SCREEN_CELLS)))
	for s in screens:
		var x0 := s * SCREEN_CELLS
		var x1 := mini(x0 + SCREEN_CELLS, m.width)
		var total := 0
		for x in range(x0, x1):
			total += interest[x]
		assert_gt(total, 0,
			"第 %d 個畫面（第 %d–%d 格）除了平地什麼都沒有" % [s, x0, x1 - 1])

## 打倒 Boss 之後不該再走一整個畫面才到終點，那會把關底的高潮洩掉。
func test_goal_follows_the_boss_closely() -> void:
	var boss_x := -1
	var goal_x := -1
	for e in m.entities:
		if e["type"] == "boss":
			boss_x = e["cell"].x
		elif e["type"] == "goal":
			goal_x = e["cell"].x
	assert_lte(goal_x - boss_x, SCREEN_CELLS,
		"Boss 在第 %d 格、旗竿在第 %d 格，中間隔了 %d 格空地"
			% [boss_x, goal_x, goal_x - boss_x])
