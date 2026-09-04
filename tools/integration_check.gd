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
	await _check_checkpoint_stops_listening_once_taken()
	await _check_goal_opens_when_coin_shot_kills_boss()
	await _check_every_character_is_selectable()
	await _check_select_arrows_cycle()
	await _check_sprint_is_faster()
	await _check_small_player_can_sprint()
	await _check_tapping_shift_throws_a_coin()
	await _check_end_menu_appears_and_navigates()
	await _check_share_actions_degrade_outside_web()
	await _check_pipe_round_trip_keeps_run_stats()
	await _check_pipe_entry_keeps_big_size()
	await _check_checkpoint_survives_pipe_round_trip()
	await _check_death_costs_one_life_and_respawns()
	await _check_death_in_room_still_costs_a_life()
	await _check_broken_level_does_not_start_playing()

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


## 按住 Shift 在同樣幀數內要跑得比不按遠。
## 單元測試證明速度上限對，這裡證明它真的接到節點上。
func _check_sprint_is_faster() -> void:
	var walk := await _measure_run(false, false)
	var dash := await _measure_run(true, false)
	_expect(dash > walk * 1.2, "按住 Shift 跑得比不按明顯遠",
		"走路 %.0f px、衝刺 %.0f px" % [walk, dash])


## 衝刺不該要求變大。小牛如果只能慢走，整個前半段關卡會很拖。
func _check_small_player_can_sprint() -> void:
	var small_dash := await _measure_run(true, false)
	var small_walk := await _measure_run(false, false)
	_expect(small_dash > small_walk * 1.2, "小牛按住 Shift 也衝得起來",
		"走路 %.0f px、衝刺 %.0f px" % [small_walk, small_dash])


## 量測 40 個物理幀內往右跑了多遠。
func _measure_run(sprint: bool, big: bool) -> float:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	if big:
		player.grow()
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break

	var start_x := player.global_position.x
	Input.action_press("move_right")
	if sprint:
		Input.action_press("throw")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	if sprint:
		Input.action_release("throw")
	var travelled := player.global_position.x - start_x
	main.queue_free()
	await get_tree().process_frame
	return travelled


## Shift 一鍵兩用的另一半：按下的那一幀，大牛有金幣時會丟出一枚。
## 這是我提醒過的代價（起衝會漏一枚金幣），使用者選了這個方案，
## 所以把它釘成明確的預期行為而不是意外。
func _check_tapping_shift_throws_a_coin() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	player.grow()
	for i in 5:
		main.stats.add_coin()
	var before: int = main.stats.coins

	await _tap_action("throw")
	_expect(main.stats.coins == before - 1, "輕點 Shift 會丟出一枚金幣",
		"金幣 %d -> %d" % [before, main.stats.coins])

	# 沒金幣時 Shift 應該是純衝刺，不會扣到負的
	while main.stats.spend_coin():
		pass
	await _tap_action("throw")
	_expect(main.stats.coins == 0, "彈藥空了按 Shift 不會扣成負數",
		"金幣=%d" % main.stats.coins)
	main.queue_free()
	await get_tree().process_frame


func _tap_action(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


## 通關後出現結束選單，←→ 走得動，游標預設停在「再玩一次」。
func _check_end_menu_appears_and_navigates() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().process_frame
	main.get_node("Player").goal_reached.emit()
	await get_tree().process_frame

	var menu: EndMenu = main.get_node("EndMenu")
	_expect(main.flow_state == Flow.CLEARED, "碰到旗竿進入通關狀態")
	_expect(menu.visible, "通關後結束選單看得到")
	_expect(menu.current_action() == EndMenu.DEFAULT_ACTION,
		"游標預設停在再玩一次（連按兩下空白鍵的舊習慣還能用）",
		"停在 %s" % menu.current_action())

	await _tap(KEY_RIGHT)
	_expect(menu.current_action() != EndMenu.DEFAULT_ACTION,
		"按右鍵換到別的選項", "還停在 %s" % menu.current_action())
	await _tap(KEY_LEFT)
	_expect(menu.current_action() == EndMenu.DEFAULT_ACTION,
		"按左鍵換回來", "停在 %s" % menu.current_action())

	# 選「再玩一次」要回到標題
	await _tap(KEY_SPACE)
	_expect(main.flow_state == Flow.TITLE, "選再玩一次回到標題",
		"flow_state=%d" % main.flow_state)
	_expect(not menu.visible, "回到標題後選單收起來")
	main.queue_free()
	await get_tree().process_frame


## 非網頁環境下三個分享動作都不能崩，而且要老實說「這裡辦不到」。
## 整合測試跑在 headless，正好是那個環境。
func _check_share_actions_degrade_outside_web() -> void:
	_expect(not ShareBridge.is_available(),
		"headless 下 ShareBridge 回報不可用")

	var main := await _make_main()
	main.begin_game()
	await get_tree().process_frame
	main.get_node("Player").goal_reached.emit()
	await get_tree().process_frame

	var menu: EndMenu = main.get_node("EndMenu")
	for action in ["facebook", "threads", "copy"]:
		menu.chosen.emit(action)
		await get_tree().process_frame
		_expect(not menu.current_note().is_empty(),
			"選 %s 之後有明確的提示文字" % action)

	# 分享不該把流程狀態帶走——按了分享還要留在結束畫面
	_expect(main.flow_state == Flow.CLEARED, "分享之後還留在結束畫面",
		"flow_state=%d" % main.flow_state)
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
	_expect(main.flow_state == Flow.PLAYING, "begin_game 會跳過選角直接開始",
		"flow_state=%d" % main.flow_state)

	main.get_node("Player").goal_reached.emit()
	await get_tree().process_frame
	_expect(main.flow_state == Flow.CLEARED, "碰到旗竿即通關",
		"flow_state=%d" % main.flow_state)
	main.queue_free()
	await get_tree().process_frame


func _first_in_group(main: Node, group: String) -> Node2D:
	for node in main.get_node("Entities").get_children():
		if node.is_in_group(group):
			return node
	return null


## 走進檢查點之後，它要真的關掉自己的偵測。
##
## mark_taken 是在玩家 TouchBox 的 area_entered 訊號裡被同步呼叫的，而 Godot
## 在物理 in/out 訊號期間會擋掉對 monitorable 的直接賦值（「Function blocked
## during in/out signal」）。被擋掉時旗子外觀變了、偵測卻沒關。這只有讓玩家
## 真的用物理重疊去碰才測得到——直接呼叫 mark_taken 不在訊號裡，永遠會過。
func _check_checkpoint_stops_listening_once_taken() -> void:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	var checkpoint: Area2D = _first_in_group(main, "checkpoint")
	if checkpoint == null:
		_fail("主關卡有檢查點")
		main.queue_free()
		return
	_ok("主關卡有檢查點")
	_expect(checkpoint.monitorable, "碰到之前檢查點偵測得到")

	player.respawn_at(checkpoint.global_position)
	for i in 10:
		await get_tree().physics_frame
		if bool(checkpoint.get("_taken")):
			break
	# 延後的屬性變更要等訊號結束後那次 flush 才生效，多等一輪。
	await get_tree().physics_frame
	await get_tree().process_frame

	_expect(bool(checkpoint.get("_taken")), "走進檢查點會標記為已通過")
	_expect(main.call("_respawn_position") == checkpoint.global_position,
		"重生點移到檢查點", "重生點=%s" % main.call("_respawn_position"))
	_expect(not checkpoint.monitorable,
		"通過後的檢查點不再被偵測（賦值沒有被物理訊號擋掉）")
	main.queue_free()
	await get_tree().process_frame


## 用金幣打死 Boss 之後，旗竿要真的打得開。
##
## 金幣打中 Boss 走的是 CoinShot 的 body_entered 訊號；Boss 的 defeated 沿路
## 同步傳到 Main，再叫旗竿 set_active(true)。這一整串都還在物理 in/out 訊號裡，
## monitorable 若直接賦值會被擋掉——旗竿看起來亮了卻碰不到，關卡就此卡死。
## 踩死 Boss 走的是每幀輪詢、不在訊號裡，所以只有金幣這條路會踩到這個洞。
func _check_goal_opens_when_coin_shot_kills_boss() -> void:
	var main := await _make_main()
	main.begin_game()
	var boss: Node2D = _first_in_group(main, "boss")
	var goal: Area2D = _first_in_group(main, "goal")
	if boss == null or goal == null:
		_fail("主關卡有 Boss 和旗竿")
		main.queue_free()
		return
	_ok("主關卡有 Boss 和旗竿")
	_expect(not goal.monitorable, "Boss 活著時旗竿碰不到")

	# 只留一發的血，讓一枚金幣就能收工
	boss.hp = BossRules.SHOT_DAMAGE
	var score_before: int = main.stats.score
	var shot: CoinShot = load("res://scenes/coin_shot.tscn").instantiate()
	shot.position = boss.global_position + Vector2(0, -boss.half_height)
	main.get_node("Entities").add_child(shot)
	shot.launch(1)
	for i in 30:
		await get_tree().physics_frame
		if not is_instance_valid(boss) or not bool(boss.get("_alive")):
			break
	await get_tree().physics_frame
	await get_tree().process_frame

	_expect(not is_instance_valid(boss) or not bool(boss.get("_alive")),
		"金幣打中 Boss 會打死它")
	_expect(main.stats.score == score_before + BossRules.SCORE,
		"Boss 死亡訊號傳到了 Main",
		"分數 %d -> %d" % [score_before, main.stats.score])
	_expect(goal.monitorable,
		"金幣打死 Boss 後旗竿碰得到（賦值沒有被物理訊號擋掉）")
	main.queue_free()
	await get_tree().process_frame


## --- 水管暗房與死亡：整條主線原本零覆蓋 ---

## 站上水管、按 ↓ 進去，回傳是否真的換了關卡。
func _enter_pipe(main: Node) -> bool:
	var pipe: Node2D = _first_in_group(main, "pipe")
	if pipe == null:
		return false
	var player: Player = main.get_node("Player")
	player.enter_level(pipe.global_position + Vector2(0, -40))
	for i in 30:
		await get_tree().physics_frame
		if not str(player.get("_standing_pipe")).is_empty():
			break
	if str(player.get("_standing_pipe")).is_empty():
		return false
	await _tap(KEY_DOWN)
	await get_tree().physics_frame
	await get_tree().process_frame
	return true


## 掉出關卡下緣觸發死亡，等死亡延遲跑完。
func _die_by_falling(main: Node) -> void:
	var player: Player = main.get_node("Player")
	player.global_position.y = 100000.0
	for i in 180:
		await get_tree().physics_frame
		if not bool(main.get("_death_pending")):
			if player.global_position.y < 90000.0:
				return
	await get_tree().process_frame


## 進暗房再回來，分數、金幣、生命、剩餘時間全部要延續。
##
## 原本 _load_level 用 not _in_room 判斷要不要重建 stats，而 _return_to_level
## 在呼叫它之前就把旗標設回 false——玩家撿完暗房的金幣走回來，整局成績歸零。
func _check_pipe_round_trip_keeps_run_stats() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	main.stats.add_score(4321)
	main.stats.add_coin()
	main.stats.add_coin()
	main.stats.lose_life()
	var score_before: int = main.stats.score
	var coins_before: int = main.stats.coins
	var lives_before: int = main.stats.lives

	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管")
		main.queue_free()
		await get_tree().process_frame
		return
	_ok("主關卡有可進入的水管")
	_expect(bool(main.get("_in_room")), "按 ↓ 之後進到暗房")
	_expect(main.stats.score == score_before,
		"進暗房不會洗掉分數", "%d -> %d" % [score_before, main.stats.score])

	main.call("_return_to_level")
	await get_tree().physics_frame
	await get_tree().process_frame

	_expect(not bool(main.get("_in_room")), "回到主關卡")
	_expect(main.stats.score == score_before,
		"回主關卡後分數延續", "%d -> %d" % [score_before, main.stats.score])
	_expect(main.stats.coins == coins_before,
		"回主關卡後金幣延續", "%d -> %d" % [coins_before, main.stats.coins])
	_expect(main.stats.lives == lives_before,
		"回主關卡後生命不會補滿", "%d -> %d" % [lives_before, main.stats.lives])
	main.queue_free()
	await get_tree().process_frame


## 進水管不該把大牛變回小牛——換場不是重生。
func _check_pipe_entry_keeps_big_size() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var player: Player = main.get_node("Player")
	player.grow()
	_expect(player.state.is_big(), "先變成大牛")

	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管（變身測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	_expect(player.state.is_big(), "進暗房之後還是大牛")
	main.queue_free()
	await get_tree().process_frame


## 檢查點要撐過一次水管往返。
func _check_checkpoint_survives_pipe_round_trip() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var checkpoint: Node2D = _first_in_group(main, "checkpoint")
	if checkpoint == null:
		_fail("主關卡有檢查點（水管測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	var flag_position: Vector2 = checkpoint.global_position
	main.call("_on_checkpoint_reached", flag_position)
	await get_tree().physics_frame

	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管（檢查點測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	main.call("_return_to_level")
	await get_tree().physics_frame
	await get_tree().process_frame

	_expect(main.call("_respawn_position") == flag_position,
		"水管往返之後檢查點還在",
		"重生點=%s 應為 %s" % [main.call("_respawn_position"), flag_position])
	main.queue_free()
	await get_tree().process_frame


## 死亡要剛好扣一條命並回到遊玩狀態。
func _check_death_costs_one_life_and_respawns() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var lives_before: int = main.stats.lives
	await _die_by_falling(main)

	_expect(main.stats.lives == lives_before - 1,
		"掉出關卡剛好扣一條命", "%d -> %d" % [lives_before, main.stats.lives])
	_expect(main.flow_state == Flow.PLAYING,
		"還有命就回到遊玩狀態", "flow_state=%d" % main.flow_state)
	main.queue_free()
	await get_tree().process_frame


## 在暗房裡死掉一樣要扣命。
##
## 原本 _respawn 在 _in_room 為真時會重載關卡並重建 stats，生命因此回到滿——
## 玩家只要待在暗房就有無限命。
func _check_death_in_room_still_costs_a_life() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管（暗房死亡測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	var lives_before: int = main.stats.lives
	await _die_by_falling(main)
	_expect(main.stats.lives == lives_before - 1,
		"在暗房裡死掉一樣扣命", "%d -> %d" % [lives_before, main.stats.lives])
	main.queue_free()
	await get_tree().process_frame


## 關卡檔壞掉時要停在標題並說明，不能讓玩家掉進沒有地形的虛空。
##
## 原本 _load_level 解析失敗只 push_error 就 return，_map 維持 null，
## 而掉出關卡的死亡判定有 _map == null 的早退——主角會無限下墜且永遠不判死。
func _check_broken_level_does_not_start_playing() -> void:
	var main := await _make_main()
	var loaded: bool = main.call("_load_level", "res://levels/根本不存在.txt")
	_expect(not loaded, "壞掉的關卡回報載入失敗")
	_expect(main.flow_state != Flow.PLAYING,
		"關卡載不起來就不會進入遊玩狀態", "flow_state=%d" % main.flow_state)
	main.queue_free()
	await get_tree().process_frame
