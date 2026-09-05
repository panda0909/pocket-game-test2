extends GutTest

## 成績卡的內容。
##
## 分享出去的圖以前是固定的三隻角色合照——A 玩家通關拿 12340 分、B 玩家
## 開場就死，兩人貼到 Facebook 的東西一模一樣。動態牆上沒有任何個人化訊號，
## 而那是社群傳播最致命的一種缺陷：分享出去的不是「我」的，是「它」的。
##
## 版面與渲染是節點的事；「卡片上該寫什麼」是純資料，留在這裡測。

func _stats(score: int, cleared_pct: int) -> RunStats:
	var stats := RunStats.new(150)
	stats.set_targets(10, 5, 2)
	stats.add_score(score)
	for i in int(round(cleared_pct * 0.1)):
		stats.add_coin()
	return stats

func test_cleared_card_says_cleared() -> void:
	var card := ScoreCard.compose(_stats(12340, 100), 0, true, 62)
	assert_eq(card["headline"], "通關")
	assert_string_contains(card["character"], Roster.name_of(0))

func test_failed_card_does_not_claim_a_clear() -> void:
	var card := ScoreCard.compose(_stats(3200, 40), 1, false, 0)
	assert_ne(card["headline"], "通關")
	assert_false(card["headline"].is_empty())

## 卡片上的每一個數字都要能對回 RunStats，不能是裝飾。
func test_numbers_come_from_the_run() -> void:
	var stats := _stats(8888, 50)
	var card := ScoreCard.compose(stats, 2, true, 41)
	assert_eq(int(card["score"]), stats.score)
	assert_eq(int(card["coins"]), stats.found["coin"])
	assert_eq(int(card["collect_pct"]), stats.collect_percent())
	assert_eq(int(card["time_left"]), 41)

## 無傷是最難的成就，有拿到就要放在卡片上——但要同時滿足「通關」與「沒受傷」。
func test_flawless_needs_both_clearing_and_no_damage() -> void:
	var clean := _stats(5000, 60)
	assert_true(ScoreCard.compose(clean, 0, true, 30)["flawless"],
		"通關且沒受傷 → 有無傷")
	assert_false(ScoreCard.compose(clean, 0, false, 0)["flawless"],
		"沒通關就不算，半路無傷死掉不是成就")

	var hurt := _stats(5000, 60)
	hurt.count_damage_taken()
	assert_false(ScoreCard.compose(hurt, 0, true, 30)["flawless"],
		"受過傷就不算")

## 沒通關就沒有通關時間可言，不該印一個 0 秒上去。
func test_time_is_omitted_when_not_cleared() -> void:
	var card := ScoreCard.compose(_stats(3200, 40), 0, false, 0)
	assert_eq(int(card["time_left"]), 0)
	assert_false(card["show_time"])
	assert_true(ScoreCard.compose(_stats(3200, 40), 0, true, 55)["show_time"])

## 角色索引壞掉不該崩——卡片是分享路徑上的東西，那條路徑不能有例外。
func test_bad_character_index_falls_back() -> void:
	var card := ScoreCard.compose(_stats(100, 10), 99, false, 0)
	assert_string_contains(card["character"], Roster.name_of(Roster.DEFAULT_INDEX))

## 檔名要能區分不同的成績，玩家連存三張才不會互相覆蓋。
func test_filename_includes_the_score() -> void:
	# _stats 撿的金幣也會加分，所以拿實際的 score 來比對，不要寫死。
	var stats := _stats(12340, 100)
	var name := ScoreCard.filename(stats, true)
	assert_string_contains(name, str(stats.score))
	assert_true(name.ends_with(".png"))
	assert_false(name.contains(" "), "檔名不要有空白")
