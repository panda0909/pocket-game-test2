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

func test_missing_separator_treats_all_lines_as_map() -> void:
	var m := LevelMap.parse("S F\n###")
	assert_eq(m.height, 2)
	assert_eq(m.time_limit, 300)
	assert_true(m.is_valid(), str(m.errors))

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
