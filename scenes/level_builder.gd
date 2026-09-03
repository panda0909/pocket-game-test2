class_name LevelBuilder
extends RefCounted

## 把 LevelMap 的純資料變成場景樹上的東西：地形進 TileMapLayer，
## 其他一切各自生成節點。
##
## TileSet 是用程式建的，不是在編輯器裡拉的。這樣關卡資料、字元語意、
## 圖集欄位三者的對應關係全部寫在程式裡看得到，也不需要開圖形介面才能改。
##
## 只有「站得住又不會互動」的格子進 TileMapLayer。問號磚、牛奶磚、可破磚
## 都得各自記住「被頂過了沒」，那是節點的工作，不是圖磚的工作。

const TILE := 64
const SOURCE_ID := 0

const COIN_SCENE := preload("res://scenes/coin.tscn")
const GOAL_SCENE := preload("res://scenes/goal_flag.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BLOCK_SCENE := preload("res://scenes/question_block.tscn")
const PLATFORM_SCENE := preload("res://scenes/moving_platform.tscn")
const PIPE_SCENE := preload("res://scenes/pipe.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/checkpoint.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")

## 進 TileMapLayer 的地形。尖刺也進，但不給碰撞多邊形——它靠 Area2D 傷人，
## 玩家該踩得進去而不是站在上面。
const TILEMAP_KINDS := [
	TileGlossary.KIND_GROUND,
	TileGlossary.KIND_BRICK,
	TileGlossary.KIND_SPIKE,
]


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


## 格子底邊中央。站在地上的東西用這個當原點，才會剛好貼著地面。
static func cell_bottom(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, (cell.y + 1) * TILE)


static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/tiles.png")
	source.texture_region_size = Vector2i(TILE, TILE)
	# 先掛進 TileSet 再建圖磚。圖磚的實體層是從所屬 TileSet 繼承來的，
	# 順序反過來的話 set_collision_polygon_points 會說 layer 0 越界。
	tile_set.add_source(source, SOURCE_ID)

	var columns := int(source.texture.get_width() / TILE)
	for column in columns:
		var coords := Vector2i(column, 0)
		source.create_tile(coords)
		if column == TileGlossary.atlas_column(TileGlossary.KIND_SPIKE):
			continue
		var data := source.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-TILE * 0.5, -TILE * 0.5),
			Vector2(TILE * 0.5, -TILE * 0.5),
			Vector2(TILE * 0.5, TILE * 0.5),
			Vector2(-TILE * 0.5, TILE * 0.5),
		]))

	return tile_set


## 建構整張關卡。回傳 Main 需要知道的資訊。
static func build(map: LevelMap, tile_layer: TileMapLayer,
		entity_root: Node2D) -> Dictionary:
	tile_layer.clear()
	if tile_layer.tile_set == null:
		tile_layer.tile_set = build_tileset()
	for child in entity_root.get_children():
		child.queue_free()

	var built := 0
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var kind := map.terrain_at(cell)
			if BlockRules.needs_node(kind):
				var block := BLOCK_SCENE.instantiate()
				block.setup(kind)
				block.position = cell_center(cell)
				entity_root.add_child(block)
				built += 1
				continue
			if not TILEMAP_KINDS.has(kind):
				continue
			tile_layer.set_cell(cell, SOURCE_ID,
				Vector2i(TileGlossary.atlas_column(kind), 0), 0)
			if kind == TileGlossary.KIND_SPIKE:
				entity_root.add_child(_make_hazard(cell))
				built += 1

	for entity in map.entities:
		var node := _make_entity(entity)
		if node == null:
			continue
		entity_root.add_child(node)
		built += 1

	return {
		"spawn_position": cell_bottom(map.spawn),
		"level_size": map.pixel_size(TILE),
		"entities_built": built,
	}


static func _make_hazard(cell: Vector2i) -> Area2D:
	var area := Area2D.new()
	area.name = "Spike%d_%d" % [cell.x, cell.y]
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("hazard")
	# 傷害範圍刻意比整格小：尖刺只有上半格真的有刺，貼著旁邊走過去不該受傷。
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE - 12, TILE * 0.5)
	shape.shape = rect
	shape.position = Vector2(0, TILE * 0.25)
	area.add_child(shape)
	area.position = cell_center(cell)
	return area


static func _make_entity(entity: Dictionary) -> Node2D:
	var type: String = entity["type"]
	var cell: Vector2i = entity["cell"]

	match type:
		"coin":
			var coin := COIN_SCENE.instantiate()
			coin.position = cell_center(cell)
			return coin
		"goal":
			var goal := GOAL_SCENE.instantiate()
			goal.position = cell_bottom(cell)
			return goal
		"bear", "spikeball", "arrow":
			var enemy := ENEMY_SCENE.instantiate()
			enemy.setup(EnemyRules.kind_from_type(type))
			# 刺球與箭頭懸空，站在格子中央；小熊站在格子底邊。
			enemy.position = cell_bottom(cell) if type == "bear" \
				else cell_center(cell)
			return enemy
		"platform_h", "platform_v":
			var platform := PLATFORM_SCENE.instantiate()
			platform.setup(type == "platform_v")
			platform.position = cell_center(cell)
			return platform
		"pipe":
			var pipe := PIPE_SCENE.instantiate()
			pipe.setup(str(entity["params"].get("target", "")))
			pipe.position = cell_center(cell)
			return pipe
		"checkpoint":
			var checkpoint := CHECKPOINT_SCENE.instantiate()
			checkpoint.position = cell_bottom(cell)
			return checkpoint
		"boss":
			var boss := BOSS_SCENE.instantiate()
			boss.position = cell_bottom(cell)
			return boss
	return null
