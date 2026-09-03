extends Node2D

## 遊戲流程總控。所有狀態改變都在這裡發生——子節點只發訊號，不改別人的狀態。

const TILE := 64
const MAIN_LEVEL := "res://levels/level1.txt"

var stats := RunStats.new()

var _map: LevelMap
var _level_path := MAIN_LEVEL
var _spawn := Vector2.ZERO

@onready var _tiles: TileMapLayer = $Tiles
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Player


func _ready() -> void:
	if not ResourceLoader.exists(_level_path) and not FileAccess.file_exists(_level_path):
		_level_path = "res://levels/dev.txt"
	_load_level(_level_path)
	_connect_player()


func _load_level(path: String) -> void:
	_map = LevelMap.load_from(path)
	if not _map.is_valid():
		for message in _map.errors:
			push_error("關卡 %s：%s" % [path, message])
		return

	var result := LevelBuilder.build(_map, _tiles, _entities)
	_spawn = result["spawn_position"]
	stats = RunStats.new(_map.time_limit)
	_player.respawn_at(_spawn)
	_player.set_camera_bounds(result["level_size"])


func _connect_player() -> void:
	_player.coin_collected.connect(_on_coin_collected)
	_player.goal_reached.connect(_on_goal_reached)
	_player.hazard_touched.connect(_on_hazard_touched)
	_player.died.connect(_on_player_died)


func _on_coin_collected() -> void:
	stats.add_coin()


func _on_goal_reached() -> void:
	stats.finish()


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
