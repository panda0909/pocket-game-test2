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
## 關卡檔損毀成亂碼時，每格一則錯誤會產生數千則字串，Main 再逐則
## push_error，在 Web 版會明顯凍結。超過就收成一行總結。
const MAX_CHAR_ERRORS := 20

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


## 往下找第一格實心地面的列號。整欄都沒有地面（磚塊架在坑上）時回關卡
## 底部，玩家至少看得到東西掉下去。
##
## 這段和 drift_direction 原本寫在 main.gd 上——是純資料運算卻掛在 Node2D
## 上，於是完全進不了單元測試，牛奶掉錯格只能靠跑整個場景才發現。
func ground_surface_row_below(cell: Vector2i) -> int:
	for row in range(cell.y + 1, height):
		if TileGlossary.is_solid(terrain_at(Vector2i(cell.x, row))):
			return row
	return height


## 頂出來的東西往哪邊滑。右邊有實心而左邊沒有就往左，其餘往右——
## 差別只在觀感，落點高度已經由 ground_surface_row_below 保證站得到。
func drift_direction(cell: Vector2i) -> int:
	var right_blocked := TileGlossary.is_solid(
		terrain_at(Vector2i(cell.x + 1, cell.y)))
	var left_blocked := TileGlossary.is_solid(
		terrain_at(Vector2i(cell.x - 1, cell.y)))
	if right_blocked and not left_blocked:
		return -1
	return 1


## 這張關卡總共有多少可收集／可打倒的東西。收集率用它當分母。
##
## 問號磚也算金幣（頂一下就噴一枚），牛奶磚自己一類，Boss 算敵人。
## 純資料運算，所以「關卡改了分母會不會跟著變」有測試守著。
func collectible_totals() -> Dictionary:
	var totals := {"coin": 0, "enemy": 0, "milk": 0}
	for y in height:
		for x in width:
			var kind := terrain_at(Vector2i(x, y))
			if kind == TileGlossary.KIND_QUESTION:
				totals["coin"] += 1
			elif kind == TileGlossary.KIND_MILK_BRICK:
				totals["milk"] += 1
	for entity in entities:
		match entity["type"]:
			"coin":
				totals["coin"] += 1
			"bear", "spikeball", "arrow", "boss":
				totals["enemy"] += 1
	return totals


## 這張關卡的中繼資料指向哪些暗房。收集率的分母要把暗房也算進去，
## 不然玩家找到暗房、全撿光，收集率反而超過 100%。
func room_targets() -> Array:
	var out: Array = []
	for key in meta:
		if not str(key).begins_with("pipe"):
			continue
		var target := str(meta[key])
		if target.is_empty() or target == "__return__":
			continue
		out.append(target)
	return out


## 關卡的像素尺寸，供相機夾邊界用。
func pixel_size(tile: int) -> Vector2:
	return Vector2(width * tile, height * tile)


func _parse(text: String) -> void:
	var lines := text.replace("\r\n", "\n").split("\n")
	var map_lines := _split_header(lines)
	_read_meta()
	_read_map(map_lines)
	_validate()


## 切出中繼資料與地圖兩段，回傳地圖行。
##
## 分界線是必要的，不是可選的：「#」在中繼資料區是註解、在地圖區是地面磚，
## 沒有分界線就無從分辨。以前找不到分界線時會把全部當地圖，結果是有人寫了
## 一行註解卻得到一整排地面加上一串「未知字元」錯誤。
func _split_header(lines: PackedStringArray) -> PackedStringArray:
	var sep := -1
	for i in lines.size():
		if lines[i].strip_edges() == SEPARATOR:
			sep = i
			break
	if sep < 0:
		errors.append("關卡檔必須有一行 %s 分界線，用來隔開中繼資料與地圖" % SEPARATOR)
		return PackedStringArray()

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
	var unknown_chars := 0

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
				unknown_chars += 1
				if unknown_chars <= MAX_CHAR_ERRORS:
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

	if unknown_chars > MAX_CHAR_ERRORS:
		errors.append("另有 %d 個未知字元未逐一列出" % (unknown_chars - MAX_CHAR_ERRORS))

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
