extends Node2D

## 遊戲流程總控。所有狀態改變都在這裡發生——子節點只發訊號，不改別人的狀態。

const TILE := 64
const MAIN_LEVEL := "res://levels/level1.txt"
const POWERUP_SCENE := preload("res://scenes/powerup.tscn")
const COIN_TEXTURE := preload("res://assets/coin.png")
const COIN_SHOT_SCENE := preload("res://scenes/coin_shot.tscn")

## 頂出來的金幣飛多高、飛多久。飛完就消失，不必玩家再去撿——
## 他已經頂到了，再讓他追一顆金幣只是多餘的操作。
const COIN_POP_HEIGHT := 96.0
const COIN_POP_TIME := 0.45

var stats := RunStats.new()

var _map: LevelMap
var _level_path := MAIN_LEVEL
var _spawn := Vector2.ZERO
## 進水管前站的位置。從暗房回來時要放回這裡，玩家才不會迷失方向。
var _return_position := Vector2.INF
var _in_room := false

@onready var _tiles: TileMapLayer = $Tiles
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Player


func _ready() -> void:
	if not ResourceLoader.exists(_level_path) and not FileAccess.file_exists(_level_path):
		_level_path = "res://levels/dev.txt"
	_load_level(_level_path)
	_connect_player()


func _load_level(path: String, spawn_override := Vector2.INF) -> void:
	var map := LevelMap.load_from(path)
	if not map.is_valid():
		for message in map.errors:
			push_error("關卡 %s：%s" % [path, message])
		return

	_map = map
	var result := LevelBuilder.build(_map, _tiles, _entities)
	# 分數與計時活在 Main，不隨關卡重建——進暗房不該把時間洗掉。
	if not _in_room:
		stats = RunStats.new(_map.time_limit)
	_spawn = result["spawn_position"] if not _map.is_room else spawn_override
	var start: Vector2 = spawn_override if spawn_override.is_finite() \
		else result["spawn_position"]
	_player.respawn_at(start)
	_player.set_camera_bounds(result["level_size"])
	_connect_level_nodes()


## 關卡裡的節點是建構器生成的，Main 建完才接訊號。
## 子節點不知道 Main 存在，只管發訊號。
func _connect_level_nodes() -> void:
	for node in _entities.get_children():
		if node.is_in_group("block"):
			node.popped_coin.connect(_on_block_popped_coin)
			node.popped_milk.connect(_on_block_popped_milk)


func _on_block_popped_coin(position: Vector2) -> void:
	stats.add_coin()
	_spawn_coin_pop(position)


func _on_block_popped_milk(position: Vector2) -> void:
	var milk := POWERUP_SCENE.instantiate()
	milk.position = position
	_entities.add_child(milk)


func _spawn_coin_pop(position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = COIN_TEXTURE
	sprite.position = position
	_entities.add_child(sprite)
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", position.y - COIN_POP_HEIGHT,
		COIN_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, COIN_POP_TIME)
	tween.chain().tween_callback(sprite.queue_free)


func _connect_player() -> void:
	_player.coin_collected.connect(_on_coin_collected)
	_player.goal_reached.connect(_on_goal_reached)
	_player.hazard_touched.connect(_on_hazard_touched)
	_player.enemy_stomped.connect(_on_enemy_stomped)
	_player.enemy_touched.connect(_on_hazard_touched)
	_player.died.connect(_on_player_died)
	_player.milk_collected.connect(_on_milk_collected)
	_player.throw_requested.connect(_on_throw_requested)
	_player.pipe_entered.connect(_on_pipe_entered)
	_player.checkpoint_reached.connect(_on_checkpoint_reached)


func _on_coin_collected() -> void:
	stats.add_coin()


func _on_goal_reached() -> void:
	stats.finish()


## 進水管。暗房是另一張關卡檔，整張換掉；分數與計時延續。
func _on_pipe_entered(target: String) -> void:
	if target.is_empty():
		return
	if target == "__return__":
		_return_to_level()
		return
	_return_position = _player.global_position
	_in_room = true
	_load_level("res://levels/%s.txt" % target, Vector2(160, 448))


func _return_to_level() -> void:
	if not _in_room:
		return
	_in_room = false
	var back := _return_position
	_return_position = Vector2.INF
	# 放在原水管右邊一格，免得一回來就又踩進管口無限往返
	_load_level(_level_path, back + Vector2(LevelBuilder.TILE, 0))


func _on_checkpoint_reached(position: Vector2) -> void:
	if _in_room:
		return
	_spawn = position
	for node in _entities.get_children():
		if node.is_in_group("checkpoint") and node.global_position == position:
			node.mark_taken()


## 玩家按了丟金幣。條件由 ThrowRules 判定——體型不對或沒彈藥時
## 不生成投射物，也不扣任何東西。
func _on_throw_requested(direction: int, origin: Vector2) -> void:
	if not ThrowRules.fire(_player.state, stats):
		return
	var shot := COIN_SHOT_SCENE.instantiate()
	shot.position = origin
	_entities.add_child(shot)
	shot.launch(direction)
	shot.hit_enemy.connect(_on_enemy_stomped)


func _on_milk_collected() -> void:
	if _player.grow() == "bonus":
		stats.add_milk_bonus()


func _on_enemy_stomped(kind: int) -> void:
	stats.add_score(EnemyRules.score(kind))


func _on_hazard_touched() -> void:
	_player.take_hit()


func _on_player_died() -> void:
	stats.lose_life()
	_player.respawn_at(_spawn)


# --- 開發工具用（tools/capture.gd）---

func begin_game() -> void:
	pass


func teleport_player(cells: int) -> void:
	_player.respawn_at(_spawn + Vector2(cells * TILE, 0))


func debug_grant_powerup(coins: int) -> void:
	_player.grow()
	for i in coins:
		stats.add_coin()


func debug_summary() -> String:
	return "分數=%d 金幣=%d 生命=%d 時間=%d 實體=%d" % [
		stats.score, stats.coins, stats.lives, stats.seconds_left(),
		_entities.get_child_count(),
	]
