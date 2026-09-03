extends Node

## Headless 整合測試。單元測試證明每個純邏輯類別自己是對的；這裡證明它們
## 接起來之後在真的場景樹上也對——關卡載得動、玩家會落地不會穿地、
## 踩踏真的給回彈、相機邊界對得上關卡尺寸。
##
## 不用視窗驅動器，因為驗證環境（和未來的 CI）沒有圖形 session。
## 讓腳本自己 quit()，不加 --quit-after，避免中途卡住時被強制結束
## 而誤判為通過。

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("整合測試開始")
	print("環境 %s" % OS.get_name())
	print("---")

	await _check_levels_parse()
	await _check_main_scene_builds()
	await _check_player_lands()
	await _check_stomp_bounce()
	await _check_camera_bounds()
	await _check_scoring_and_flow()
	await _check_space_key_starts_game()
	await _check_player_runs_and_jumps()

	print("---")
	print("通過 %d　失敗 %d" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _ok(label: String) -> void:
	_passed += 1
	print("通過 %s" % label)


func _fail(label: String, detail := "") -> void:
	_failed += 1
	print("失敗 %s %s" % [label, detail])


func _expect(condition: bool, label: String, detail := "") -> void:
	if condition:
		_ok(label)
	else:
		_fail(label, detail)


## 真的推一個 InputEventKey 進輸入管線，確認「按空白鍵開始」這條路真的通。
## 直接呼叫 begin_game() 測不到 InputMap 對不對、事件有沒有被別的節點吃掉。
func _check_space_key_starts_game() -> void:
	var main := await _make_main()
	_expect(main.flow_state == Flow.TITLE, "一開始在標題畫面")

	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(main.flow_state == Flow.PLAYING, "按空白鍵開始遊戲",
		"flow_state=%d" % main.flow_state)

	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame


## 握著方向鍵真的會前進、按跳真的會離地。這是唯一一條「輸入 → 物理 → 位移」
## 的端到端驗證；PlayerPhysics 的單元測試證明數學對，這裡證明它有接上節點。
func _check_player_runs_and_jumps() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break

	var start_x := player.global_position.x
	Input.action_press("move_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var moved := player.global_position.x - start_x
	_expect(moved > 100.0, "握著方向鍵會前進", "只移動了 %.1f px" % moved)

	var ground_y := player.global_position.y
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	for i in 12:
		await get_tree().physics_frame
	var rise := ground_y - player.global_position.y
	_expect(rise > 40.0, "按跳會離地", "只上升了 %.1f px" % rise)

	main.queue_free()
	await get_tree().process_frame


func _check_levels_parse() -> void:
	for path in ["res://levels/level1.txt", "res://levels/level1_pipe_a.txt",
			"res://levels/dev.txt"]:
		var map := LevelMap.load_from(path)
		_expect(map.is_valid(), "關卡可解析 %s" % path, str(map.errors))


func _make_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	return main


func _check_main_scene_builds() -> void:
	var main := await _make_main()
	var map := LevelMap.load_from("res://levels/level1.txt")
	var entities: Node = main.get_node("Entities")
	# 實體節點 = 關卡實體 + 每一格地刺各一個 Area2D + 三種要節點化的磚塊
	_expect(entities.get_child_count() >= map.entities.size(),
		"實體全部建構", "節點 %d < 實體 %d" % [
			entities.get_child_count(), map.entities.size()])
	_expect(main.get_node("Tiles").get_used_cells().size() > 500,
		"地形寫進 TileMapLayer",
		"只有 %d 格" % main.get_node("Tiles").get_used_cells().size())
	main.queue_free()
	await get_tree().process_frame


func _check_player_lands() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		if player.is_on_floor():
			landed = true
			break
	_expect(landed, "玩家會落地不會穿地")
	_expect(player.global_position.y < 900.0, "玩家沒有掉出關卡",
		"y=%.1f" % player.global_position.y)
	main.queue_free()
	await get_tree().process_frame


func _check_stomp_bounce() -> void:
	var main := await _make_main()
	var player: Player = main.get_node("Player")
	player.apply_stomp(false)
	_expect(is_equal_approx(player.velocity.y, PlayerPhysics.stomp_velocity(false)),
		"踩踏給出設計值的回彈", "velocity.y=%.1f" % player.velocity.y)
	main.queue_free()
	await get_tree().process_frame


func _check_camera_bounds() -> void:
	var main := await _make_main()
	var map := LevelMap.load_from("res://levels/level1.txt")
	var camera: Camera2D = main.get_node("Player/Camera")
	_expect(camera.limit_right == int(map.pixel_size(LevelBuilder.TILE).x),
		"相機右邊界等於關卡寬度",
		"limit_right=%d 關卡寬=%d" % [camera.limit_right,
			int(map.pixel_size(LevelBuilder.TILE).x)])
	main.queue_free()
	await get_tree().process_frame


func _check_scoring_and_flow() -> void:
	var main := await _make_main()
	var before: int = main.stats.score
	main.stats.add_coin()
	_expect(main.stats.score > before, "撿金幣會加分")

	main.begin_game()
	await get_tree().process_frame
	_expect(main.flow_state == Flow.PLAYING, "開始遊戲進入遊玩狀態",
		"flow_state=%d" % main.flow_state)

	main.get_node("Player").goal_reached.emit()
	await get_tree().process_frame
	_expect(main.flow_state == Flow.CLEARED, "碰到旗竿即通關",
		"flow_state=%d" % main.flow_state)
	main.queue_free()
	await get_tree().process_frame
