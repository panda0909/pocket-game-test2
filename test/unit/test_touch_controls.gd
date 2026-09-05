extends GutTest

## 虛擬按鍵的設定驗收。
##
## 實際觸控要真的裝置才試得出來，但「每顆鍵綁的動作真的存在」「按鍵之間
## 不會重疊」這兩件事是純資料，寫錯的話手機玩家會按到沒反應或按錯鍵。

func test_every_button_maps_to_a_real_action() -> void:
	for spec in TouchControls.BUTTONS:
		assert_true(InputMap.has_action(spec["action"]),
			"虛擬按鍵綁了不存在的動作 %s" % spec["action"])

## 移動、跳躍、丟金幣、衝刺、暫停都要按得到。
func test_all_essential_actions_are_reachable_by_touch() -> void:
	var covered: Dictionary = {}
	for spec in TouchControls.BUTTONS:
		covered[spec["action"]] = true
	for needed in ["move_left", "move_right", "jump", "duck", "throw",
			"sprint", "pause"]:
		assert_true(covered.has(needed), "手機上按不到 %s" % needed)

## 兩顆鍵重疊的話，玩家想跳卻會同時丟出金幣。
func test_buttons_do_not_overlap() -> void:
	var list := TouchControls.BUTTONS
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: Dictionary = list[i]
			var b: Dictionary = list[j]
			var gap: float = (a["at"] as Vector2).distance_to(b["at"])
			assert_gt(gap, float(a["r"]) + float(b["r"]),
				"%s 和 %s 的按鍵範圍重疊" % [a["action"], b["action"]])

## 按鍵不能跑到畫面外。
func test_buttons_stay_inside_the_viewport() -> void:
	var w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	for spec in TouchControls.BUTTONS:
		var at: Vector2 = spec["at"]
		var r: float = spec["r"]
		assert_gte(at.x - r, 0.0, "%s 超出左邊界" % spec["action"])
		assert_lte(at.x + r, w, "%s 超出右邊界" % spec["action"])
		assert_gte(at.y - r, 0.0, "%s 超出上邊界" % spec["action"])
		assert_lte(at.y + r, h, "%s 超出下邊界" % spec["action"])

## 桌面沒有觸控螢幕就不該蓋一排半透明圓圈在畫面上。
func test_hidden_without_a_touchscreen() -> void:
	assert_eq(TouchControls.should_show(),
		DisplayServer.is_touchscreen_available())
