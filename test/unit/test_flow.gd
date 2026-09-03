extends GutTest

func test_start_moves_title_to_playing() -> void:
	assert_eq(Flow.next(Flow.TITLE, "start", 3), Flow.PLAYING)

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
	assert_false(Flow.accepts_input(Flow.GAME_OVER))
	assert_false(Flow.accepts_input(Flow.CLEARED))

func test_only_playing_counts_down() -> void:
	assert_true(Flow.counts_down(Flow.PLAYING))
	assert_false(Flow.counts_down(Flow.CLEARED))
