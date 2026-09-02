extends GutTest

var s: PlayerState

func before_each() -> void:
	s = PlayerState.new()

func test_starts_small_and_vulnerable() -> void:
	assert_eq(s.size, PlayerState.SMALL)
	assert_false(s.is_invincible())
	assert_false(s.can_throw())

func test_small_hit_dies() -> void:
	assert_eq(s.take_hit(), "died")

func test_milk_grows_small_to_big() -> void:
	assert_eq(s.collect_milk(), "grew")
	assert_true(s.is_big())
	assert_true(s.can_throw())

func test_milk_when_big_is_bonus() -> void:
	s.collect_milk()
	assert_eq(s.collect_milk(), "bonus")
	assert_true(s.is_big())

func test_big_hit_shrinks_and_grants_invincibility() -> void:
	s.collect_milk()
	assert_eq(s.take_hit(), "shrank")
	assert_eq(s.size, PlayerState.SMALL)
	assert_true(s.is_invincible())

func test_hit_while_invincible_is_ignored() -> void:
	s.collect_milk()
	s.take_hit()
	assert_eq(s.take_hit(), "ignored")

func test_invincibility_expires() -> void:
	s.collect_milk()
	s.take_hit()
	s.advance(PlayerState.INVINCIBLE_TIME + 0.01)
	assert_false(s.is_invincible())
	assert_eq(s.take_hit(), "died")

func test_invincibility_still_active_just_before_expiry() -> void:
	s.collect_milk()
	s.take_hit()
	s.advance(PlayerState.INVINCIBLE_TIME - 0.05)
	assert_true(s.is_invincible())

func test_reset_returns_to_small_and_clears_invincibility() -> void:
	s.collect_milk()
	s.take_hit()
	s.reset()
	assert_eq(s.size, PlayerState.SMALL)
	assert_false(s.is_invincible())

func test_scale_reflects_size() -> void:
	assert_almost_eq(s.body_scale(), 1.0, 0.001)
	s.collect_milk()
	assert_almost_eq(s.body_scale(), PlayerState.BIG_SCALE, 0.001)
