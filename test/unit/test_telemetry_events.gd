extends GutTest

## 埋點事件的定義與清洗。
##
## 專案原本沒有任何埋點，所以「載入完成率」「多少人按了開始」「多少人通關」
## 「多少人按分享」一項都量不到——所有決策（包括那份產品診斷）都只能靠推算。
##
## 但埋點是會把資料送出去的東西，所以這一層的責任是：只送得出白名單裡的
## 欄位，而且值只能是數字或短字串。玩家的任何個人資訊不該有機會被夾帶出去。

func test_event_names_are_a_closed_set() -> void:
	assert_gt(TelemetryEvents.names().size(), 4)
	for name in TelemetryEvents.names():
		assert_true(TelemetryEvents.is_known(name))
	assert_false(TelemetryEvents.is_known("隨便打的名字"))

## 事件名稱打錯就等於那個事件永遠是 0，而且不會有人發現。
func test_unknown_event_is_rejected_not_silently_sent() -> void:
	assert_eq(TelemetryEvents.sanitize_name("cleared"), "cleared")
	assert_eq(TelemetryEvents.sanitize_name("clearedd"), "")

func test_known_numeric_props_pass_through() -> void:
	var out := TelemetryEvents.sanitize({"score": 1200, "collect_pct": 55})
	assert_eq(out["score"], 1200)
	assert_eq(out["collect_pct"], 55)

## 白名單以外的欄位一律丟掉。這是「不會不小心送出個資」的唯一保證。
func test_unknown_props_are_dropped() -> void:
	var out := TelemetryEvents.sanitize({
		"score": 100,
		"player_email": "someone@example.com",
		"user_id": "abc-123",
	})
	assert_true(out.has("score"))
	assert_false(out.has("player_email"))
	assert_false(out.has("user_id"))

## 白名單裡的欄位也不能塞任意內容進去。
func test_values_must_be_numbers_or_short_strings() -> void:
	var out := TelemetryEvents.sanitize({
		"score": 100,
		"platform": "facebook",
		"character": {"nested": "物件"},
	})
	assert_eq(out["platform"], "facebook")
	assert_false(out.has("character"), "物件不該被送出去")

func test_long_strings_are_truncated() -> void:
	var long := ""
	for i in 200:
		long += "x"
	var out := TelemetryEvents.sanitize({"platform": long})
	assert_lte(out["platform"].length(), TelemetryEvents.MAX_STRING)

func test_empty_props_are_fine() -> void:
	assert_eq(TelemetryEvents.sanitize({}).size(), 0)
