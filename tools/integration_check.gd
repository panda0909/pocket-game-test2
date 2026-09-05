extends Node

## Headless 整合測試。單元測試證明每個純邏輯類別自己是對的；這裡證明它們
## 接起來之後在真的場景樹上也對——關卡載得動、玩家會落地不會穿地、
## 踩踏真的給回彈、相機邊界對得上關卡尺寸。
##
## 不用視窗驅動器，因為驗證環境（和未來的 CI）沒有圖形 session。
## 讓腳本自己 quit()，不加 --quit-after，避免中途卡住時被強制結束
## 而誤判為通過。

## 至少要跑到這麼多項檢查。加新檢查時把它調高。
const MIN_CHECKS := 125

var _passed := 0
var _failed := 0


func _ready() -> void:
	# 有些檢查會把樹暫停。這個節點得繼續跑，不然 await 之後就再也醒不來。
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	await _check_pressing_throw_key_fires_a_coin()
	await _check_end_menu_appears_and_navigates()
	await _check_share_actions_degrade_outside_web()
	await _check_pipe_round_trip_keeps_run_stats()
	await _check_pipe_entry_keeps_big_size()
	await _check_checkpoint_survives_pipe_round_trip()
	await _check_death_costs_one_life_and_respawns()
	await _check_death_in_room_still_costs_a_life()
	await _check_broken_level_does_not_start_playing()
	await _check_coin_shot_stops_at_blocks()
	await _check_dead_enemy_stops_being_an_enemy()
	await _check_share_copy_reports_failure_in_headless()
	await _check_confirming_character_does_not_jump()
	await _check_pause_stops_the_world()
	await _check_pause_is_released_on_state_change()
	await _check_finishing_a_run_records_the_score()
	await _check_boss_health_bar_follows_the_boss()
	await _check_boss_health_bar_hidden_outside_gameplay()
	await _check_clear_time_is_recorded_before_the_bonus()
	await _check_pipe_does_not_respawn_collected_things()
	await _check_pipe_does_not_respawn_enemies()
	await _check_small_player_gets_feedback_when_throwing()
	await _check_pipe_shows_a_prompt()
	await _check_goal_reads_as_a_goal()
	await _check_collect_percent_tracks_progress()
	await _check_flawless_survives_respawn()
	await _check_end_menu_shows_collection()

	print("---")
	# 檢查總數也要守。單看「失敗 0」看不出有沒有檢查憑空消失——
	# 某個 _check_* 因為找不到目標而提早 return 的話，總結行仍然是漂亮的
	# 「通過 N　失敗 0」，只是 N 悄悄變小了。
	if _passed + _failed < MIN_CHECKS:
		_fail("只跑了 %d 項檢查，少於預期的 %d 項——有檢查沒被執行到"
			% [_passed + _failed, MIN_CHECKS])
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
	for node in get_tree().get_nodes_in_group("block"):
		if main.is_ancestor_of(node) \
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
		milk = _first_in_group(main, "powerup")
		if milk != null and milk.is_landed():
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
		# 明確失敗，不要靜默 return。以前這裡直接 return，不計失敗也不計通過——
		# 只要有人改關卡拿掉可踩敵人，這條檢查就人間蒸發，而總結行
		# 「通過 N　失敗 0」看起來一切正常，因為 N 變小了沒有人在看。
		_fail("關卡裡有可踩的敵人（側面接觸測試）")
		main.queue_free()
		await get_tree().process_frame
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
##
## 這條以前和上面那條參數完全相同、只是順序對調——兩條測的都是小牛，
## 真正該防的迴歸（有人把衝刺綁上「必須是大牛」）兩條都抓不到，
## 而且 _measure_run 的 big 參數從來沒被傳過 true，那段是死碼。
## 現在是真的對照：小牛衝刺與大牛衝刺應該一樣快。
func _check_small_player_can_sprint() -> void:
	var small_dash := await _measure_run(true, false)
	var big_dash := await _measure_run(true, true)
	_expect(small_dash > big_dash * 0.9, "小牛衝刺不比大牛慢",
		"小牛 %.0f px、大牛 %.0f px" % [small_dash, big_dash])


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
		Input.action_press("sprint")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	if sprint:
		Input.action_release("sprint")
	var travelled := player.global_position.x - start_x
	main.queue_free()
	await get_tree().process_frame
	return travelled


## 丟金幣有自己的鍵（J），按下去大牛有金幣時會丟出一枚。
##
## 衝刺與丟金幣以前共用 Shift，於是大牛每次起衝都會漏掉一枚金幣，
## 而金幣是有限彈藥（Boss 要六發）。現在兩者分家，這條檢查證明
## 丟金幣那條路仍然接得起來。
func _check_pressing_throw_key_fires_a_coin() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var player: Player = main.get_node("Player")
	player.grow()
	for i in 6:
		main.stats.add_coin()
	var before: int = main.stats.coins
	# 輪詢式的輸入用 action 壓，不用實體按鍵事件——按鍵綁定本身
	# 由 test_input_map.gd 驗證，這裡要驗的是「丟金幣那條路接得起來」。
	await _tap_action("throw")
	await get_tree().physics_frame
	_expect(main.stats.coins == before - 1, "按丟金幣鍵射出一枚金幣",
		"%d -> %d" % [before, main.stats.coins])

	# 彈藥空了不該扣成負數
	while main.stats.coins > 0:
		main.stats.spend_coin()
	await _tap_action("throw")
	await get_tree().physics_frame
	_expect(main.stats.coins == 0, "彈藥空了再按不會扣成負數",
		"coins=%d" % main.stats.coins)
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
	_expect(main.flow_state == Flow.PLAYING,
		"選再玩一次直接回到遊戲，不繞標題與選角",
		"flow_state=%d" % main.flow_state)
	_expect(not menu.visible, "回到遊戲後結束選單收起來")
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

	# 逐類精確比對，不是拿總數用 >= 帶過。
	#
	# 舊的斷言是「節點總數 >= 關卡實體數」，而實際節點數遠大於實體數（還有
	# 地刺與三種節點化磚塊墊著）。結果是：_make_entity 對認不得的型別會靜靜
	# 回 null 再被 continue 略過，有人把 "checkpoint" 打成 "checkpont"，整關的
	# 檢查點會全部消失而總數仍然 >=，測試照樣綠。
	var wanted: Dictionary = {}
	for entity in map.entities:
		var group := _group_of(entity["type"])
		if group.is_empty():
			continue
		wanted[group] = int(wanted.get(group, 0)) + 1
	for group in wanted:
		var built := 0
		for node in get_tree().get_nodes_in_group(group):
			if not main.is_ancestor_of(node):
				continue
			# Boss 同時在 boss 與 enemy 兩個群組，算 enemy 時要扣掉，
			# 不然關卡寫 17 隻會數出 18 隻。
			if group == "enemy" and node.is_in_group("boss"):
				continue
			built += 1
		_expect(built == int(wanted[group]),
			"關卡裡的 %s 全部建出來了" % group,
			"關卡寫了 %d 個，場上只有 %d 個" % [wanted[group], built])
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


## 踩踏回彈要真的把玩家推上去，而且按住跳鍵要彈得更高。
##
## 舊的斷言是 is_equal_approx(player.velocity.y, PlayerPhysics.stomp_velocity(false))
## ——左右兩邊是同一個運算式，只驗證了「賦值敘述有執行」，任何行為都測不到。
## 真正值得驗的是連踩爬高那條路：apply_stomp 的參數是從
## Input.is_action_pressed("jump") 傳進來的，接錯了就再也踩不高。
func _check_stomp_bounce() -> void:
	var plain := await _measure_stomp_rise(false)
	var held := await _measure_stomp_rise(true)
	_expect(plain > 40.0, "踩踏會把玩家往上推", "只升高 %.0f px" % plain)
	_expect(held > plain * 1.15, "按住跳鍵踩踏會彈得明顯更高",
		"不按 %.0f px、按住 %.0f px" % [plain, held])


## 量測一次踩踏回彈能升多高。
func _measure_stomp_rise(hold_jump: bool) -> float:
	var main := await _make_main()
	main.begin_game()
	var player: Player = main.get_node("Player")
	for i in 60:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	var start_y := player.global_position.y
	# 跳鍵要真的按住，不能只把 true 傳進 apply_stomp。PlayerPhysics 的
	# jump-cut 會在下一個物理幀把「沒按住」的上升速度砍到 JUMP_CUT_VELOCITY，
	# 所以不按住的話兩種初速最後會爬到一樣高——連踩爬高靠的是持續按住。
	if hold_jump:
		Input.action_press("jump")
	player.apply_stomp(hold_jump)
	var highest := start_y
	for i in 90:
		await get_tree().physics_frame
		highest = minf(highest, player.global_position.y)
		if player.is_on_floor() and player.global_position.y >= start_y - 1.0:
			break
	if hold_jump:
		Input.action_release("jump")
	main.queue_free()
	await get_tree().process_frame
	return start_y - highest


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


## 在整個 Main 子樹裡找群組成員，而不是寫死 Entities 這個節點路徑。
##
## 寫死路徑的代價是：main.tscn 改一個節點名字，整份整合測試會靜靜地
## 找不到東西然後開始失敗，而錯誤訊息只會說「主關卡沒有牛奶」。
func _first_in_group(main: Node, group: String) -> Node2D:
	for node in get_tree().get_nodes_in_group(group):
		if node is Node2D and main.is_ancestor_of(node):
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


## 丟出去的金幣撞到問號磚要消失，不能穿過去。
##
## 舊的判斷只認 boss 群組、enemy 群組與 TileMapLayer 三種。問號磚、水管、
## 移動平台都是 collision_layer 1、會觸發 body_entered，卻三個分支都不成立——
## 金幣直接穿牆飛走。
func _check_coin_shot_stops_at_blocks() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var block: Node2D = _first_in_group(main, "block")
	if block == null:
		_fail("主關卡有問號磚")
		main.queue_free()
		await get_tree().process_frame
		return
	_ok("主關卡有問號磚")

	var shot: Node2D = load("res://scenes/coin_shot.tscn").instantiate()
	shot.global_position = block.global_position + Vector2(-100, 0)
	main.get_node("Entities").add_child(shot)
	shot.launch(1)
	var gone := false
	for i in 45:
		await get_tree().physics_frame
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			gone = true
			break
	_expect(gone, "金幣撞到問號磚就消失，不會穿過去")
	main.queue_free()
	await get_tree().process_frame


## 打死的敵人要立刻退出 enemy 群組。
##
## 玩家的接觸判定是每幀輪詢 enemy 群組的。屍體會停留 0.22 秒做淡出動畫，
## 這段期間如果還在群組裡，跑過去撞上它照樣會被扣血。
func _check_dead_enemy_stops_being_an_enemy() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var enemy: Node2D = _first_in_group(main, "enemy")
	if enemy == null:
		_fail("主關卡有敵人")
		main.queue_free()
		await get_tree().process_frame
		return
	_ok("主關卡有敵人")
	enemy.die()
	await get_tree().physics_frame
	_expect(not enemy.is_in_group("enemy"),
		"死掉的敵人立刻退出 enemy 群組，屍體不會再傷人")
	main.queue_free()
	await get_tree().process_frame


## headless 下複製成績要回報失敗，而且提示文字要說明失敗。
##
## 舊的斷言只檢查「提示文字非空」，而每個分支不論成敗都會 show_note——
## 那條斷言在任何情況下都會通過，連「headless 卻顯示已複製」都抓不到。
func _check_share_copy_reports_failure_in_headless() -> void:
	var main := await _make_main()
	main.begin_game()
	main.call("_advance", Flow.GOAL)
	await get_tree().process_frame
	var menu: EndMenu = main.get_node("EndMenu")
	main.call("_on_end_menu_chosen", "copy")
	await get_tree().process_frame
	var note := menu.current_note()
	_expect(note.contains("失敗") or note.contains("無法"),
		"headless 下複製成績說的是失敗，不是「已複製」", "提示是「%s」" % note)
	main.queue_free()
	await get_tree().process_frame


## 在選角畫面按空白鍵確認，主角不該在開場那一幀無故跳一下。
##
## _unhandled_input 在輸入派送階段執行，早於同一幀的物理步；確認之後
## control_enabled 立刻變 true，緊接著 Player 的 is_action_just_pressed("jump")
## 比對到同一個物理幀編號，於是回傳 true。
func _check_confirming_character_does_not_jump() -> void:
	var main := await _make_main()
	await _tap(KEY_SPACE)
	await _tap(KEY_SPACE)
	_expect(main.flow_state == Flow.PLAYING, "已經進入遊玩狀態")
	var player: Player = main.get_node("Player")
	_expect(player.velocity.y > -100.0,
		"確認選角不會被當成跳躍", "開場的 velocity.y=%.1f" % player.velocity.y)
	main.queue_free()
	await get_tree().process_frame


## ESC 要真的暫停：樹停住、選單出現、再按一次回到遊戲。
func _check_pause_stops_the_world() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var menu: PauseMenu = main.get_node("PauseMenu")
	var seconds_before: int = main.stats.seconds_left()

	await _tap(KEY_ESCAPE)
	_expect(menu.visible, "按 ESC 叫出暫停選單")
	_expect(get_tree().paused, "暫停選單開著時整棵樹是停的")

	for i in 20:
		await get_tree().process_frame
	_expect(main.stats.seconds_left() == seconds_before,
		"暫停期間計時不會繼續倒數",
		"%d -> %d" % [seconds_before, main.stats.seconds_left()])

	await _tap(KEY_ESCAPE)
	_expect(not menu.visible, "再按一次 ESC 收起暫停選單")
	_expect(not get_tree().paused, "繼續遊戲之後樹恢復運作")
	main.queue_free()
	await get_tree().process_frame


## 暫停選單開著時離開遊玩狀態，不能把樹永遠留在暫停。
func _check_pause_is_released_on_state_change() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	main.get_node("PauseMenu").open()
	_expect(get_tree().paused, "先把樹暫停起來")
	main.call("_advance", Flow.GOAL)
	await get_tree().process_frame
	_expect(not get_tree().paused, "通關之後樹不會卡在暫停")
	main.queue_free()
	await get_tree().process_frame


## 一局結束要把成績寫進最高分紀錄。
func _check_finishing_a_run_records_the_score() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	main.stats.add_score(7777)
	main.call("_advance", Flow.GOAL)
	await get_tree().process_frame
	_expect(main.save.best_score >= 7777,
		"通關的分數進了最高分紀錄", "best_score=%d" % main.save.best_score)
	main.queue_free()
	await get_tree().process_frame


## 關卡實體型別對應到它進場後所在的群組。
func _group_of(type: String) -> String:
	match type:
		"coin": return "coin"
		"goal": return "goal"
		"checkpoint": return "checkpoint"
		"pipe": return "pipe"
		"boss": return "boss"
		"platform_h", "platform_v": return "platform"
		"bear", "spikeball", "arrow": return "enemy"
	return ""


## Boss 血條只在 Boss 真的進畫面時才出現。
##
## Boss 在第 272 格，玩家從第 0 格開始。血條若一開場就掛著，那 272 格
## 它都是一個永遠不動的 UI——新手的解讀是「載入進度條卡住了」，而且
## 玩家自發截圖分享時畫面上永遠有個看起來壞掉的東西。
func _check_boss_health_bar_follows_the_boss() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var boss_row: Control = main.get_node("HUD/Boss")
	var boss: Node2D = _first_in_group(main, "boss")
	if boss == null:
		_fail("主關卡有 Boss（血條測試）")
		main.queue_free()
		await get_tree().process_frame
		return

	_expect(not boss_row.visible, "離 Boss 還很遠時血條不出現")

	# 傳送到 Boss 旁邊
	main.get_node("Player").enter_level(boss.global_position + Vector2(-200, 0))
	for i in 20:
		await get_tree().physics_frame
		if boss_row.visible:
			break
	_expect(boss_row.visible, "Boss 進畫面之後血條出現")
	_expect(is_equal_approx(main.get_node("HUD/Boss/BossBar").value, 1.0),
		"血條一開始是滿的",
		"value=%.2f" % main.get_node("HUD/Boss/BossBar").value)

	boss.take_shot()
	await get_tree().physics_frame
	_expect(main.get_node("HUD/Boss/BossBar").value < 1.0,
		"打中之後血條真的下降",
		"value=%.2f" % main.get_node("HUD/Boss/BossBar").value)
	main.queue_free()
	await get_tree().process_frame


## Boss 血條不該出現在標題與選角畫面上。
##
## 關卡在標題狀態就已經建好了（背景要看得到），所以 Boss 也在場上、
## 血條也被同步了一次。它得跟著上方那排數值一起收起來。
func _check_boss_health_bar_hidden_outside_gameplay() -> void:
	var main := await _make_main()
	var boss_row: Control = main.get_node("HUD/Boss")
	_expect(main.flow_state == Flow.TITLE, "先確認在標題畫面")
	_expect(not boss_row.visible, "標題畫面看不到 Boss 血條")

	await _tap(KEY_SPACE)
	_expect(not boss_row.visible, "選角畫面看不到 Boss 血條")

	await _tap(KEY_SPACE)
	await get_tree().physics_frame
	_expect(not boss_row.visible,
		"開始遊戲時 Boss 還在 272 格外，血條仍然不出現")
	main.queue_free()
	await get_tree().process_frame


## 通關記錄的剩餘秒數要是「通關當下」的，不是結算歸零之後的。
##
## stats.finish() 會把剩餘時間換成分數並清零，而記錄成績是在那之後——
## 於是最佳通關時間永遠記成 0 秒，標題畫面顯示「已通關（最佳剩餘 0 秒）」。
func _check_clear_time_is_recorded_before_the_bonus() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	main.save = SaveData.new()
	var seconds_at_goal: int = main.stats.seconds_left()
	_expect(seconds_at_goal > 0, "通關前還有剩餘時間",
		"seconds_left=%d" % seconds_at_goal)
	main.call("_advance", Flow.GOAL)
	await get_tree().process_frame
	_expect(main.save.best_time_left > 0,
		"通關紀錄留下的是通關當下的剩餘秒數",
		"記到 %d 秒（通關當下是 %d 秒）"
			% [main.save.best_time_left, seconds_at_goal])
	main.queue_free()
	await get_tree().process_frame


## 水管往返不能讓已經撿走的東西復活。
##
## 這是「修好水管會清空成績」時換來的另一個 bug：keep_stats=true 讓分數
## 延續，但 LevelBuilder.build 會清空並重建所有實體——分數保留、金幣復活，
## 於是進出水管就能無限刷分（實測 162 分/秒，而每 5000 分送一條命）。
## 最高分紀錄是全遊戲唯一的重玩動機，這個漏洞讓它失去意義。
func _check_pipe_does_not_respawn_collected_things() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame

	# 撿光主關卡的金幣
	for node in get_tree().get_nodes_in_group("coin"):
		if main.is_ancestor_of(node):
			main.stats.add_coin()
			node.queue_free()
	await get_tree().physics_frame
	var coins_left := _count_in(main, "coin")
	_expect(coins_left == 0, "先把金幣撿光", "還剩 %d 枚" % coins_left)
	var score_before: int = main.stats.score

	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管（復活測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	main.call("_return_to_level")
	await get_tree().physics_frame
	await get_tree().process_frame

	_expect(_count_in(main, "coin") == 0,
		"水管往返之後金幣沒有復活",
		"場上又出現 %d 枚金幣" % _count_in(main, "coin"))
	_expect(main.stats.score == score_before,
		"分數仍然延續", "%d -> %d" % [score_before, main.stats.score])
	main.queue_free()
	await get_tree().process_frame


## 打死的敵人也不能因為往返而復活。
func _check_pipe_does_not_respawn_enemies() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var before := _count_in(main, "enemy")
	var target := _first_stompable(main)
	if target == null:
		_fail("主關卡有可踩的敵人（復活測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	target.die()
	await get_tree().physics_frame
	await get_tree().physics_frame

	if not await _enter_pipe(main):
		_fail("主關卡有可進入的水管（敵人復活測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	main.call("_return_to_level")
	await get_tree().physics_frame
	await get_tree().process_frame
	_expect(_count_in(main, "enemy") < before,
		"水管往返之後敵人沒有復活",
		"打死前 %d 隻，往返後 %d 隻" % [before, _count_in(main, "enemy")])
	main.queue_free()
	await get_tree().process_frame


func _count_in(main: Node, group: String) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(group):
		if main.is_ancestor_of(node) and not node.is_queued_for_deletion():
			n += 1
	return n


## 小牛按丟金幣鍵要有回饋，不能靜靜地什麼都不做。
##
## 以前條件不成立時連訊號都不發：沒有音效、沒有動畫、數字不動。玩家的
## 結論是「這個鍵是壞的」，然後就再也沒按過——等他後來真的變大了，
## 早就放棄了。這不是「沒被發現」，是主動教玩家這個機制不存在。
func _check_small_player_gets_feedback_when_throwing() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var player: Player = main.get_node("Player")
	var hud: HUD = main.get_node("HUD")
	_expect(not player.state.is_big(), "先確認現在是小牛")

	# 用陣列當容器：GDScript 的 lambda 以值捕獲區域變數，
	# 直接寫 denied = true 只會改到 lambda 自己的複本。
	var denied := [false]
	player.throw_denied.connect(func(): denied[0] = true)
	await _tap_action("throw")
	await get_tree().physics_frame
	_expect(denied[0], "小牛按丟金幣會發出 throw_denied")
	_expect(not hud.get_node("Hint").text.is_empty(),
		"畫面上有一行說明為什麼丟不出來",
		"提示是「%s」" % hud.get_node("Hint").text)
	main.queue_free()
	await get_tree().process_frame


## 站在水管上要看得到「↓」，不然整個隱藏房間對第一次玩的人是不存在的。
func _check_pipe_shows_a_prompt() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var pipe: Node2D = _first_in_group(main, "pipe")
	if pipe == null:
		_fail("主關卡有水管（提示測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	var prompt: Control = pipe.get_node("Prompt")
	_expect(not prompt.visible, "還沒站上去時不顯示提示")

	main.get_node("Player").enter_level(pipe.global_position + Vector2(0, -40))
	for i in 30:
		await get_tree().physics_frame
		if prompt.visible:
			break
	_expect(prompt.visible, "站上水管會冒出「↓」提示")
	main.queue_free()
	await get_tree().process_frame


## 終點旗竿要比中途的檢查點顯眼，而且鎖住時要看得出是鎖住而不是畫壞了。
func _check_goal_reads_as_a_goal() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	var goal: Node2D = _first_in_group(main, "goal")
	var checkpoint: Node2D = _first_in_group(main, "checkpoint")
	if goal == null or checkpoint == null:
		_fail("主關卡有旗竿與檢查點（外觀測試）")
		main.queue_free()
		await get_tree().process_frame
		return
	var goal_sprite: Sprite2D = goal.get_node("Sprite")
	var cp_sprite: Sprite2D = checkpoint.get_node("Sprite")
	_expect(goal_sprite.scale.x > cp_sprite.scale.x,
		"終點旗竿畫得比檢查點大",
		"終點 %.2f、檢查點 %.2f" % [goal_sprite.scale.x, cp_sprite.scale.x])
	# Boss 還活著，所以現在是鎖住的
	_expect(is_equal_approx(goal_sprite.modulate.a, 1.0),
		"鎖住的終點不是靠變透明表現（透明看起來像沒畫完）",
		"alpha=%.2f" % goal_sprite.modulate.a)
	main.queue_free()
	await get_tree().process_frame


## 收集率的分母要包含暗房，而且真的會隨遊玩上升。
func _check_collect_percent_tracks_progress() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame

	var level := LevelMap.load_from("res://levels/level1.txt")
	var room := LevelMap.load_from("res://levels/level1_pipe_a.txt")
	var expected_coin: int = level.collectible_totals()["coin"] \
		+ room.collectible_totals()["coin"]
	_expect(main.stats.targets["coin"] == expected_coin,
		"收集率的分母把暗房也算進去了",
		"分母 %d，主關卡加暗房是 %d"
			% [main.stats.targets["coin"], expected_coin])
	_expect(main.stats.collect_percent() == 0, "開局收集率是 0")

	for node in get_tree().get_nodes_in_group("coin"):
		if main.is_ancestor_of(node):
			main.stats.add_coin()
	_expect(main.stats.collect_percent() > 0, "撿了金幣收集率會上升",
		"仍然是 %d%%" % main.stats.collect_percent())
	main.queue_free()
	await get_tree().process_frame


## 受傷會結束無傷，而且死亡重生不會把它洗掉。
func _check_flawless_survives_respawn() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	_expect(main.stats.flawless, "開局是無傷狀態")

	main.call("_on_damaged")
	await get_tree().physics_frame
	_expect(not main.stats.flawless, "受傷之後不再是無傷")

	await _die_by_falling(main)
	_expect(not main.stats.flawless, "死亡重生不會把受傷紀錄洗掉")
	main.queue_free()
	await get_tree().process_frame


## 結束畫面要看得到收集率——那是第二輪的理由。
func _check_end_menu_shows_collection() -> void:
	var main := await _make_main()
	main.begin_game()
	await get_tree().physics_frame
	main.stats.add_coin()
	main.call("_advance", Flow.GOAL)
	await get_tree().process_frame
	var detail: Label = main.get_node("EndMenu/Panel/Detail")
	_expect(detail.text.contains("收集率"),
		"結束畫面顯示收集率", "實際是「%s」" % detail.text)
	main.queue_free()
	await get_tree().process_frame
