extends GutTest

func test_ground_is_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind("#"), TileGlossary.KIND_GROUND)

func test_space_is_empty_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind(" "), TileGlossary.KIND_EMPTY)

func test_coin_is_entity_not_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind("o"), -1)
	assert_eq(TileGlossary.entity_type("o"), "coin")

func test_unknown_char_is_not_known() -> void:
	assert_false(TileGlossary.is_known("@"))
	assert_true(TileGlossary.is_known("#"))

func test_spike_is_not_solid() -> void:
	assert_false(TileGlossary.is_solid(TileGlossary.KIND_SPIKE))
	assert_true(TileGlossary.is_solid(TileGlossary.KIND_GROUND))

func test_pipe_digits_map_to_index() -> void:
	assert_eq(TileGlossary.pipe_index("1"), 1)
	assert_eq(TileGlossary.pipe_index("9"), 9)
	assert_eq(TileGlossary.pipe_index("#"), 0)
	assert_eq(TileGlossary.entity_type("3"), "pipe")

func test_atlas_column_is_stable_for_each_kind() -> void:
	assert_eq(TileGlossary.atlas_column(TileGlossary.KIND_GROUND), 0)
	assert_eq(TileGlossary.atlas_column(TileGlossary.KIND_USED_BRICK), 3)
	assert_eq(TileGlossary.atlas_column(TileGlossary.KIND_EMPTY), -1)
