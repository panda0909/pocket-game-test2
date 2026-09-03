extends GutTest

## 分享文字與網址的組裝。純字串處理，所以可以完整測——
## 而 percent-encoding 正是那種寫錯了不會當場爆、只會讓分享出去變亂碼的地方。

var stats: RunStats

func before_each() -> void:
	stats = RunStats.new(300)
	stats.add_score(12340)
	for i in 48:
		stats.add_coin()

func test_message_contains_the_score() -> void:
	var text := ShareText.compose(stats, 0, true)
	assert_string_contains(text, str(stats.score))

func test_message_contains_the_character_name() -> void:
	var text := ShareText.compose(stats, 1, true)
	assert_string_contains(text, Roster.name_of(1))

func test_cleared_and_failed_messages_differ() -> void:
	var cleared := ShareText.compose(stats, 0, true)
	var failed := ShareText.compose(stats, 0, false)
	assert_ne(cleared, failed)
	assert_string_contains(cleared, "通關")

func test_cleared_message_mentions_coins() -> void:
	assert_string_contains(ShareText.compose(stats, 0, true), str(stats.coins))

func test_full_message_ends_with_the_page_url() -> void:
	var message := ShareText.full_message(stats, 0, true)
	assert_true(message.ends_with(ShareText.PAGE_URL),
		"分享文字結尾要是遊戲網址，收到的人才點得進來：%s" % message)

func test_page_url_is_the_published_site() -> void:
	assert_true(ShareText.PAGE_URL.begins_with("https://"))
	assert_string_contains(ShareText.PAGE_URL, "pocket-game-test2")

func test_facebook_url_points_at_the_sharer_with_our_page() -> void:
	var url := ShareText.facebook_url()
	assert_string_contains(url, "facebook.com/sharer")
	assert_string_contains(url, ShareText.PAGE_URL.uri_encode())

func test_threads_url_points_at_the_post_intent() -> void:
	assert_string_contains(ShareText.threads_url("哈囉"), "threads.net/intent/post")

## 中文與全形標點一定要編碼過才能放進查詢字串。
func test_threads_url_encodes_chinese() -> void:
	var url := ShareText.threads_url("通關了")
	assert_false(url.contains("通關了"), "中文沒有編碼就直接塞進網址了")
	assert_string_contains(url, "%E9")

func test_threads_url_does_not_double_encode() -> void:
	var url := ShareText.threads_url(ShareText.full_message(stats, 0, true))
	assert_false(url.contains("%25"),
		"出現 %25 代表百分號被再編碼一次，收到的人會看到亂碼")

func test_encoding_round_trips() -> void:
	var message := ShareText.full_message(stats, 2, false)
	var url := ShareText.threads_url(message)
	var encoded := url.substr(url.find("text=") + 5)
	assert_eq(encoded.uri_decode(), message, "編碼後解回來要一模一樣")

func test_out_of_range_character_still_produces_a_message() -> void:
	assert_false(ShareText.compose(stats, 99, true).is_empty())
