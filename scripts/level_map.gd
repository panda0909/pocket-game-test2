class_name LevelMap
extends RefCounted

## 把純文字關卡檔解析成資料。不碰場景樹，因此可以完整單元測試。
##
## 為什麼關卡是文字檔而不是 Godot 的 TileMap 場景：文字檔能 diff、能在
## code review 裡看出「這個坑變寬了兩格」，改一個字元就能試手感，而且不需要
## 圖形編輯器就能排版。代價是要自己維護一張字元表，那張表就是 TileGlossary。
##
## 格式：
##     key: value        中繼資料，一行一組
##     ---               分界線
##     <地圖>            一字元一格，左上角是 (0, 0)
##
## 地圖的最後一行對齊關卡底部；建構器負責把格子座標換成像素座標。

## 中繼資料 room: true 的關卡是水管隱藏房，沒有起點與終點，
## 落點由 Main 指定，所以跳過那兩條驗證。
const SEPARATOR := "---"
const DEFAULT_TIME := 300

var errors: Array[String] = []
var width := 0
var height := 0
## terrain[y][x]，y 由上到下
var terrain: Array = []
## 每項 {"type": String, "cell": Vector2i, "params": Dictionary}
var entities: Array[Dictionary] = []
var meta: Dictionary = {}
var spawn := Vector2i.ZERO
var time_limit := DEFAULT_TIME
var level_name := ""
var is_room := false


static func parse(text: String) -> LevelMap:
	var map := LevelMap.new()
	map._parse(text)
	return map


static func load_from(path: String) -> LevelMap:
	if not FileAccess.file_exists(path):
		var map := LevelMap.new()
		map.errors.append("找不到關卡檔 %s" % path)
		return map
	return LevelMap.parse(FileAccess.get_file_as_string(path))


func is_valid() -> bool:
	return errors.is_empty()


## 越界回空格，讓建構器與測試不必自己檢查邊界。
func terrain_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= terrain.size():
		return TileGlossary.KIND_EMPTY
	var row: Array = terrain[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return TileGlossary.KIND_EMPTY
	return row[cell.x]


## 關卡的像素尺寸，供相機夾邊界用。
func pixel_size(tile: int) -> Vector2:
	return Vector2(width * tile, height * tile)


func _parse(text: String) -> void:
	var lines := text.replace("\r\n", "\n").split("\n")
	var map_lines := _split_header(lines)
	_read_meta()
	_read_map(map_lines)
	_validate()


## 切出中繼資料與地圖兩段，回傳地圖行。找不到分界線就把全部當地圖——
## 這讓測試可以只寫地圖，不必每次都補標頭。
func _split_header(lines: PackedStringArray) -> PackedStringArray:
	var sep := -1
	for i in lines.size():
		if lines[i].strip_edges() == SEPARATOR:
			sep = i
			break
	if sep < 0:
		return lines

	for i in sep:
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(":", true, 1)
		if parts.size() != 2:
			errors.append("中繼資料第 %d 行不是 key: value 格式：%s" % [i + 1, line])
			continue
		meta[parts[0].strip_edges()] = parts[1].strip_edges()

	return lines.slice(sep + 1)


func _read_meta() -> void:
	level_name = str(meta.get("name", ""))
	is_room = str(meta.get("room", "")).to_lower() == "true"

	var raw_time := str(meta.get("time", ""))
	if raw_time.is_empty():
		time_limit = DEFAULT_TIME
	elif raw_time.is_valid_int() and int(raw_time) > 0:
		time_limit = int(raw_time)
	else:
		errors.append("time 必須是正整數，收到「%s」" % raw_time)
		time_limit = DEFAULT_TIME


func _read_map(map_lines: PackedStringArray) -> void:
	# 尾端的空行是編輯器留下的，不算關卡高度；中間的空行是真的空中走廊，要留。
	var rows: Array[String] = []
	for line in map_lines:
		rows.append(line)
	while not rows.is_empty() and rows[rows.size() - 1].strip_edges().is_empty():
		rows.remove_at(rows.size() - 1)

	height = rows.size()
	for row in rows:
		width = maxi(width, row.length())

	var spawn_count := 0
	var goal_count := 0

	for y in height:
		var row: String = rows[y]
		var cells: Array = []
		cells.resize(width)
		cells.fill(TileGlossary.KIND_EMPTY)
		for x in width:
			var ch := " " if x >= row.length() else row[x]
			var kind := TileGlossary.terrain_kind(ch)
			if kind >= 0:
				cells[x] = kind
				continue

			var type := TileGlossary.entity_type(ch)
			if type.is_empty():
				errors.append("第 %d 行第 %d 欄有未知字元「%s」" % [y + 1, x + 1, ch])
				continue

			if type == "spawn":
				spawn = Vector2i(x, y)
				spawn_count += 1
				continue
			if type == "goal" or type == "boss":
				goal_count += 1

			entities.append({
				"type": type,
				"cell": Vector2i(x, y),
				"params": _entity_params(ch, type),
			})
		terrain.append(cells)

	if not is_room:
		if spawn_count != 1:
			errors.append("關卡必須恰好有一個起點 S，實際有 %d 個" % spawn_count)
		if goal_count < 1:
			errors.append("關卡必須至少有一個終點 F 或 Boss K")


func _entity_params(ch: String, type: String) -> Dictionary:
	if type != "pipe":
		return {}
	var index := TileGlossary.pipe_index(ch)
	var key := "pipe%d" % index
	if not meta.has(key):
		errors.append("水管 %d 沒有對應的中繼資料 %s" % [index, key])
	return {"index": index, "target": str(meta.get(key, ""))}


func _validate() -> void:
	if height == 0 or width == 0:
		errors.append("關卡是空的")
