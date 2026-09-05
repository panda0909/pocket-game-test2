extends GutTest

## 輸入表的驗收。
##
## 取代原本的 test_smoke.gd（只有 assert_eq(1 + 1, 2)）——「GUT 跑得起來」
## 這件事 run_tests.sh 的載入檔數比對已經驗過了，而且驗得更好。
## 這裡改成驗真正沒人守的東西：Player 依賴的六個 action 名稱。
## 拼錯一個字，遊戲不會報錯，只會安靜地不回應那個按鍵。

const REQUIRED := [
	"move_left", "move_right", "jump", "duck", "throw", "sprint", "pause",
]

func test_every_action_the_game_uses_exists() -> void:
	for action in REQUIRED:
		assert_true(InputMap.has_action(action), "輸入表缺少 %s" % action)

func test_every_action_has_at_least_one_key() -> void:
	for action in REQUIRED:
		if not InputMap.has_action(action):
			continue
		var keys := 0
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys += 1
		assert_gt(keys, 0, "%s 沒有綁任何鍵盤按鍵" % action)

## 手把是平台遊戲的主要輸入裝置之一，而且網頁版接上手把就該能玩。
func test_every_action_has_gamepad_support() -> void:
	for action in REQUIRED:
		if not InputMap.has_action(action):
			continue
		var pad := 0
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				pad += 1
		assert_gt(pad, 0, "%s 沒有手把綁定" % action)

## 方向鍵玩家的直覺跳躍鍵是 ↑。duck 綁了 ↓，代表方向鍵是被當成一組
## 主要輸入支援的——同一組裡的 ↑ 沒作用，玩家會以為遊戲當掉。
func test_up_arrow_also_jumps() -> void:
	var found := false
	for event in InputMap.action_get_events("jump"):
		if event is InputEventKey and event.physical_keycode == KEY_UP:
			found = true
	assert_true(found, "↑ 應該也能跳")

## 任何兩個動作都不該共用同一個鍵。
##
## 這條原本只比對衝刺與丟金幣——那是因為它們以前真的共用 Shift：大牛每次
## 起衝一定丟掉一枚金幣，而金幣是有限彈藥（Boss 需要六枚），習慣按住 Shift
## 跑的玩家會在抵達關底前把彈藥灑光而不知道是自己造成的。
##
## 改成兩兩比對，是因為重新綁鍵正是最容易撞到別人的時候：換一個鍵很快，
## 而撞到的表現只是「按下去同時做了兩件事」，不會有任何錯誤。
func test_no_two_actions_share_a_key() -> void:
	for i in REQUIRED.size():
		for j in range(i + 1, REQUIRED.size()):
			var a: String = REQUIRED[i]
			var b: String = REQUIRED[j]
			if not (InputMap.has_action(a) and InputMap.has_action(b)):
				continue
			for code in _key_codes(a):
				assert_false(_key_codes(b).has(code),
					"%s 與 %s 共用了同一個鍵（keycode %d）" % [a, b, code])

## 手把按鍵同理。
func test_no_two_actions_share_a_gamepad_button() -> void:
	for i in REQUIRED.size():
		for j in range(i + 1, REQUIRED.size()):
			var a: String = REQUIRED[i]
			var b: String = REQUIRED[j]
			if not (InputMap.has_action(a) and InputMap.has_action(b)):
				continue
			for index in _pad_buttons(a):
				assert_false(_pad_buttons(b).has(index),
					"%s 與 %s 共用了同一顆手把鍵（button %d）" % [a, b, index])

func _pad_buttons(action: String) -> Array:
	var out: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			out.append(event.button_index)
	return out

func _key_codes(action: String) -> Array:
	var codes: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			codes.append(event.physical_keycode)
	return codes
