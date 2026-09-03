extends GutTest

func test_bear_and_arrow_are_stompable_spikeball_is_not() -> void:
	assert_true(EnemyRules.is_stompable(EnemyRules.KIND_BEAR))
	assert_true(EnemyRules.is_stompable(EnemyRules.KIND_ARROW))
	assert_false(EnemyRules.is_stompable(EnemyRules.KIND_SPIKEBALL))

func test_patrol_speeds_differ_by_kind() -> void:
	assert_almost_eq(EnemyRules.patrol_speed(EnemyRules.KIND_BEAR), 60.0, 0.01)
	assert_lt(EnemyRules.patrol_speed(EnemyRules.KIND_SPIKEBALL),
		EnemyRules.patrol_speed(EnemyRules.KIND_BEAR))

func test_arrow_does_not_patrol() -> void:
	assert_almost_eq(EnemyRules.patrol_speed(EnemyRules.KIND_ARROW), 0.0, 0.01)

func test_turns_when_blocked_ahead() -> void:
	assert_eq(EnemyRules.turn_direction(1, true, true), -1)

func test_turns_when_no_floor_ahead() -> void:
	assert_eq(EnemyRules.turn_direction(1, false, false), -1)

func test_keeps_direction_when_path_is_clear() -> void:
	assert_eq(EnemyRules.turn_direction(-1, false, true), -1)
	assert_eq(EnemyRules.turn_direction(1, false, true), 1)

func test_kind_from_entity_type() -> void:
	assert_eq(EnemyRules.kind_from_type("bear"), EnemyRules.KIND_BEAR)
	assert_eq(EnemyRules.kind_from_type("spikeball"), EnemyRules.KIND_SPIKEBALL)
	assert_eq(EnemyRules.kind_from_type("arrow"), EnemyRules.KIND_ARROW)
	assert_eq(EnemyRules.kind_from_type("coin"), -1)

func test_texture_path_for_each_kind() -> void:
	for kind in [EnemyRules.KIND_BEAR, EnemyRules.KIND_SPIKEBALL, EnemyRules.KIND_ARROW]:
		var path := EnemyRules.texture_path(kind)
		assert_true(ResourceLoader.exists(path), "缺少貼圖 %s" % path)

func test_stomp_requires_falling_and_being_above() -> void:
	# 玩家在敵人上方且正在下墜 -> 踩死
	assert_true(EnemyRules.is_stomp(120.0, -40.0, 30.0))
	# 玩家在下墜但位置在敵人腳下 -> 不算踩
	assert_false(EnemyRules.is_stomp(120.0, 40.0, 30.0))
	# 玩家在上方但正在上升（往上頂） -> 不算踩
	assert_false(EnemyRules.is_stomp(-120.0, -40.0, 30.0))

func test_score_differs_by_kind() -> void:
	assert_gt(EnemyRules.score(EnemyRules.KIND_ARROW),
		EnemyRules.score(EnemyRules.KIND_BEAR))
