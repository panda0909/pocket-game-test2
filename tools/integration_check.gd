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
	await _check_milk_lands_within_reach()
	await _check_stomping_actually_kills()
	await _check_side_contact_hurts_instead()
	await _check_every_character_is_selectable()
	await _check_select_arrows_cycle()

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

	await _tap(KEY_SPACE)
	_expect(main.flow_state == Flow.SELECT, "按空白鍵進入選角畫面",
		"flow_state=%d" % main.flow_state)
	_expect(main.get_node("CharacterSelect").visible, "選角畫面看得到")

	await _tap(KEY_SPACE)
	_expect(main.flow_state == Flow.PLAYING, "在選角畫面按空白鍵開始遊戲",
		"flow_state=%d" % main.flow_state)
	_expect(not main.get_node("CharacterSelect").visible, "開始後選角畫面收起來")
	main.queue_free()
	await get_tree().process_frame


## 推一次真的按鍵事件（按下再放開）。
func _tap(code: int) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


## 三隻都選得到，而且玩家的貼圖真的換掉了。
## 光測 Roster 只證明清單對，不證明選了之後畫面上真的換人。
func _check_every_character_is_selectable() -> void:
	var main := await _make_main()
	await _tap(KEY_SPACE)
	_expect(main.flow_state == Flow.SELECT, "進到選角畫面")

	var player: Player = main.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite")
	var seen: Dictionary = {}

	for i in Roster.COUNT:
		main.character_index = i
		main.get_node("CharacterSelect").show_index(i)
		player.set_character(i)
		await get_tree().process_frame
		var path: String = sprite.texture.resource_path
		_expect(path == Roster.texture_path(i),
			"選 %s 時主角貼圖換成對的圖" % Roster.name_of(i),
			"實際是 %s" % path)
		seen[path] = true

	_expect(seen.size() == Roster.COUNT, "三隻用的是三張不同的圖",
		"只出現 %d 張" % seen.size())
	main.queue_free()
	await get_tree().process_frame


## 選角畫面的左右鍵會換人，走到頭會繞回來。
func _check_select_arrows_cycle() -> void:
	var main := await _make_main()
	await _tap(KEY_SPACE)
	var start: int = main.character_index

	await _tap(KEY_RIGHT)
	_expect(main.character_index == Roster.cycle(start, 1),
		"按右鍵換到下一隻", "index=%d" % main.character_index)

	await _tap(KEY_LEFT)
	_expect(main.character_index == start,
		"按左鍵換回上一隻", "index=%d" % main.character_index)

	# 從第一隻往左應該繞到最後一隻
	main.character_index = 0
	await _tap(KEY_LEFT)
	_expect(main.character_index == Roster.COUNT - 1,
		"從第一隻往左會繞到最後一隻", "index=%d" % main.character_index)

	# 選角時計時不能跑
	var before: float = main.stats.time_left
	for i in 20:
		await get_tree().process_frame
	_expect(is_equal_approx(main.stats.time_left, before),
		"選角時計時停住", "少了 %.2f 秒" % (before - main.stats.time_left))
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


## 頂出來的牛奶要落到地面上。原本它停在磚頂，而磚為了讓大牛鑽得過去必須
## 離地 3 格，道具就落在跳不到的高度。這條測試守著「拿得到」這件事。
func _check_milk_lands_within_reach() -> void:
	var main := await _make_main()
	var block: Node = null
	for node in main.get_node("Entities").get_children():
		if node.is_in_group("block") \
				and node.kind == TileGlossary.KIND_MILK_BRICK:
			block = node
			break
	if block == null:
		_fail("主關卡有牛奶磚")
		main.queue_free()
		return
	_ok("主關卡有牛奶磚")

	var block_y: float = block.global_position.y
	_expect(block.hit_from_below(false) == "milk", "牛奶磚頂得出牛奶")

	var milk: Node2D = null
	for i in 180:
		await get_tree().physics_frame
		for node in main.get_node("Entities").get_children():
			if node.is_in_group("powerup"):
				milk = node
				break
		if milk != null and bool(milk.get("_landed")):
			break

	if milk == null:
		_fail("牛奶有生成")
		main.queue_free()
		return
	_ok("牛奶有生成")

	_expect(bool(milk.get("_landed")), "牛奶有落地")

	# 磚塊在離地 3 格處，所以牛奶落地後應該比磚塊低 2 格以上。
	# 這條就是在守「拿得到」：停在磚頂的話 drop 會是負的。
	var drop := milk.global_position.y - block_y
	_expect(drop > LevelBuilder.TILE * 1.5,
		"牛奶落到地面而不是停在磚上", "只低了 %.0f px" % drop)

	# 真正的驗收：玩家從那塊地面起跳，頭頂碰得到牛奶嗎？
	var ground_y := milk.global_position.y + Powerup.GROUND_OFFSET
	var head_reach := ground_y - Player.SMALL_HEIGHT - PlayerPhysics.jump_height()
	var milk_bottom := milk.global_position.y + Powerup.GROUND_OFFSET
	_expect(head_reach < milk_bottom, "小牛跳得到牛奶",
		"頭頂只到 %.0f，牛奶底部在 %.0f" % [head_reach, milk_bottom])
	main.queue_free()
	await get_tree().process_frame


## 從上方落下真的踩得死敵人。
##
## 這條是踩不死那個 bug 的補洞測試。原本的單元測試拿手挑的數值去測判定
## 函式，測得過，但函式的契約本身就錯了——它用當幀位置判，而真實墜落速度
## 下那個判定窗只有幾個像素寬，每次都被跨過去。只有讓玩家真的掉下去才看得出來。
func _check_stomping_actually_kills() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	var target := _first_stompable(main)
	if target == null:
		_fail("關卡裡有可踩的敵人")
		main.queue_free()
		return
	_ok("關卡裡有可踩的敵人")

	player.global_position = target.global_position + Vector2(0, -220)
	player.velocity = Vector2.ZERO
	var bounced := false
	for i in 60:
		await get_tree().physics_frame
		if player.velocity.y < -100.0:
			bounced = true
			break
		if not is_instance_valid(target):
			break

	_expect(bounced, "從上方落下會彈起來（踩到了）",
		"velocity.y=%.1f" % player.velocity.y)
	for i in 30:
		await get_tree().physics_frame
	_expect(not is_instance_valid(target) or not target.get("_alive"),
		"被踩的敵人死了")
	main.queue_free()
	await get_tree().process_frame


## 從側面撞上去要受傷，不能被誤判成踩踏。
func _check_side_contact_hurts_instead() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	var target := _first_stompable(main)
	if target == null:
		main.queue_free()
		return

	player.grow()
	var was_big: bool = player.state.is_big()
	# 腳底和敵人同高、水平貼上去
	player.global_position = target.global_position + Vector2(-30, 0)
	player.velocity = Vector2(200, 60)
	for i in 20:
		await get_tree().physics_frame
		if not player.state.is_big():
			break

	_expect(was_big and not player.state.is_big(),
		"從側面撞上去會受傷而不是踩死",
		"is_big=%s 敵人還在=%s" % [player.state.is_big(),
			is_instance_valid(target)])
	main.queue_free()
	await get_tree().process_frame


func _first_stompable(main: Node) -> Node2D:
	for node in main.get_node("Entities").get_children():
		if node.is_in_group("enemy") and not node.is_in_group("boss") \
				and EnemyRules.is_stompable(node.kind):
			return node
	return null


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
	_expect(main.flow_state == Flow.PLAYING, "begin_game 會跳過選角直接開始",
		"flow_state=%d" % main.flow_state)

	main.get_node("Player").goal_reached.emit()
	await get_tree().process_frame
	_expect(main.flow_state == Flow.CLEARED, "碰到旗竿即通關",
		"flow_state=%d" % main.flow_state)
	main.queue_free()
	await get_tree().process_frame
