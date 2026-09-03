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

## 踩踏判定看的是「上一幀腳底在不在敵人頭頂上方」，不是當幀的相對位置。
## 用當幀位置判會被幀間位移跳過去：玩家以 600 px/s 墜落一幀移動 10 px，
## 而可判定的區間只有幾個像素寬，實測會直接從「還在上面」跳到「已經穿過腰部」。

func test_stomp_when_feet_crossed_enemy_top_this_frame() -> void:
	assert_true(EnemyRules.is_stomp(600.0, 290.0, 300.0))

func test_no_stomp_when_already_below_top_last_frame() -> void:
	# 從側面撞上來：上一幀腳底已經在敵人腰部
	assert_false(EnemyRules.is_stomp(600.0, 340.0, 300.0))

func test_no_stomp_when_rising() -> void:
	assert_false(EnemyRules.is_stomp(-600.0, 290.0, 300.0))

func test_no_stomp_when_standing_still() -> void:
	assert_false(EnemyRules.is_stomp(0.0, 290.0, 300.0))

## 這條是這個 bug 的核心：一幀掉很多也不能漏判。
func test_fast_fall_is_not_skipped() -> void:
	var enemy_top := 300.0
	for step: float in [10.0, 15.0, 30.0, 60.0]:
		var previous := enemy_top - step * 0.6
		assert_true(EnemyRules.is_stomp(900.0, previous, enemy_top),
			"一幀移動 %.0f px 時漏判了踩踏" % step)

## 容差讓「幾乎踩到」也算數。少了它，判定窗窄到玩家覺得遊戲在耍賴。
func test_small_tolerance_below_the_top_still_counts() -> void:
	assert_true(EnemyRules.is_stomp(600.0,
		300.0 + EnemyRules.STOMP_TOLERANCE - 1.0, 300.0))
	assert_false(EnemyRules.is_stomp(600.0,
		300.0 + EnemyRules.STOMP_TOLERANCE + 1.0, 300.0))

func test_score_differs_by_kind() -> void:
	assert_gt(EnemyRules.score(EnemyRules.KIND_ARROW),
		EnemyRules.score(EnemyRules.KIND_BEAR))
