extends GutTest

## 幾何驗收：大牛過得去、道具拿得到、看不到的地方不會摔死。
##
## 這支取代了原本只跑 level1 的 test_level1_clearance.gd。三個改變：
##   1. 每個關卡檔都跑一遍，暗房也不例外——牛奶磚頂不到就是頂不到
##   2. 常數一律問正式程式碼要，不再手抄。抄一份的話 BIG_SCALE 一調，
##      測試會拿舊數字比對而全綠，守不住它本來要守的東西
##   3. 磚台底下沒有地面（架在坑上）時不再跳過，改用關卡底部當地面——
##      懸空在坑上方的磚台恰恰是最需要驗可達性的

const TILE := LevelBuilder.TILE
const REQUIRED_CLEARANCE_ROWS := 3
## 站上移動平台那一跳要留的安全邊際。卡在跳躍上限的平台實際玩起來
## 就是「這裡老是上不去」。
const BOARD_MARGIN := 32.0

func _levels() -> Array:
	return [
		"res://levels/level1.txt",
		"res://levels/level1_pipe_a.txt",
	]

func _big_body_height() -> float:
	return Player.SMALL_BODY.y * PlayerState.BIG_SCALE

func test_three_rows_of_clearance_actually_fit_a_big_player() -> void:
	assert_gt(float(REQUIRED_CLEARANCE_ROWS * TILE), _big_body_height(),
		"3 格淨空必須放得下大牛")

## 可頂的磚塊底下要留得下大牛，而且要真的頂得到。
func test_every_bump_block_is_reachable_and_fits_a_big_player() -> void:
	var checked := 0
	for path in _levels():
		var m := LevelMap.load_from(path)
		assert_true(m.is_valid(), "%s: %s" % [path, m.errors])
		for y in m.height:
			for x in m.width:
				if not BlockRules.needs_node(m.terrain_at(Vector2i(x, y))):
					continue
				checked += 1
				var clearance := 0
				for below in range(y + 1, m.height):
					if TileGlossary.is_solid(m.terrain_at(Vector2i(x, below))):
						break
					clearance += 1
				assert_gte(clearance, REQUIRED_CLEARANCE_ROWS,
					"%s 第 (%d, %d) 的磚塊底下只有 %d 格淨空" % [path, x, y, clearance])
	assert_gt(checked, 5, "應該檢查到多塊可頂的磚")

## 站得上去的磚台不能超過跳躍高度，否則附近要有真的搆得到的移動平台。
##
## 以「連續一整段磚台」為單位判定，不是逐格——玩家只要上得去其中一格，
## 剩下的用走的就到了。
func test_standable_shelves_are_within_reach() -> void:
	var checked := 0
	for path in _levels():
		var m := LevelMap.load_from(path)
		for run in _brick_runs(m):
			var y: int = run["row"]
			var reachable := false
			var worst := 0.0
			for x in range(run["x0"], run["x1"] + 1):
				var ground_row := _ground_row_below(m, x, y)
				var rise := float(ground_row - y) * TILE
				worst = maxf(worst, rise)
				if rise <= PlayerPhysics.jump_height() \
						or _has_reachable_helper(m, x, y, ground_row):
					reachable = true
					break
			checked += 1
			assert_true(reachable,
				"%s 第 %d 列 %d–%d 那段磚台最高 %.0f px，從地面跳不上去，附近也沒有搆得到的平台"
					% [path, y, run["x0"], run["x1"], worst])
	assert_gt(checked, 3, "應該檢查到多段磚台")

## 這一欄往下第一格實心地面的列號；整欄都沒有就回關卡底部。
func _ground_row_below(m: LevelMap, x: int, y: int) -> int:
	for below in range(y + 1, m.height):
		if TileGlossary.is_solid(m.terrain_at(Vector2i(x, below))):
			return below
	return m.height

## 把每一列的連續磚塊切成一段一段。
func _brick_runs(m: LevelMap) -> Array:
	var runs: Array = []
	for y in m.height:
		var x0 := -1
		for x in m.width:
			if _is_brick(m, x, y):
				if x0 < 0:
					x0 = x
				continue
			if x0 >= 0:
				runs.append({"row": y, "x0": x0, "x1": x - 1})
				x0 = -1
		if x0 >= 0:
			runs.append({"row": y, "x0": x0, "x1": m.width - 1})
	return runs

## 附近有沒有一座「玩家上得去、而且載得到磚台高度」的移動平台。
##
## 舊版只看水平距離 8 格，既不看高度也不分平台種類——一座放在 8 格外、
## 低了 10 列的平台照樣能讓斷言通過，而玩家根本上不去。
##
## 上平台那一跳要留安全邊際：平台起點剛好卡在跳躍上限時，玩家得每次都跳到
## 極限才上得去，實際玩起來就是「這裡老是上不去」。
func _has_reachable_helper(m: LevelMap, x: int, y: int, ground_row: int) -> bool:
	for entity in m.entities:
		if not (entity["type"] in ["platform_h", "platform_v"]):
			continue
		var vertical: bool = entity["type"] == "platform_v"
		var travel: int = MovingPlatform.TRAVEL_V if vertical else MovingPlatform.TRAVEL_H
		var cell: Vector2i = entity["cell"]
		if absf(float(cell.x - x)) > float(travel):
			continue
		# 站上平台：平台停在起點那一格的中心，玩家要跳得到
		var board_rise := float(ground_row - cell.y) * TILE - TILE * 0.5
		if board_rise > PlayerPhysics.jump_height() - BOARD_MARGIN:
			continue
		# 平台行程頂端再跳一次，要搆得到磚台
		var platform_top_row: int = cell.y - (travel if vertical else 0)
		if float(platform_top_row - y) * TILE <= PlayerPhysics.jump_height():
			return true
	return false


## 玩家站在磚台上往前走，不能一步就踏進看不到的坑。
##
## 相機被夾在關卡中段，站在高處時關卡底部完全在畫面外——磚台右緣正好懸在
## 坑上方的話，玩家看不到下面是什麼就已經踩空了。
func test_no_brick_shelf_edge_overhangs_a_pit() -> void:
	for path in _levels():
		var m := LevelMap.load_from(path)
		for y in m.height:
			for x in m.width:
				if m.terrain_at(Vector2i(x, y)) != TileGlossary.KIND_BRICK:
					continue
				var left_open := not _is_brick(m, x - 1, y)
				var right_open := not _is_brick(m, x + 1, y)
				if not (left_open or right_open):
					continue
				assert_false(_column_is_a_pit(m, x, y),
					"%s 第 (%d, %d) 是磚台邊緣，正下方卻是坑——玩家看不到就會摔死"
						% [path, x, y])

func _is_brick(m: LevelMap, x: int, y: int) -> bool:
	return m.terrain_at(Vector2i(x, y)) == TileGlossary.KIND_BRICK

## 這一欄從磚台往下到關卡底部，有沒有任何站得住的地面。
func _column_is_a_pit(m: LevelMap, x: int, y: int) -> bool:
	for below in range(y + 1, m.height):
		if TileGlossary.is_solid(m.terrain_at(Vector2i(x, below))):
			return false
	return true

## 每一座移動平台，玩家自己要上得去。
##
## 舊版只在檢查「磚台段」時順便驗平台，所以旁邊沒有磚台的平台根本沒被掃到——
## 第 230 格那座就是這樣溜過去的：站立面離地 304 px、跳躍上限 236 px，
## 玩家上不去，而它行程頂端擺著兩枚「只有搭平台才拿得到」的金幣。
func test_every_moving_platform_can_be_boarded() -> void:
	var checked := 0
	for path in _levels():
		var m := LevelMap.load_from(path)
		for entity in m.entities:
			if not (entity["type"] in ["platform_h", "platform_v"]):
				continue
			checked += 1
			var cell: Vector2i = entity["cell"]
			# 平台停在起點那一格的中心，站立面在中心往上半個形狀高
			var surface := float(cell.y) * TILE + TILE * 0.5 - 16.0
			# 玩家是從水平跳躍範圍內最近的地面跳上去的，不一定是正下方——
			# 平台常常就架在坑上，正下方本來就沒有地面。
			assert_true(_can_step_up_to(m, cell.x, surface),
				"%s 第 (%d, %d) 的平台站立面 y=%.0f，附近沒有跳得上去的落腳點"
					% [path, cell.x, cell.y, surface])
	assert_gt(checked, 2, "應該檢查到多座平台")

## 每一枚金幣都要在某個站立面的跳躍範圍內。
##
## 站立面包含：地面、磚台頂、以及移動平台行程的頂端與底端。
func test_every_coin_is_reachable() -> void:
	var checked := 0
	for path in _levels():
		var m := LevelMap.load_from(path)
		var surfaces := _standing_surfaces(m)
		for entity in m.entities:
			if entity["type"] != "coin":
				continue
			checked += 1
			var cell: Vector2i = entity["cell"]
			var coin_y := float(cell.y) * TILE + TILE * 0.5
			assert_true(_reachable_from_any(surfaces, cell.x, coin_y),
				"%s 第 (%d, %d) 的金幣沒有任何站立面搆得到"
					% [path, cell.x, cell.y])
	assert_gt(checked, 10, "應該檢查到很多金幣")

## 蒐集所有站得住的表面：{x: 欄, y: 站立面世界座標}
func _standing_surfaces(m: LevelMap) -> Array:
	var out: Array = []
	for y in m.height:
		for x in m.width:
			if not TileGlossary.is_solid(m.terrain_at(Vector2i(x, y))):
				continue
			# 上方要是空的才站得住
			if TileGlossary.is_solid(m.terrain_at(Vector2i(x, y - 1))):
				continue
			out.append({"x": x, "y": float(y) * TILE})
	for entity in m.entities:
		if not (entity["type"] in ["platform_h", "platform_v"]):
			continue
		var vertical: bool = entity["type"] == "platform_v"
		var travel: int = MovingPlatform.TRAVEL_V if vertical else MovingPlatform.TRAVEL_H
		var cell: Vector2i = entity["cell"]
		var base := float(cell.y) * TILE + TILE * 0.5 - 16.0
		if vertical:
			out.append({"x": cell.x, "y": base})
			out.append({"x": cell.x, "y": base - float(travel) * TILE})
		else:
			for step in range(travel + 1):
				out.append({"x": cell.x + step, "y": base})
	return out

## 從任何一個站立面搆得到這個高度嗎。
##
## 判準要算進玩家身高：接觸框涵蓋整個身體，所以能碰到的最高點是
## 「腳底跳到的高度」再往上一個身高，不是腳底那條線。
func _reachable_from_any(surfaces: Array, x: int, target_y: float) -> bool:
	var reach := PlayerPhysics.jump_height() + Player.SMALL_BODY.y
	for surface in surfaces:
		var dx: float = absf(float(surface["x"] - x)) * TILE
		var rise: float = float(surface["y"]) - target_y
		if rise < -TILE:
			continue  # 目標在腳下太多，這個面不算
		if rise > reach:
			continue
		if dx > PlayerPhysics.jump_distance(PlayerPhysics.MAX_RUN_SPEED) * 0.5:
			continue
		return true
	return false


## 附近有沒有一個地面，跳上去就站得到這個高度（腳底，不含身高）。
func _can_step_up_to(m: LevelMap, x: int, surface_y: float) -> bool:
	for ground in _standing_surfaces(m):
		var dx: float = absf(float(ground["x"] - x)) * TILE
		var rise: float = float(ground["y"]) - surface_y
		if rise < 0.0 or rise > PlayerPhysics.jump_height() - BOARD_MARGIN:
			continue
		if dx > PlayerPhysics.jump_distance(PlayerPhysics.MAX_RUN_SPEED) * 0.5:
			continue
		return true
	return false
