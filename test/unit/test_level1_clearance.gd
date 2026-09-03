extends GutTest

## 幾何驗收：大牛過得去、道具拿得到。
##
## 這兩件事單元測試原本都沒蓋到，是靠推算碰撞箱高度與跳躍高度才發現的。
## 寫成測試之後，關卡排版再動也不會把它們弄壞。

const TILE := 64
## 小牛碰撞箱 120 高、大牛 ×1.4 = 168。磚塊底下要放得下大牛，
## 淨空至少要 3 格（192 px）。
const BIG_BODY_HEIGHT := 168.0
const REQUIRED_CLEARANCE_ROWS := 3

var m: LevelMap

func before_all() -> void:
	m = LevelMap.load_from("res://levels/level1.txt")

func test_big_player_fits_under_every_bump_block() -> void:
	assert_gt(REQUIRED_CLEARANCE_ROWS * TILE, BIG_BODY_HEIGHT,
		"3 格淨空必須放得下大牛")
	var checked := 0
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
				"第 (%d, %d) 的磚塊底下只有 %d 格淨空，大牛鑽不過去"
					% [x, y, clearance])
	assert_gt(checked, 5, "應該檢查到多塊可頂的磚")

## 站得上去的磚台不能超過跳躍高度。跳躍高度 236 px，
## 從地面躍上第 9 列（高 192 px）可以，第 8 列（256 px）不行。
func test_standable_brick_shelves_are_within_jump_reach() -> void:
	for y in m.height:
		for x in m.width:
			if m.terrain_at(Vector2i(x, y)) != TileGlossary.KIND_BRICK:
				continue
			# 找出這一欄底下最近的實心地面，算它離磚台頂端多高
			var ground_row := -1
			for below in range(y + 1, m.height):
				if TileGlossary.is_solid(m.terrain_at(Vector2i(x, below))):
					ground_row = below
					break
			if ground_row < 0:
				continue
			var rise := float(ground_row - y) * TILE
			if rise <= PlayerPhysics.jump_height():
				continue
			# 超過跳躍高度的磚台必須有移動平台或其他磚台在附近當中繼
			var has_helper := false
			for entity in m.entities:
				if entity["type"] in ["platform_h", "platform_v"] \
						and absf(entity["cell"].x - x) <= 8:
					has_helper = true
					break
			assert_true(has_helper,
				"第 (%d, %d) 的磚台高 %.0f px 超過跳躍上限，附近也沒有平台可搭"
					% [x, y, rise])
