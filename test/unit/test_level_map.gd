extends GutTest

const HEAD := "name: 測試關\ntime: 120\npipe1: room_a\n---\n"

func test_parses_terrain_and_size() -> void:
	var m := LevelMap.parse(HEAD + "  S F\n#####")
	assert_true(m.is_valid(), str(m.errors))
	assert_eq(m.width, 5)
	assert_eq(m.height, 2)
	assert_eq(m.terrain_at(Vector2i(0, 1)), TileGlossary.KIND_GROUND)
	assert_eq(m.terrain_at(Vector2i(0, 0)), TileGlossary.KIND_EMPTY)

func test_reads_metadata() -> void:
	var m := LevelMap.parse(HEAD + "S F\n###")
	assert_eq(m.level_name, "測試關")
	assert_eq(m.time_limit, 120)

func test_time_defaults_to_300() -> void:
	var m := LevelMap.parse("name: 無時間\n---\nS F\n###")
	assert_eq(m.time_limit, 300)

func test_spawn_cell_recorded_and_not_an_entity() -> void:
	var m := LevelMap.parse(HEAD + " S F\n####")
	assert_eq(m.spawn, Vector2i(1, 0))
	for e in m.entities:
		assert_ne(e["type"], "spawn")

func test_entities_collected_with_cells() -> void:
	var m := LevelMap.parse(HEAD + "S o b F\n#######")
	var types: Array = []
	for e in m.entities:
		types.append(e["type"])
	assert_true(types.has("coin"))
	assert_true(types.has("bear"))
	assert_true(types.has("goal"))

func test_entity_cell_terrain_is_empty() -> void:
	var m := LevelMap.parse(HEAD + "S b F\n#####")
	assert_eq(m.terrain_at(Vector2i(2, 0)), TileGlossary.KIND_EMPTY)

func test_requires_exactly_one_spawn() -> void:
	assert_false(LevelMap.parse(HEAD + "F\n#").is_valid())
	assert_false(LevelMap.parse(HEAD + "S S F\n#####").is_valid())

func test_requires_goal_or_boss() -> void:
	assert_false(LevelMap.parse(HEAD + "S\n#").is_valid())
	assert_true(LevelMap.parse(HEAD + "S K\n###").is_valid())

func test_unknown_char_reports_position() -> void:
	var m := LevelMap.parse(HEAD + "S @ F\n#####")
	assert_false(m.is_valid())
	assert_string_contains(m.errors[0], "@")

func test_pipe_requires_matching_meta() -> void:
	var ok := LevelMap.parse(HEAD + "S 1 F\n#####")
	assert_true(ok.is_valid(), str(ok.errors))
	var bad := LevelMap.parse(HEAD + "S 2 F\n#####")
	assert_false(bad.is_valid())

func test_pipe_entity_carries_target() -> void:
	var m := LevelMap.parse(HEAD + "S 1 F\n#####")
	var found := false
	for e in m.entities:
		if e["type"] == "pipe":
			found = true
			assert_eq(e["params"]["target"], "room_a")
			assert_eq(e["params"]["index"], 1)
	assert_true(found, "應該有一個水管實體")

func test_short_rows_padded_with_empty() -> void:
	var m := LevelMap.parse(HEAD + "S\n####F\n#####")
	assert_eq(m.width, 5)
	assert_eq(m.terrain_at(Vector2i(4, 0)), TileGlossary.KIND_EMPTY)

func test_out_of_bounds_terrain_is_empty() -> void:
	var m := LevelMap.parse(HEAD + "S F\n###")
	assert_eq(m.terrain_at(Vector2i(-1, 0)), TileGlossary.KIND_EMPTY)
	assert_eq(m.terrain_at(Vector2i(99, 99)), TileGlossary.KIND_EMPTY)

func test_room_levels_skip_spawn_and_goal_validation() -> void:
	var m := LevelMap.parse("room: true\npipe1: __return__\n---\n# 1 #\n#####")
	assert_true(m.is_valid(), str(m.errors))
	assert_true(m.is_room)

func test_pipe_room_file_parses() -> void:
	var m := LevelMap.load_from("res://levels/level1_pipe_a.txt")
	assert_true(m.is_valid(), str(m.errors))
	assert_true(m.is_room)
	var pipes := 0
	for e in m.entities:
		if e["type"] == "pipe":
			pipes += 1
			assert_eq(e["params"]["target"], "__return__")
	assert_eq(pipes, 1, "暗房要有一個回程水管")

# --- 中繼資料與檔案層級的壞輸入 ---
# 這幾條原本完全沒有測試：所有壞輸入測試都集中在地圖區，
# 中繼資料區的四條錯誤路徑一條都沒守。

func test_missing_file_is_invalid_with_message() -> void:
	var m := LevelMap.load_from("res://levels/不存在的關卡.txt")
	assert_false(m.is_valid())
	assert_string_contains(m.errors[0], "找不到關卡檔")

func test_time_rejects_non_integer_and_falls_back() -> void:
	var m := LevelMap.parse("time: abc\n---\nS F\n###")
	assert_false(m.is_valid())
	assert_string_contains(m.errors[0], "time")
	assert_eq(m.time_limit, LevelMap.DEFAULT_TIME)

func test_time_rejects_zero() -> void:
	# time: 0 會讓 RunStats 在第一幀就回報時間到，玩家一進關卡就死。
	var m := LevelMap.parse("time: 0\n---\nS F\n###")
	assert_false(m.is_valid())
	assert_eq(m.time_limit, LevelMap.DEFAULT_TIME)

func test_time_rejects_negative() -> void:
	var m := LevelMap.parse("time: -30\n---\nS F\n###")
	assert_false(m.is_valid())
	assert_eq(m.time_limit, LevelMap.DEFAULT_TIME)

func test_empty_text_reports_empty_level() -> void:
	var m := LevelMap.parse("")
	assert_false(m.is_valid())
	assert_string_contains(str(m.errors), "關卡是空的")

func test_crlf_line_endings_parse_the_same() -> void:
	# Windows 編輯器存檔就會踩到。
	var unix := LevelMap.parse("time: 90\n---\nS F\n###")
	var dos := LevelMap.parse("time: 90\r\n---\r\nS F\r\n###")
	assert_true(dos.is_valid(), str(dos.errors))
	assert_eq(dos.height, unix.height)
	assert_eq(dos.width, unix.width)
	assert_eq(dos.time_limit, 90)

func test_separator_is_required() -> void:
	# 「#」在中繼資料區是註解、在地圖區是地面磚，兩者無法並存。
	# 強制要有分界線，才不會有人寫了註解卻得到一整排地面。
	var m := LevelMap.parse("S F\n###")
	assert_false(m.is_valid())
	assert_string_contains(str(m.errors), "---")

func test_unknown_char_errors_are_capped() -> void:
	# 關卡檔損毀成亂碼時，每格一則錯誤會產生數千則字串，
	# Main 再逐則 push_error，在 Web 版會明顯凍結。
	var junk := ""
	for i in 200:
		junk += "@"
	var m := LevelMap.parse("---\n" + junk)
	assert_false(m.is_valid())
	assert_lt(m.errors.size(), 30, "錯誤訊息應該有上限，不該每格一則")


# --- 牛奶落點 ---
# 這兩段運算原本寫在 main.gd 上，是純 LevelMap 資料的計算卻掛在 Node2D 上，
# 於是完全無法被單元測試覆蓋——牛奶掉錯格只能靠跑整個場景才發現。

func test_ground_surface_below_finds_the_first_solid_row() -> void:
	var m := LevelMap.parse(HEAD + "S ? F\n     \n#####")
	assert_eq(m.ground_surface_row_below(Vector2i(2, 0)), 2)

func test_ground_surface_below_falls_back_to_level_bottom() -> void:
	# 磚塊架在坑上：整欄都沒有地面，落點就是關卡底部，
	# 玩家至少看得到牛奶掉下去，而不是卡在半空中。
	var m := LevelMap.parse(HEAD + "S ? F\n#   #\n#   #")
	assert_eq(m.ground_surface_row_below(Vector2i(2, 0)), m.height)

func test_drift_goes_left_when_only_the_right_is_blocked() -> void:
	var m := LevelMap.parse(HEAD + "S ?#F\n#####")
	assert_eq(m.drift_direction(Vector2i(2, 0)), -1)

func test_drift_goes_right_when_both_sides_are_open() -> void:
	var m := LevelMap.parse(HEAD + "S ? F\n#####")
	assert_eq(m.drift_direction(Vector2i(2, 0)), 1)

func test_drift_goes_right_when_only_the_left_is_blocked() -> void:
	var m := LevelMap.parse(HEAD + "S#? F\n#####")
	assert_eq(m.drift_direction(Vector2i(2, 0)), 1)

func test_drift_is_safe_at_the_level_edge() -> void:
	var m := LevelMap.parse(HEAD + "S ?F\n####")
	var d := m.drift_direction(Vector2i(0, 0))
	assert_true(d == 1 or d == -1, "邊緣不該回傳 0")
