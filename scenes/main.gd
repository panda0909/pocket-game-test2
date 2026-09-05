class_name Main
extends Node2D

## 遊戲流程總控。所有狀態改變都在這裡發生——子節點只發訊號，不改別人的狀態。

const TILE := TileGlossary.SIZE
const MAIN_LEVEL := "res://levels/level1.txt"
## 死亡後畫面停頓多久才重生。表演本身在 Player.play_death()，
## 這裡只管停多久。
const DEATH_PAUSE := 0.9
## 剩幾秒開始警告。與 HUD 的變色門檻同一個來源。
const HURRY_SECONDS := HUD.HURRY_SECONDS

var stats := RunStats.new()
var save := SaveData.new()
var flow_state := Flow.TITLE
## 選到第幾隻主角。整局都用同一隻，死亡重生不會換人；
## 回到標題時保留上次的選擇當游標起點。
var character_index := Roster.DEFAULT_INDEX

var _map: LevelMap
var _level_path := MAIN_LEVEL
## 關卡起點（地圖上的 S）。每次載入主關卡都會重算。
var _spawn := Vector2.ZERO
## 玩家拿到的檢查點。與 _spawn 分開存，否則進一次水管就會被關卡起點蓋掉，
## 玩家吃了三面旗子再死一次，還是被丟回關卡最左邊。
var _checkpoint := Vector2.INF
## 進水管前站的位置。從暗房回來時要放回這裡，玩家才不會迷失方向。
var _return_position := Vector2.INF
var _in_room := false
var _death_pending := false
## 關卡檔壞掉時停在標題並說明，不要讓玩家掉進沒有地形的虛空。
var _level_broken := false

@onready var _tiles: TileMapLayer = $Tiles
@onready var _entities: Node2D = $Entities
@onready var _effects: Effects = $Effects
@onready var _player: Player = $Player
@onready var _hud: HUD = $HUD
@onready var _select: CharacterSelect = $CharacterSelect
@onready var _end_menu: EndMenu = $EndMenu
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	if not ResourceLoader.exists(_level_path) and not FileAccess.file_exists(_level_path):
		_level_path = "res://levels/dev.txt"
	save = SaveData.load_from_disk()
	_connect_player()
	_select.moved.connect(_on_select_moved)
	_select.confirmed.connect(_on_select_confirmed)
	_select.cancelled.connect(_on_select_cancelled)
	_end_menu.chosen.connect(_on_end_menu_chosen)
	_pause_menu.resumed.connect(_on_resumed)
	_pause_menu.quit_to_title.connect(_on_quit_to_title)
	_enter_state(Flow.TITLE)


## 載入一張關卡，回傳是否成功。
##
## keep_stats 必須由呼叫端明講，不要從 _in_room 推導。以前推導的寫法造成兩個
## bug：_return_to_level 與 _respawn 都在呼叫這裡之前就把 _in_room 設回 false，
## 於是從暗房走回來會重建 RunStats——分數金幣歸零、生命補滿，等於在暗房裡
## 死掉不用扣命。
func _load_level(path: String, spawn_override := Vector2.INF,
		keep_stats := false) -> bool:
	var map := LevelMap.load_from(path)
	if not map.is_valid():
		for message in map.errors:
			push_error("關卡 %s：%s" % [path, message])
		return false

	_map = map
	var result := LevelBuilder.build(_map, _tiles, _entities)
	# 分數與計時活在 Main，不隨關卡重建——進暗房不該把時間洗掉。
	if not keep_stats:
		stats = RunStats.new(_map.time_limit)
		# 角色的初始金幣。走 add_coin 會連分數一起加，所以直接設欄位。
		stats.coins = int(Roster.traits(character_index)["start_coins"])
	# 暗房沒有 S，關卡起點沿用主關卡的，回來時才找得到路。
	if not _map.is_room:
		_spawn = result.spawn_position
	var start := spawn_override if spawn_override.is_finite() \
		else result.spawn_position
	# 換場不是重生：保留變身狀態，不然按 ↓ 的瞬間大牛就變回小牛。
	_player.enter_level(start)
	_player.set_character(character_index)
	_player.set_camera_bounds(result.level_size)
	_connect_level_nodes()
	return true


## 玩家死亡後該站回哪裡：拿過檢查點就回檢查點，否則回關卡起點。
func _respawn_position() -> Vector2:
	return _checkpoint if _checkpoint.is_finite() else _spawn


## 關卡裡的節點是建構器生成的，Main 建完才接訊號。
## 子節點不知道 Main 存在，只管發訊號。
func _connect_level_nodes() -> void:
	for node in _entities.get_children():
		if node.is_in_group("block"):
			node.popped_coin.connect(_on_block_popped_coin)
			node.popped_milk.connect(_on_block_popped_milk)
		elif node.is_in_group("boss"):
			node.defeated.connect(_on_boss_defeated)
			node.spawned_projectile.connect(_on_boss_projectile)
			node.health_changed.connect(_hud.set_boss_health)
			node.hit_absorbed.connect(_on_boss_hit_absorbed)
			# 主動問一次現況。Boss 的 _ready() 在 LevelBuilder 把它加進樹的當下
			# 就發過 health_changed 了，而這裡是建構完才接線——那一次發射沒有
			# 任何人聽到。訊號只送「之後的變化」，初始狀態要接線方自己拿。
			_hud.set_boss_health(BossRules.health_ratio(node.hp))

	# Boss 還活著時旗竿不能碰。不然玩家可以直接繞過關底衝終點。
	_set_goal_active(get_tree().get_nodes_in_group("boss").is_empty())
	if get_tree().get_nodes_in_group("boss").is_empty():
		_hud.hide_boss_health()


func _set_goal_active(active: bool) -> void:
	for node in get_tree().get_nodes_in_group("goal"):
		node.set_active(active)


## 打中了但在無敵幀內。玩家原本完全分不出這和真的扣血的差別。
func _on_boss_hit_absorbed() -> void:
	Audio.play("bump")


func _on_boss_defeated() -> void:
	Audio.play("boss_down")
	_hud.hide_boss_health()
	stats.add_score(BossRules.SCORE)
	_set_goal_active(true)


func _on_boss_projectile(origin: Vector2, direction: Vector2) -> void:
	_effects.boss_projectile(origin, direction)


func _on_block_popped_coin(world_position: Vector2) -> void:
	stats.add_coin()
	_effects.coin_pop(world_position)


## 牛奶的落點由關卡資料決定，實際生成交給 Effects。
func _on_block_popped_milk(cell: Vector2i) -> void:
	_effects.drop_milk(cell, _map)


func _connect_player() -> void:
	_player.coin_collected.connect(_on_coin_collected)
	_player.goal_reached.connect(_on_goal_reached)
	_player.enemy_stomped.connect(_on_enemy_stomped)
	_player.damaged.connect(_on_damaged)
	_player.died.connect(_on_player_died)
	_player.milk_collected.connect(_on_milk_collected)
	_player.throw_requested.connect(_on_throw_requested)
	_player.pipe_entered.connect(_on_pipe_entered)
	_player.checkpoint_reached.connect(_on_checkpoint_reached)


func _on_coin_collected() -> void:
	stats.add_coin()
	_effects.score_popup(_player.global_position + Vector2(0, -80),
		RunStats.COIN_SCORE)


func _on_goal_reached() -> void:
	_advance(Flow.GOAL)


## 進水管。暗房是另一張關卡檔，整張換掉；分數與計時延續。
func _on_pipe_entered(target: String) -> void:
	if target.is_empty():
		return
	if target == "__return__":
		_return_to_level()
		return
	var back := _player.global_position
	var room_path := "res://levels/%s.txt" % target
	var entry := _room_entry(room_path)
	# 旗標只在真的換場成功之後才翻。以前先設 _in_room = true 再載入，
	# 暗房檔壞掉時畫面完全沒變，旗標卻永久卡在 true——之後檢查點全部失效。
	if not _load_level(room_path, entry, true):
		return
	_return_position = back
	_in_room = true


## 暗房的落點由關卡自己的中繼資料 entry: x,y 指定。
## 以前寫死成 Vector2(160, 448)，那是專為現在這張 20x8 暗房算出來的像素座標——
## 換一張形狀不同的暗房，玩家就會生在牆裡或半空中。
func _room_entry(room_path: String) -> Vector2:
	var room := LevelMap.load_from(room_path)
	if not room.is_valid():
		return Vector2.INF
	var raw := str(room.meta.get("entry", ""))
	var parts := raw.split(",")
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() \
			or not parts[1].strip_edges().is_valid_int():
		push_error("暗房 %s 缺少 entry: x,y 中繼資料" % room_path)
		return Vector2.INF
	return LevelBuilder.cell_bottom(Vector2i(
		int(parts[0].strip_edges()), int(parts[1].strip_edges())))


func _return_to_level() -> void:
	if not _in_room:
		return
	# 放在原水管右邊一格，免得一回來就又踩進管口無限往返
	if not _load_level(_level_path,
			_return_position + Vector2(LevelBuilder.TILE, 0), true):
		return
	_in_room = false
	_return_position = Vector2.INF


## 檢查點的識別靠節點本身，不是座標。
##
## 以前是拿 Vector2 做精確相等比對去找是哪一支旗子——只因為那個值是從
## area.global_position 原封不動傳回來的才成立。任何一天在中途做了座標
## 換算或加了偏移，旗子就再也不會變色，而且不會有任何錯誤訊息。
func _on_checkpoint_reached(world_position: Vector2) -> void:
	if _in_room:
		return
	_checkpoint = world_position
	for node in get_tree().get_nodes_in_group("checkpoint"):
		if is_ancestor_of(node) and node.global_position.is_equal_approx(world_position):
			node.mark_taken()


## 玩家按了丟金幣。條件由 ThrowRules 判定——體型不對或沒彈藥時
## 不生成投射物，也不扣任何東西。
func _on_throw_requested(direction: int, origin: Vector2) -> void:
	if not ThrowRules.fire(_player.state, stats):
		return
	Audio.play("throw")
	var shot := _effects.coin_shot(origin, direction)
	shot.hit_enemy.connect(_on_enemy_stomped)
	shot.hit_boss.connect(_on_boss_shot)


## 金幣打中 Boss。以前這裡是個空的 pass——訊號接了卻什麼都不做，
## 而玩家最需要的正是「這一發有沒有生效」的回饋。
func _on_boss_shot() -> void:
	Audio.play("boss_hit")


func _on_milk_collected() -> void:
	if _player.grow() == PlayerState.BONUS:
		stats.add_milk_bonus()
		_effects.score_popup(_player.global_position + Vector2(0, -110),
			RunStats.MILK_BONUS_SCORE)


func _on_enemy_stomped(kind: int) -> void:
	var amount := EnemyRules.score(kind)
	stats.add_score(amount)
	_effects.score_popup(_player.global_position + Vector2(0, -80), amount)


func _on_damaged() -> void:
	_player.take_hit()


func _on_player_died() -> void:
	_kill_player()


## 掉出關卡下緣即死。用關卡高度加一格當界線，玩家看得到自己掉下去。
func _physics_process(_delta: float) -> void:
	if not Flow.counts_down(flow_state) or _map == null:
		return
	if _player.global_position.y > _map.pixel_size(TILE).y + TILE:
		_kill_player()


## --- 流程 ---

func _unhandled_input(event: InputEvent) -> void:
	# 暫停優先。樹被暫停之後 Main 就收不到輸入了，繼續遊戲那一下由
	# PauseMenu 自己處理（它的 process_mode 是 ALWAYS）。
	if event.is_action_pressed("pause") and flow_state == Flow.PLAYING:
		get_viewport().set_input_as_handled()
		_pause_menu.open()
		return

	# 選角畫面要吃走左右鍵，所以它先於 jump 的判斷處理。
	if flow_state == Flow.SELECT:
		_select.handle_action(event)
		return
	if flow_state == Flow.GAME_OVER or flow_state == Flow.CLEARED:
		_end_menu.handle_action(event)
		return
	if not event.is_action_pressed("jump"):
		return
	if flow_state == Flow.TITLE and not _level_broken:
		_advance(Flow.START)


func _on_resumed() -> void:
	# 暫停選單吃掉了那一下按鍵，但玩家放開之前不該被當成新的輸入。
	_player.begin_control()


func _on_quit_to_title() -> void:
	_advance(Flow.RESTART) if flow_state != Flow.PLAYING else _enter_state(Flow.TITLE)


func _on_select_moved(direction: int) -> void:
	character_index = Roster.cycle(character_index, direction)
	_select.show_index(character_index)


func _on_select_confirmed() -> void:
	_player.set_character(character_index)
	_advance(Flow.CONFIRM)


func _on_select_cancelled() -> void:
	_advance(Flow.BACK)


## 結束畫面的四個動作。分享失敗時明說，不假裝成功——
## 瀏覽器擋彈出視窗或不給剪貼簿權限都是常見情況。
func _on_end_menu_chosen(action: String) -> void:
	var cleared := flow_state == Flow.CLEARED
	var message := ShareText.full_message(stats, character_index, cleared)
	match action:
		"facebook":
			if ShareBridge.open_url(ShareText.facebook_url()):
				_end_menu.show_note("正在開啟 Facebook 分享（若沒有新分頁，會直接跳轉過去）")
			else:
				_end_menu.show_note("這個版本不是網頁版，無法開啟分享視窗")
		"threads":
			if ShareBridge.open_url(ShareText.threads_url(message)):
				_end_menu.show_note("正在開啟 Threads，文字已經幫你填好了")
			else:
				_end_menu.show_note("這個版本不是網頁版，無法開啟分享視窗")
		"copy":
			if ShareBridge.copy_to_clipboard(message):
				_end_menu.show_note("成績文字已複製，貼到 Instagram 就好")
			else:
				_end_menu.show_note("複製失敗，請手動選取下面這段文字：%s" % message)
		"again":
			_advance(Flow.RESTART)


func _process(delta: float) -> void:
	if not Flow.counts_down(flow_state):
		return
	var before := stats.seconds_left()
	if stats.tick(delta):
		_kill_player()
	# 跨過警告線的那一秒響一次，不是每幀都響。
	if before > HURRY_SECONDS and stats.seconds_left() <= HURRY_SECONDS:
		Audio.play("hurry")
	_hud.update_stats(stats, _player.state.is_big())


func _advance(event: String) -> void:
	var next := Flow.next(flow_state, event, stats.lives)
	if next == flow_state and event != Flow.DIED:
		return
	_enter_state(next, event)


func _enter_state(state: int, event := "") -> void:
	# 任何狀態轉換都先解除暫停。暫停選單開著時若因為別的路徑
	# 離開了遊玩狀態，樹會永遠停在 paused。
	if _pause_menu.visible:
		_pause_menu.close()
	flow_state = state
	if Flow.accepts_input(state):
		_player.begin_control()
	else:
		_player.control_enabled = false
	_select.visible = state == Flow.SELECT
	_end_menu.visible = state == Flow.GAME_OVER or state == Flow.CLEARED
	_hud.set_stats_visible(state != Flow.TITLE and state != Flow.SELECT)
	match state:
		Flow.TITLE:
			_hud.reset_cache()
			_restart_run()
			if _level_broken:
				_hud.show_message("關卡載入失敗",
					"%s 讀不起來，請看主控台的錯誤訊息" % _level_path)
			else:
				Audio.stop_music()
				_hud.show_message("口袋牛牛大冒險", _title_subtitle())
		Flow.SELECT:
			_hud.hide_message()
			_select.show_index(character_index)
		Flow.PLAYING:
			_hud.hide_message()
			Audio.play_music()
			if event == Flow.DIED:
				_respawn()
		Flow.GAME_OVER:
			Audio.stop_music()
			_hud.hide_message()
			_record_run(false)
			_end_menu.show_result(false, stats.score, stats.coins)
		Flow.CLEARED:
			Audio.stop_music()
			Audio.play("clear")
			stats.finish()
			_hud.hide_message()
			_record_run(true)
			_end_menu.show_result(true, stats.score, stats.coins)
	_hud.update_stats(stats, _player.state.is_big())


## 把這一局記進最高分紀錄。
## 標題畫面的第二行。有紀錄就先報紀錄——刷分要有對照組才有意義。
func _title_subtitle() -> String:
	var controls := "空白鍵開始　方向鍵／WASD 移動　空白／↑ 跳　Shift 衝刺　J 丟金幣　↓ 進水管　ESC 暫停"
	if save.best_score <= 0:
		return controls
	var record := "最高分 %d　金幣 %d 枚" % [save.best_score, save.best_coins]
	if save.cleared:
		record += "　已通關（最佳剩餘 %d 秒）" % save.best_time_left
	return record + "\n" + controls


## 把這一局記進最高分紀錄。
func _record_run(cleared: bool) -> void:
	if save.record_run(stats.score, stats.coins, cleared, stats.seconds_left()):
		_end_menu.show_note("新紀錄！上一個最高分是 %d" % save.best_score)
	save.save_to_disk()


func _restart_run() -> void:
	_in_room = false
	_return_position = Vector2.INF
	_checkpoint = Vector2.INF
	# 新的一局：這是唯一該重建 RunStats 的地方。
	_level_broken = not _load_level(_level_path)


func _respawn() -> void:
	if _in_room:
		# 在暗房裡死掉要回到主關卡，但成績要延續——扣掉的那條命不能被補回來。
		if _load_level(_level_path, Vector2.INF, true):
			_in_room = false
			_return_position = Vector2.INF
	stats.restart_level()
	_player.respawn_at(_respawn_position())


## 死亡統一走這裡：先扣命再問流程要去哪，順序反了會出現
## 「明明還有命卻結束了」這種最惱人的 bug。
func _kill_player() -> void:
	if _death_pending or not Flow.counts_down(flow_state):
		return
	_death_pending = true
	Audio.play("death")
	stats.lose_life()
	_player.play_death()
	_hud.show_message("", "剩餘 %d 條命" % stats.lives if stats.lives > 0 else "沒有命了")
	await get_tree().create_timer(DEATH_PAUSE).timeout
	_player.revive()
	_hud.hide_message()
	_death_pending = false
	# 這 0.9 秒裡屍體還帶著慣性，可能滑進旗竿而進入 CLEARED。
	# 這時再送一次 DIED 會讓結束畫面重跑一遍，游標與提示文字被洗掉。
	if not Flow.counts_down(flow_state):
		return
	_advance(Flow.DIED)


# --- 開發工具用（tools/capture.gd）---

## 只走到選角畫面就停，供擷圖確認。
func begin_game_to_select() -> void:
	if _level_broken:
		return
	if flow_state == Flow.TITLE:
		_advance(Flow.START)


func begin_game(index := -1) -> void:
	if _level_broken:
		return
	if index >= 0:
		character_index = Roster.clamp_index(index)
	if flow_state == Flow.TITLE:
		_advance(Flow.START)
	if flow_state == Flow.SELECT:
		_on_select_confirmed()


func teleport_player(cells: int) -> void:
	_player.respawn_at(_spawn + Vector2(cells * TILE, 0))


func debug_grant_powerup(coins: int) -> void:
	_player.grow()
	for i in coins:
		stats.add_coin()


func debug_summary() -> String:
	return "角色=%s 分數=%d 金幣=%d 生命=%d 時間=%d 實體=%d" % [
		Roster.name_of(character_index), stats.score, stats.coins,
		stats.lives, stats.seconds_left(), _entities.get_child_count(),
	]
