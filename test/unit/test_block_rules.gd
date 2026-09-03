extends GutTest

func test_question_block_gives_coin_once() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_QUESTION, false, false), "coin")
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_QUESTION, false, true), "spent")

func test_milk_block_gives_milk() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_MILK_BRICK, false, false), "milk")

func test_milk_block_only_gives_once() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_MILK_BRICK, true, true), "spent")

func test_breakable_bounces_for_small_breaks_for_big() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BREAKABLE, false, false), "bounce")
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BREAKABLE, true, false), "broke")

func test_plain_brick_always_bounces() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BRICK, true, false), "bounce")

func test_blocks_that_become_nodes() -> void:
	assert_true(BlockRules.needs_node(TileGlossary.KIND_QUESTION))
	assert_true(BlockRules.needs_node(TileGlossary.KIND_MILK_BRICK))
	assert_true(BlockRules.needs_node(TileGlossary.KIND_BREAKABLE))
	assert_false(BlockRules.needs_node(TileGlossary.KIND_GROUND))
	assert_false(BlockRules.needs_node(TileGlossary.KIND_BRICK))

func test_spent_block_shows_used_texture() -> void:
	assert_eq(BlockRules.spent_column(TileGlossary.KIND_QUESTION),
		TileGlossary.atlas_column(TileGlossary.KIND_USED_BRICK))
	assert_eq(BlockRules.spent_column(TileGlossary.KIND_BREAKABLE),
		TileGlossary.atlas_column(TileGlossary.KIND_BREAKABLE))
