extends GutTest

func test_start_moves_title_to_character_select() -> void:
	assert_eq(Flow.next(Flow.TITLE, "start", 3), Flow.SELECT)

func test_confirm_moves_select_to_playing() -> void:
	assert_eq(Flow.next(Flow.SELECT, "confirm", 3), Flow.PLAYING)

func test_select_can_go_back_to_title() -> void:
	assert_eq(Flow.next(Flow.SELECT, "back", 3), Flow.TITLE)

func test_select_ignores_gameplay_events() -> void:
	assert_eq(Flow.next(Flow.SELECT, "died", 0), Flow.SELECT)
	assert_eq(Flow.next(Flow.SELECT, "goal", 3), Flow.SELECT)

func test_title_ignores_gameplay_events() -> void:
	assert_eq(Flow.next(Flow.TITLE, "died", 3), Flow.TITLE)
	assert_eq(Flow.next(Flow.TITLE, "goal", 3), Flow.TITLE)

func test_death_with_lives_left_returns_to_playing() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "died", 2), Flow.PLAYING)

func test_death_without_lives_is_game_over() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "died", 0), Flow.GAME_OVER)

func test_reaching_goal_clears() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "goal", 3), Flow.CLEARED)

func test_restart_from_end_states_goes_to_title() -> void:
	assert_eq(Flow.next(Flow.GAME_OVER, "restart", 0), Flow.TITLE)
	assert_eq(Flow.next(Flow.CLEARED, "restart", 3), Flow.TITLE)

func test_cleared_ignores_further_deaths() -> void:
	assert_eq(Flow.next(Flow.CLEARED, "died", 0), Flow.CLEARED)

func test_unknown_event_keeps_state() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "sneeze", 3), Flow.PLAYING)

func test_only_playing_accepts_input() -> void:
	assert_true(Flow.accepts_input(Flow.PLAYING))
	assert_false(Flow.accepts_input(Flow.TITLE))
	assert_false(Flow.accepts_input(Flow.SELECT))
	assert_false(Flow.accepts_input(Flow.GAME_OVER))
	assert_false(Flow.accepts_input(Flow.CLEARED))

## 選角時計時不能跑，不然玩家在挑角色的時候就在扣時間。
func test_only_playing_counts_down() -> void:
	assert_true(Flow.counts_down(Flow.PLAYING))
	assert_false(Flow.counts_down(Flow.SELECT))
	assert_false(Flow.counts_down(Flow.CLEARED))

func test_select_is_a_distinct_state() -> void:
	for other in [Flow.TITLE, Flow.PLAYING, Flow.GAME_OVER, Flow.CLEARED]:
		assert_ne(Flow.SELECT, other)
