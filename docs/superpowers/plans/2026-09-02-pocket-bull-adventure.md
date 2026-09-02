# 口袋牛牛大冒險 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以「口袋」紅牛為主角，做出一條精心設計的橫向捲軸平台長關卡，含變身道具、問號磚、投射物、移動平台、水管隱藏房、計時與關底 Boss，可匯出網頁版。

**Architecture:** 所有數學與規則放在 `scripts/` 下不繼承 `Node` 的純邏輯類別（單元測試對象）；`scenes/` 的節點只讀輸入、呼叫純邏輯、更新畫面。關卡是純文字字元地圖，由 `LevelMap` 解析成資料、`LevelBuilder` 建構成節點。訊號單向往上，只有 `Main` 改遊戲狀態。

**Tech Stack:** Godot 4.7.2（`gl_compatibility`）、GDScript、GUT 單元測試、Pillow 程式化產圖。

**Spec:** `docs/superpowers/specs/2026-09-02-pocket-bull-adventure-design.md`

## Global Constraints

- Godot 執行檔：`/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot`（4.7.2）
- 視窗 1280×720，`stretch/mode = canvas_items`、`stretch/aspect = keep`
- 渲染 `gl_compatibility`（桌機與 mobile 皆同）
- 格子 64 px；關卡地圖左下角對齊關卡底部
- `scripts/` 下所有類別**不得繼承 `Node`**，且不得 `preload` 場景
- 每個 `scripts/` 類別檔開頭寫 `class_name`，以便測試直接引用
- 註解與 UI 文字用繁體中文；程式識別名用英文
- 單元測試一律經 `tools/run_tests.sh`，不直接呼叫 GUT
- 改完程式跑 `tools/verify_game.sh`，必須全綠才算完成
- 素材由 `tools/prepare_assets.py` 產生，四倍尺寸繪製再縮小，相同輸入永遠相同輸出

---

## File Structure

| 檔案 | 責任 |
|---|---|
| `project.godot` | 視窗、渲染、InputMap、主場景 |
| `scripts/tile_glossary.gd` | 字元 ↔ 格子語意的單一真相；實心／實體分類 |
| `scripts/level_map.gd` | 文字關卡 → 地形陣列＋實體清單＋中繼資料，含驗證 |
| `scripts/player_physics.gd` | 速度積分、可變跳躍、土狼時間、跳躍緩衝 |
| `scripts/player_state.gd` | SMALL／BIG 與無敵倒數的狀態轉移 |
| `scripts/run_stats.gd` | 分數、金幣（兼彈藥）、生命、計時 |
| `scenes/player.tscn/gd` | `CharacterBody2D`，輸入 → `PlayerPhysics`，擠壓拉伸 |
| `scenes/enemy.tscn/gd` | 三種敵人型別參數化：巡邏、刺球、俯衝 |
| `scenes/coin.tscn/gd` | 可撿金幣 |
| `scenes/coin_shot.tscn/gd` | 丟出的金幣投射物 |
| `scenes/powerup.tscn/gd` | 漲停牛奶 |
| `scenes/question_block.tscn/gd` | 問號磚／牛奶磚／可破磚的頂撞互動 |
| `scenes/moving_platform.tscn/gd` | `AnimatableBody2D` 水平／垂直來回 |
| `scenes/pipe.tscn/gd` | 可進水管的偵測與訊號 |
| `scenes/goal_flag.tscn/gd` | 終點旗竿 |
| `scenes/boss.tscn/gd` | 關底 Boss熊，三段血 |
| `scenes/checkpoint.tscn/gd` | 檢查點 |
| `scenes/level_builder.gd` | `LevelMap` 資料 → `TileMapLayer` ＋ 實體節點 |
| `scenes/hud.tscn/gd` | 分數、金幣、生命、時間顯示 |
| `scenes/main.tscn/gd` | 流程狀態機、訊號匯集、相機、關卡切換 |
| `levels/level1.txt` | 主關卡，約 300×14 格 |
| `levels/level1_pipe_a.txt` | 隱藏房，約 20×8 格 |
| `tools/prepare_assets.py` | 產生 tiles、敵人、道具、旗竿、平台、背景 |
| `tools/run_tests.sh` | 單元測試入口 |
| `tools/verify_game.sh` | 語法 → 單元 → 整合 |
| `tools/integration_check.gd/tscn` | headless 整合測試 |
| `tools/capture.gd/tscn` | 不開視窗擷圖 |

---

### Task 1: 專案骨架與驗證管線

**Files:**
- Create: `project.godot`, `tools/run_tests.sh`, `tools/verify_game.sh`, `tools/capture.gd`, `tools/capture.tscn`, `test/unit/test_smoke.gd`
- 已存在: `addons/gut/`（自 Game2 複製）、`.gutconfig.json`、`.gitignore`、`assets/characters/red_bull.png`、`assets/fonts/NotoSansTC-Bold.otf`

**Interfaces:**
- Consumes: 無
- Produces: 可執行的 `tools/run_tests.sh`（GUT 入口）與 `tools/verify_game.sh`（三層驗證）

- [ ] **Step 1: 寫 `project.godot`**

```ini
config_version=5

[application]
config/name="口袋牛牛大冒險"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://assets/characters/red_bull.png"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[editor_plugins]
enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[input]
; move_left: ← A / move_right: → D / duck: ↓ S
; jump: Space / throw: Shift
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

InputMap 用 Godot 的 `InputEventKey` 物件字面值寫，physical_keycode 對照：
← `4194319`、→ `4194321`、↓ `4194322`、A `65`、D `68`、S `83`、Space `32`、Shift `4194325`。
動作名：`move_left`、`move_right`、`duck`、`jump`、`throw`。

- [ ] **Step 2: 寫 `test/unit/test_smoke.gd`**

```gdscript
extends GutTest

func test_gut_runs() -> void:
	assert_eq(1 + 1, 2, "GUT 應該能跑起來")
```

- [ ] **Step 3: 寫 `tools/run_tests.sh`（複製 Game2 版本並改路徑），跑起來確認會過**

Run: `tools/run_tests.sh`
Expected: 1 個測試通過

- [ ] **Step 4: 寫 `tools/verify_game.sh`（複製 Game2 版本）與 `tools/capture.gd/tscn`**

`capture.gd`：載入主場景、等 N 幀、`get_viewport().get_texture().get_image().save_png(path)`、`quit()`。
參數自 `OS.get_cmdline_user_args()` 取 `[路徑, 幀數]`。

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "建立 Game3 專案骨架與驗證管線"
```

---

### Task 2: `TileGlossary` 字元語意表

**Files:**
- Create: `scripts/tile_glossary.gd`
- Test: `test/unit/test_tile_glossary.gd`

**Interfaces:**
- Consumes: 無
- Produces:
  - `TileGlossary.KIND_EMPTY/GROUND/BRICK/QUESTION/MILK_BRICK/BREAKABLE/SPIKE/USED_BRICK` — `int` 常數（地形種類）
  - `TileGlossary.terrain_kind(ch: String) -> int`，未知或非地形回 `-1`
  - `TileGlossary.entity_type(ch: String) -> String`，回 `"coin"/"bear"/"spikeball"/"arrow"/"platform_h"/"platform_v"/"pipe"/"checkpoint"/"spawn"/"goal"/"boss"`，非實體回 `""`
  - `TileGlossary.is_known(ch: String) -> bool`
  - `TileGlossary.is_solid(kind: int) -> bool`（`GROUND/BRICK/QUESTION/MILK_BRICK/BREAKABLE/USED_BRICK` 為實心；`SPIKE` **不**實心，靠 Area2D 傷害）
  - `TileGlossary.pipe_index(ch: String) -> int`，`"1"`–`"9"` 回 1–9，其餘回 0

- [ ] **Step 1: 寫失敗測試 `test/unit/test_tile_glossary.gd`**

```gdscript
extends GutTest

func test_ground_is_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind("#"), TileGlossary.KIND_GROUND)

func test_space_is_empty_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind(" "), TileGlossary.KIND_EMPTY)

func test_coin_is_entity_not_terrain() -> void:
	assert_eq(TileGlossary.terrain_kind("o"), -1)
	assert_eq(TileGlossary.entity_type("o"), "coin")

func test_unknown_char_is_not_known() -> void:
	assert_false(TileGlossary.is_known("@"))
	assert_true(TileGlossary.is_known("#"))

func test_spike_is_not_solid() -> void:
	assert_false(TileGlossary.is_solid(TileGlossary.KIND_SPIKE))
	assert_true(TileGlossary.is_solid(TileGlossary.KIND_GROUND))

func test_pipe_digits_map_to_index() -> void:
	assert_eq(TileGlossary.pipe_index("1"), 1)
	assert_eq(TileGlossary.pipe_index("9"), 9)
	assert_eq(TileGlossary.pipe_index("#"), 0)
	assert_eq(TileGlossary.entity_type("3"), "pipe")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tools/run_tests.sh`
Expected: FAIL（`TileGlossary` 未定義）

- [ ] **Step 3: 寫 `scripts/tile_glossary.gd`**

```gdscript
class_name TileGlossary
extends RefCounted

const KIND_EMPTY := 0
const KIND_GROUND := 1
const KIND_BRICK := 2
const KIND_QUESTION := 3
const KIND_MILK_BRICK := 4
const KIND_BREAKABLE := 5
const KIND_SPIKE := 6
const KIND_USED_BRICK := 7

const _TERRAIN := {
	" ": KIND_EMPTY, "#": KIND_GROUND, "=": KIND_BRICK,
	"?": KIND_QUESTION, "M": KIND_MILK_BRICK, "x": KIND_BREAKABLE,
	"^": KIND_SPIKE,
}
const _ENTITY := {
	"o": "coin", "b": "bear", "s": "spikeball", "a": "arrow",
	"P": "platform_h", "V": "platform_v", "C": "checkpoint",
	"S": "spawn", "F": "goal", "K": "boss",
}
const _SOLID := [KIND_GROUND, KIND_BRICK, KIND_QUESTION,
	KIND_MILK_BRICK, KIND_BREAKABLE, KIND_USED_BRICK]
```

四個查詢函式照 Interfaces 實作；`pipe_index` 用 `"123456789".find(ch)` 判斷。
`is_known` 是 `_TERRAIN.has(ch) or _ENTITY.has(ch) or pipe_index(ch) > 0`。

- [ ] **Step 4: 跑測試確認通過**

Run: `tools/run_tests.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入字元語意表 TileGlossary"
```

---

### Task 3: `LevelMap` 關卡解析器

**Files:**
- Create: `scripts/level_map.gd`
- Test: `test/unit/test_level_map.gd`

**Interfaces:**
- Consumes: `TileGlossary`
- Produces:
  - `LevelMap.parse(text: String) -> LevelMap`（靜態工廠）
  - 欄位：`errors: Array[String]`、`width: int`、`height: int`、`terrain: Array`（`Array[Array[int]]`，`terrain[y][x]`，y 由上到下）、`entities: Array[Dictionary]`（`{"type": String, "cell": Vector2i, "params": Dictionary}`）、`meta: Dictionary`、`spawn: Vector2i`、`time_limit: int`、`level_name: String`
  - `is_valid() -> bool`（`errors.is_empty()`）
  - `terrain_at(cell: Vector2i) -> int`（越界回 `KIND_EMPTY`）

**解析規則：** `---` 之前每行是 `key: value` 中繼資料（空行略過）；之後為地圖。
地圖寬度取最長行，短行右側補空白。實體格子的地形一律為 `KIND_EMPTY`。
水管實體的 `params` 帶 `{"index": int, "target": String}`。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_level_map.gd`**

```gdscript
extends GutTest

const HEAD := "name: 測試關\ntime: 120\npipe1: room_a\n---\n"

func test_parses_terrain_and_size() -> void:
	var m := LevelMap.parse(HEAD + "  S \n####")
	assert_true(m.is_valid(), str(m.errors))
	assert_eq(m.width, 4)
	assert_eq(m.height, 2)
	assert_eq(m.terrain_at(Vector2i(0, 1)), TileGlossary.KIND_GROUND)
	assert_eq(m.terrain_at(Vector2i(0, 0)), TileGlossary.KIND_EMPTY)

func test_reads_metadata() -> void:
	var m := LevelMap.parse(HEAD + "S\n#")
	assert_eq(m.level_name, "測試關")
	assert_eq(m.time_limit, 120)

func test_time_defaults_to_300() -> void:
	var m := LevelMap.parse("name: 無時間\n---\nS\n#")
	assert_eq(m.time_limit, 300)

func test_spawn_cell_recorded_and_not_an_entity() -> void:
	var m := LevelMap.parse(HEAD + " S \n###")
	assert_eq(m.spawn, Vector2i(1, 0))
	for e in m.entities:
		assert_ne(e["type"], "spawn")

func test_entities_collected_with_cells() -> void:
	var m := LevelMap.parse(HEAD + "S o b F\n#######")
	var types: Array = []
	for e in m.entities:
		types.append(e["type"])
	assert_true(types.has("coin"))
	assert_true(types.has("bear"))
	assert_true(types.has("goal"))

func test_entity_cell_terrain_is_empty() -> void:
	var m := LevelMap.parse(HEAD + "S b F\n#####")
	assert_eq(m.terrain_at(Vector2i(2, 0)), TileGlossary.KIND_EMPTY)

func test_requires_exactly_one_spawn() -> void:
	assert_false(LevelMap.parse(HEAD + "F\n#").is_valid())
	assert_false(LevelMap.parse(HEAD + "S S F\n#####").is_valid())

func test_requires_goal_or_boss() -> void:
	assert_false(LevelMap.parse(HEAD + "S\n#").is_valid())
	assert_true(LevelMap.parse(HEAD + "S K\n###").is_valid())

func test_unknown_char_reports_position() -> void:
	var m := LevelMap.parse(HEAD + "S @ F\n#####")
	assert_false(m.is_valid())
	assert_string_contains(m.errors[0], "@")

func test_pipe_requires_matching_meta() -> void:
	var ok := LevelMap.parse(HEAD + "S 1 F\n#####")
	assert_true(ok.is_valid(), str(ok.errors))
	var bad := LevelMap.parse(HEAD + "S 2 F\n#####")
	assert_false(bad.is_valid())

func test_pipe_entity_carries_target() -> void:
	var m := LevelMap.parse(HEAD + "S 1 F\n#####")
	for e in m.entities:
		if e["type"] == "pipe":
			assert_eq(e["params"]["target"], "room_a")
			assert_eq(e["params"]["index"], 1)

func test_short_rows_padded_with_empty() -> void:
	var m := LevelMap.parse(HEAD + "S\n####F\n#####")
	assert_eq(m.width, 5)
	assert_eq(m.terrain_at(Vector2i(4, 0)), TileGlossary.KIND_EMPTY)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tools/run_tests.sh`
Expected: FAIL（`LevelMap` 未定義）

- [ ] **Step 3: 寫 `scripts/level_map.gd`**

`parse` 流程：切行 → 找 `---` 分界（找不到就全部當地圖、`meta` 空）→ 逐行 `split(":", true, 1)`
填 `meta` → 地圖行算寬高 → 雙層迴圈逐字元分類：地形填 `terrain`，實體 append 到
`entities`（`spawn` 只記 `spawn` 欄位不進 `entities`），未知字元 append 錯誤
`"第 %d 行第 %d 欄有未知字元「%s」"` → 最後跑四條驗證。

- [ ] **Step 4: 跑測試確認通過**

Run: `tools/run_tests.sh`
Expected: 12 個測試 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入文字關卡解析器 LevelMap"
```

---

### Task 4: `PlayerPhysics` 純物理

**Files:**
- Create: `scripts/player_physics.gd`
- Test: `test/unit/test_player_physics.gd`

**Interfaces:**
- Consumes: 無
- Produces:
  - 常數：`MAX_RUN_SPEED = 280.0`、`GROUND_ACCEL = 1600.0`、`GROUND_BRAKE = 2000.0`、`AIR_ACCEL = 1100.0`、`JUMP_VELOCITY = -720.0`、`GRAVITY_RISE = 1100.0`、`GRAVITY_FALL = 1800.0`、`JUMP_CUT_VELOCITY = -420.0`、`TERMINAL_FALL = 900.0`、`COYOTE_TIME = 0.10`、`JUMP_BUFFER = 0.12`、`STOMP_BOUNCE = -480.0`、`STOMP_BOUNCE_HELD = -640.0`
  - `PlayerPhysics.step(velocity: Vector2, input: Dictionary, on_floor: bool, delta: float, timers: Dictionary) -> Dictionary`
    - `input`：`{"dir": float（-1/0/1）, "jump_pressed": bool, "jump_held": bool}`
    - `timers`：`{"coyote": float, "buffer": float}`
    - 回傳：`{"velocity": Vector2, "timers": Dictionary, "jumped": bool}`
  - `PlayerPhysics.stomp_velocity(jump_held: bool) -> float`
  - `PlayerPhysics.jump_height() -> float`（`JUMP_VELOCITY² / (2 * GRAVITY_RISE)`，供測試斷言）

**`step` 順序：** 更新計時器（`on_floor` 時 `coyote = COYOTE_TIME`，否則減 delta；`jump_pressed`
時 `buffer = JUMP_BUFFER`，否則減 delta）→ 水平：有輸入用 `GROUND_ACCEL`/`AIR_ACCEL`
朝 `dir * MAX_RUN_SPEED` 靠近，無輸入且在地面用 `GROUND_BRAKE` 朝 0 靠近 →
跳躍：`buffer > 0 and coyote > 0` 則設 `JUMP_VELOCITY`、兩計時器歸零、`jumped = true` →
重力：`velocity.y < 0` 用 `GRAVITY_RISE`，否則 `GRAVITY_FALL` → 放開跳鍵夾制：
未按住且 `velocity.y < JUMP_CUT_VELOCITY` 則設為 `JUMP_CUT_VELOCITY` → 下墜夾到 `TERMINAL_FALL`。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_player_physics.gd`**

```gdscript
extends GutTest

const D := 1.0 / 60.0

func _input(dir: float, pressed := false, held := false) -> Dictionary:
	return {"dir": dir, "jump_pressed": pressed, "jump_held": held}

func _timers(coyote := 0.0, buffer := 0.0) -> Dictionary:
	return {"coyote": coyote, "buffer": buffer}

func test_accelerates_toward_max_speed() -> void:
	var v := Vector2.ZERO
	var t := _timers(PlayerPhysics.COYOTE_TIME)
	for i in 120:
		var r := PlayerPhysics.step(v, _input(1.0), true, D, t)
		v = r["velocity"]
		t = r["timers"]
	assert_almost_eq(v.x, PlayerPhysics.MAX_RUN_SPEED, 1.0)

func test_never_exceeds_max_speed() -> void:
	var r := PlayerPhysics.step(Vector2(PlayerPhysics.MAX_RUN_SPEED, 0),
		_input(1.0), true, D, _timers(0.1))
	assert_almost_eq(r["velocity"].x, PlayerPhysics.MAX_RUN_SPEED, 0.01)

func test_brakes_to_zero_without_input() -> void:
	var v := Vector2(PlayerPhysics.MAX_RUN_SPEED, 0)
	var t := _timers(0.1)
	for i in 60:
		var r := PlayerPhysics.step(v, _input(0.0), true, D, t)
		v = r["velocity"]
		t = r["timers"]
	assert_almost_eq(v.x, 0.0, 0.01)

func test_air_accel_is_weaker_than_ground() -> void:
	var air := PlayerPhysics.step(Vector2.ZERO, _input(1.0), false, D, _timers())
	var ground := PlayerPhysics.step(Vector2.ZERO, _input(1.0), true, D, _timers(0.1))
	assert_lt(air["velocity"].x, ground["velocity"].x)

func test_jump_from_floor_sets_jump_velocity() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _input(0.0, true, true), true, D, _timers())
	assert_true(r["jumped"])
	assert_lt(r["velocity"].y, PlayerPhysics.JUMP_VELOCITY * 0.5)

func test_jump_height_matches_design() -> void:
	assert_almost_eq(PlayerPhysics.jump_height(), 236.0, 4.0)

func test_fall_gravity_stronger_than_rise() -> void:
	var rise := PlayerPhysics.step(Vector2(0, -300), _input(0.0, false, true), false, D, _timers())
	var fall := PlayerPhysics.step(Vector2(0, 300), _input(0.0), false, D, _timers())
	var rise_delta: float = rise["velocity"].y - (-300.0)
	var fall_delta: float = fall["velocity"].y - 300.0
	assert_lt(rise_delta, fall_delta)

func test_releasing_jump_cuts_rise() -> void:
	var r := PlayerPhysics.step(Vector2(0, -700), _input(0.0, false, false), false, D, _timers())
	assert_almost_eq(r["velocity"].y, PlayerPhysics.JUMP_CUT_VELOCITY, 0.01)

func test_holding_jump_does_not_cut_rise() -> void:
	var r := PlayerPhysics.step(Vector2(0, -700), _input(0.0, false, true), false, D, _timers())
	assert_lt(r["velocity"].y, PlayerPhysics.JUMP_CUT_VELOCITY)

func test_coyote_time_allows_jump_just_after_leaving_ground() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _input(0.0, true, true), false, D,
		_timers(0.05))
	assert_true(r["jumped"])

func test_coyote_time_expires() -> void:
	var r := PlayerPhysics.step(Vector2.ZERO, _input(0.0, true, true), false, D,
		_timers(0.0))
	assert_false(r["jumped"])

func test_jump_buffer_fires_on_landing() -> void:
	var mid := PlayerPhysics.step(Vector2(0, 300), _input(0.0, true, true), false, D, _timers())
	assert_false(mid["jumped"])
	var landed := PlayerPhysics.step(mid["velocity"], _input(0.0, false, true), true, D,
		mid["timers"])
	assert_true(landed["jumped"])

func test_terminal_fall_speed_capped() -> void:
	var r := PlayerPhysics.step(Vector2(0, 5000), _input(0.0), false, D, _timers())
	assert_almost_eq(r["velocity"].y, PlayerPhysics.TERMINAL_FALL, 0.01)

func test_stomp_bounce_higher_when_jump_held() -> void:
	assert_lt(PlayerPhysics.stomp_velocity(true), PlayerPhysics.stomp_velocity(false))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `tools/run_tests.sh`
Expected: FAIL（`PlayerPhysics` 未定義）

- [ ] **Step 3: 寫 `scripts/player_physics.gd`** 依上方順序實作。

- [ ] **Step 4: 跑測試確認通過**

Run: `tools/run_tests.sh`
Expected: 14 個測試 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入純物理 PlayerPhysics 與手感參數"
```

---

### Task 5: `PlayerState` 狀態機

**Files:**
- Create: `scripts/player_state.gd`
- Test: `test/unit/test_player_state.gd`

**Interfaces:**
- Consumes: 無
- Produces:
  - `PlayerState` 繼承 `RefCounted`，可 `new()`
  - 常數 `SMALL = 0`、`BIG = 1`、`INVINCIBLE_TIME = 1.2`
  - 欄位 `size: int`（初始 `SMALL`）、`invincible_left: float`
  - `is_invincible() -> bool`
  - `is_big() -> bool`
  - `advance(delta: float) -> void`（倒數無敵）
  - `take_hit() -> String`：回 `"died"`／`"shrank"`／`"ignored"`
  - `collect_milk() -> String`：回 `"grew"`／`"bonus"`
  - `can_throw() -> bool`（等同 `is_big()`）

- [ ] **Step 1: 寫失敗測試 `test/unit/test_player_state.gd`**

```gdscript
extends GutTest

var s: PlayerState

func before_each() -> void:
	s = PlayerState.new()

func test_starts_small_and_vulnerable() -> void:
	assert_eq(s.size, PlayerState.SMALL)
	assert_false(s.is_invincible())
	assert_false(s.can_throw())

func test_small_hit_dies() -> void:
	assert_eq(s.take_hit(), "died")

func test_milk_grows_small_to_big() -> void:
	assert_eq(s.collect_milk(), "grew")
	assert_true(s.is_big())
	assert_true(s.can_throw())

func test_milk_when_big_is_bonus() -> void:
	s.collect_milk()
	assert_eq(s.collect_milk(), "bonus")
	assert_true(s.is_big())

func test_big_hit_shrinks_and_grants_invincibility() -> void:
	s.collect_milk()
	assert_eq(s.take_hit(), "shrank")
	assert_eq(s.size, PlayerState.SMALL)
	assert_true(s.is_invincible())

func test_hit_while_invincible_is_ignored() -> void:
	s.collect_milk()
	s.take_hit()
	assert_eq(s.take_hit(), "ignored")

func test_invincibility_expires() -> void:
	s.collect_milk()
	s.take_hit()
	s.advance(PlayerState.INVINCIBLE_TIME + 0.01)
	assert_false(s.is_invincible())
	assert_eq(s.take_hit(), "died")
```

- [ ] **Step 2: 跑測試確認失敗** — Run `tools/run_tests.sh`，Expected FAIL

- [ ] **Step 3: 寫 `scripts/player_state.gd`**

- [ ] **Step 4: 跑測試確認通過** — Expected 7 個 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入玩家狀態機 PlayerState"
```

---

### Task 6: `RunStats` 分數與資源

**Files:**
- Create: `scripts/run_stats.gd`
- Test: `test/unit/test_run_stats.gd`

**Interfaces:**
- Consumes: 無
- Produces:
  - `RunStats` 繼承 `RefCounted`，`new(time_limit: int = 300)`
  - 常數 `COIN_SCORE = 50`、`STOMP_SCORE = 100`、`MILK_BONUS_SCORE = 1000`、`TIME_BONUS_PER_SECOND = 10`、`START_LIVES = 3`
  - 欄位 `score: int`、`coins: int`、`lives: int`、`time_left: float`
  - `add_coin() -> void`（`coins += 1`、`score += COIN_SCORE`）
  - `add_stomp() -> void`
  - `add_milk_bonus() -> void`
  - `spend_coin() -> bool`（有金幣才扣並回 `true`）
  - `lose_life() -> bool`（扣一命，回「還有命」）
  - `tick(delta: float) -> bool`（倒數，回「時間到」）
  - `finish() -> void`（把剩餘秒數 ×`TIME_BONUS_PER_SECOND` 加進分數並歸零時間）

- [ ] **Step 1: 寫失敗測試 `test/unit/test_run_stats.gd`**

```gdscript
extends GutTest

var r: RunStats

func before_each() -> void:
	r = RunStats.new(10)

func test_starts_with_lives_and_time() -> void:
	assert_eq(r.lives, RunStats.START_LIVES)
	assert_almost_eq(r.time_left, 10.0, 0.001)
	assert_eq(r.score, 0)
	assert_eq(r.coins, 0)

func test_coin_adds_coin_and_score() -> void:
	r.add_coin()
	assert_eq(r.coins, 1)
	assert_eq(r.score, RunStats.COIN_SCORE)

func test_stomp_adds_score_only() -> void:
	r.add_stomp()
	assert_eq(r.score, RunStats.STOMP_SCORE)
	assert_eq(r.coins, 0)

func test_spend_coin_requires_a_coin() -> void:
	assert_false(r.spend_coin())
	r.add_coin()
	assert_true(r.spend_coin())
	assert_eq(r.coins, 0)

func test_lose_life_reports_remaining() -> void:
	assert_true(r.lose_life())
	assert_eq(r.lives, RunStats.START_LIVES - 1)
	r.lose_life()
	assert_false(r.lose_life())
	assert_eq(r.lives, 0)

func test_tick_reports_timeout() -> void:
	assert_false(r.tick(9.0))
	assert_true(r.tick(2.0))
	assert_almost_eq(r.time_left, 0.0, 0.001)

func test_finish_converts_time_to_score() -> void:
	r.tick(4.0)
	r.finish()
	assert_eq(r.score, 6 * RunStats.TIME_BONUS_PER_SECOND)
	assert_almost_eq(r.time_left, 0.0, 0.001)
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/run_stats.gd`**

- [ ] **Step 4: 跑測試確認通過** — Expected 7 個 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入分數與資源管理 RunStats"
```

---

### Task 7: 素材管線

**Files:**
- Create: `tools/prepare_assets.py`, `tools/README.md`
- 產出: `assets/tiles.png`、`assets/coin.png`、`assets/milk.png`、`assets/flag.png`、`assets/platform.png`、`assets/background.png`、`assets/enemies/{bear,spikeball,arrow,boss}.png`

**Interfaces:**
- Consumes: 無（Pillow）
- Produces: 上列 PNG。`tiles.png` 是 7 格橫向圖集，每格 64×64，順序為
  地面、磚台、問號磚、用過磚、可破磚、尖刺、水管口；`LevelBuilder` 依此順序切 `AtlasTexture`。

- [ ] **Step 1: 建虛擬環境並裝 Pillow**

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install Pillow
```

- [ ] **Step 2: 寫 `tools/prepare_assets.py`**

沿用 Game2 慣例：`SUPERSAMPLE = 4`、`OUTLINE = (20, 20, 24, 255)`、
半透明白／黑做高光與陰影。配色常數：

```python
GROUND_TOP = (108, 176, 92, 255)     # 草面
GROUND_BODY = (146, 104, 66, 255)    # 土
BRICK = (186, 116, 78, 255)
QUESTION = (240, 182, 54, 255)
USED = (150, 138, 122, 255)
BREAKABLE = (206, 158, 106, 255)
SPIKE = (198, 204, 214, 255)
PIPE = (76, 178, 128, 255)
COIN = (255, 196, 0, 255)
MILK = (250, 250, 245, 255)
BEAR = (140, 96, 64, 255)
BOSS = (72, 62, 78, 255)
SPIKEBALL = (198, 66, 78, 255)
ARROW = (74, 190, 122, 255)          # 跌停用綠（台股跌為綠）
SKY_TOP = (126, 196, 238, 255)
SKY_BOTTOM = (206, 234, 250, 255)
```

Q 版敵人一律「圓身 ＋ 圓耳 ＋ 豆豆眼 ＋ 粗黑輪廓」，只用 `ellipse` 與
`rounded_rectangle` 疊出來，與紅牛的圓潤粗輪廓對得上。
Boss 是放大 1.8 倍的熊加金色皇冠與怒眉。
背景畫天空漸層 ＋ 遠景 K 線剪影（半透明白色矩形柱），寬 1280 供視差橫向重複捲動。

- [ ] **Step 3: 執行並確認產出**

```bash
tools/.venv/bin/python tools/prepare_assets.py && ls -la assets assets/enemies
```
Expected: 10 個 PNG，尺寸符合（`tiles.png` 為 448×64）

- [ ] **Step 4: 寫 `tools/README.md`** 說明重建環境與執行方式

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "加入 Q 版素材程式化產生管線"
```

---

### Task 8: 玩家節點與可跑跳的最小關卡

**Files:**
- Create: `scenes/player.tscn`, `scenes/player.gd`, `scenes/level_builder.gd`, `scenes/main.tscn`, `scenes/main.gd`, `levels/dev.txt`
- Test: `test/unit/test_smoke.gd`（不動）

**Interfaces:**
- Consumes: `PlayerPhysics`、`PlayerState`、`LevelMap`、`TileGlossary`、`assets/tiles.png`
- Produces:
  - `Player`（`CharacterBody2D`）訊號：`died`、`stomped_enemy(enemy: Node)`、`hit_hazard`、`coin_collected`、`throw_requested(dir: int, origin: Vector2)`
  - `Player.state: PlayerState`、`Player.apply_stomp(jump_held: bool)`、`Player.respawn_at(pos: Vector2)`
  - `LevelBuilder.build(map: LevelMap, tile_layer: TileMapLayer, entity_root: Node2D) -> Dictionary`
    回傳 `{"spawn_position": Vector2, "bounds": Rect2, "entities_built": int}`
  - `Main` 常數 `TILE := 64`

- [ ] **Step 1: 寫 `levels/dev.txt` 開發用短關卡**

```
name: 開發測試
time: 300
---
                    
   S        o   o    
        ====         
####  ##########   F#
#####################
```

- [ ] **Step 2: 建 `scenes/player.tscn`**

`CharacterBody2D`（碰撞層 1、遮罩 1）＋ `CollisionShape2D`（`RectangleShape2D` 56×120，
中心在 y = −60，讓原點落在腳底）＋ `Sprite2D`（`red_bull.png`，`scale` 使高度為 128、
`offset.y = -64`）＋ `Area2D`「HurtBox」（比碰撞箱略小，遮罩含敵人層 2 與危險層 4）。

- [ ] **Step 3: 寫 `scenes/player.gd`**

`_physics_process`：組 `input` 字典（`Input.get_axis("move_left", "move_right")`、
`Input.is_action_just_pressed("jump")`、`Input.is_action_pressed("jump")`）→
呼叫 `PlayerPhysics.step` → 回寫 `velocity` → `move_and_slide()` →
`state.advance(delta)` → 更新擠壓拉伸。
擠壓拉伸依規格表用 `_squash_tween` 實作；`jumped` 為真時播起跳壓縮，
`is_on_floor()` 由假轉真時播落地壓縮。
`Shift` 且 `state.can_throw()` 時發 `throw_requested`。

- [ ] **Step 4: 寫 `scenes/level_builder.gd`**

`build()` 逐格把 `terrain` 寫進 `TileMapLayer`（用 `TileSet` 的單一 atlas source，
7 種地形對應 atlas 座標 `Vector2i(kind_to_atlas_x, 0)`）；`KIND_SPIKE` 額外在該格
生成一個 `Area2D`（危險層 4）；實體清單逐項 `instantiate` 對應場景並放到
`entity_root`（本任務只處理 `coin`、`goal`，其餘留待後續任務）。
座標換算：`Vector2(cell.x * TILE + TILE * 0.5, (cell.y + 1) * TILE)`（格子底邊中央）。
`TileSet` 在 `_ready` 用程式建（`TileSetAtlasSource` 指向 `assets/tiles.png`，
`texture_region_size = Vector2i(64, 64)`，7 格逐一 `create_tile` 並加
`physics_layer` 與 64×64 方形碰撞多邊形）——這樣不需要圖形編輯器。

- [ ] **Step 5: 寫 `scenes/main.tscn` / `main.gd` 最小版**

`Node2D` ＋ `TileMapLayer` ＋ `Node2D`「Entities」＋ `Camera2D` ＋ 玩家實例。
`_ready`：讀 `levels/dev.txt` → `LevelMap.parse` → 有錯就 `push_error` 並印出 →
`LevelBuilder.build` → 玩家移到 `spawn_position` → 設相機 `limit_*` 為 `bounds`。
相機：`position_smoothing_enabled = true`、`drag_horizontal_enabled = true`、
垂直用 `drag_top_margin/bottom_margin = 0.12`。

- [ ] **Step 6: 語法檢查與擷圖確認**

```bash
tools/verify_game.sh
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --path . tools/capture.tscn -- /tmp/g3_player.png 120
```
Expected: 驗證全綠；PNG 裡看得到牛站在地面上、金幣在空中、天空背景

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "加入玩家節點、關卡建構器與可跑跳的最小關卡"
```

---

### Task 9: 敵人與踩踏

**Files:**
- Create: `scenes/enemy.tscn`, `scenes/enemy.gd`
- Modify: `scenes/level_builder.gd`（生成 `bear`/`spikeball`/`arrow`）、`scenes/player.gd`（踩踏判定）、`scenes/main.gd`（接訊號計分）
- Test: `test/unit/test_enemy_rules.gd`

**Interfaces:**
- Consumes: `PlayerPhysics.stomp_velocity`
- Produces:
  - `scripts/enemy_rules.gd`（純邏輯）：`EnemyRules.KIND_BEAR/SPIKEBALL/ARROW`、
    `EnemyRules.is_stompable(kind: int) -> bool`、`EnemyRules.patrol_speed(kind: int) -> float`、
    `EnemyRules.turn_direction(dir: int, blocked_ahead: bool, floor_ahead: bool) -> int`
  - `Enemy` 訊號：`stomped(enemy: Node)`、`touched_player`
  - `Enemy.kind: int`、`Enemy.die()`

**踩踏判定：** 玩家的 `HurtBox` 與敵人重疊時，若 `velocity.y > 0` 且玩家腳底
（`global_position.y`）高於敵人中心，且 `EnemyRules.is_stompable(kind)` → 發 `stomped`，
玩家 `velocity.y = PlayerPhysics.stomp_velocity(jump_held)`；否則走受傷流程。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_enemy_rules.gd`**

```gdscript
extends GutTest

func test_bear_is_stompable_spikeball_is_not() -> void:
	assert_true(EnemyRules.is_stompable(EnemyRules.KIND_BEAR))
	assert_true(EnemyRules.is_stompable(EnemyRules.KIND_ARROW))
	assert_false(EnemyRules.is_stompable(EnemyRules.KIND_SPIKEBALL))

func test_patrol_speeds_differ_by_kind() -> void:
	assert_almost_eq(EnemyRules.patrol_speed(EnemyRules.KIND_BEAR), 60.0, 0.01)
	assert_lt(EnemyRules.patrol_speed(EnemyRules.KIND_SPIKEBALL),
		EnemyRules.patrol_speed(EnemyRules.KIND_BEAR))

func test_turns_when_blocked_ahead() -> void:
	assert_eq(EnemyRules.turn_direction(1, true, true), -1)

func test_turns_when_no_floor_ahead() -> void:
	assert_eq(EnemyRules.turn_direction(1, false, false), -1)

func test_keeps_direction_when_path_is_clear() -> void:
	assert_eq(EnemyRules.turn_direction(-1, false, true), -1)
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/enemy_rules.gd`**（`patrol_speed`：熊 60、刺球 30、箭頭 0）

- [ ] **Step 4: 跑測試確認通過** — Expected 5 個 PASS

- [ ] **Step 5: 建 `scenes/enemy.tscn` 與 `enemy.gd`**

`CharacterBody2D`（層 2）＋ `Sprite2D`＋`CollisionShape2D`＋兩個 `RayCast2D`
（前方牆壁探測、前下方地面探測）。`kind` 由 `LevelBuilder` 設定並據此換貼圖、
碰撞箱大小與速度。`arrow` 不巡邏，改用 `Area2D` 偵測玩家水平距離 < 320 px
即以 260 px/s 朝玩家俯衝。`die()`：關碰撞、`scale.y` 壓扁到 0.2 並淡出後 `queue_free()`。

- [ ] **Step 6: 接進 `LevelBuilder`、`player.gd`、`main.gd`**（踩踏加分、受傷走 `PlayerState.take_hit`）

- [ ] **Step 7: 驗證與擷圖** — `tools/verify_game.sh` 全綠

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "加入三種 Q 版敵人與踩踏機制"
```

---

### Task 10: 磚塊互動、金幣與變身道具

**Files:**
- Create: `scenes/coin.tscn/gd`, `scenes/powerup.tscn/gd`, `scenes/question_block.tscn/gd`
- Modify: `scenes/level_builder.gd`、`scenes/player.gd`（頭頂偵測）、`scenes/main.gd`

**Interfaces:**
- Consumes: `TileGlossary`、`PlayerState`、`RunStats`
- Produces:
  - `QuestionBlock` 訊號：`spawned_coin(position: Vector2)`、`spawned_milk(position: Vector2)`、`broke`
  - `QuestionBlock.hit_from_below(player_is_big: bool) -> String`：回 `"coin"`／`"milk"`／`"broke"`／`"bounce"`
  - `Coin` 訊號 `collected`；`Powerup` 訊號 `collected`

**做法：** `?`／`M`／`x` 三種格子不寫進 `TileMapLayer`，改由 `LevelBuilder` 生成
`QuestionBlock` 節點（`StaticBody2D` 層 1，尺寸 64×64），這樣才能各自處理頂撞。
玩家 `_physics_process` 後檢查 `get_slide_collision_count()`，若法線朝下
（`collision.get_normal().y > 0.7`）且碰到 `QuestionBlock`，呼叫 `hit_from_below`。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_block_rules.gd`**

```gdscript
extends GutTest

func test_question_block_gives_coin_once() -> void:
	var r := BlockRules.resolve_hit(TileGlossary.KIND_QUESTION, false, false)
	assert_eq(r, "coin")
	var again := BlockRules.resolve_hit(TileGlossary.KIND_QUESTION, false, true)
	assert_eq(again, "spent")

func test_milk_block_gives_milk() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_MILK_BRICK, false, false), "milk")

func test_breakable_bounces_for_small_breaks_for_big() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BREAKABLE, false, false), "bounce")
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BREAKABLE, true, false), "broke")

func test_plain_brick_always_bounces() -> void:
	assert_eq(BlockRules.resolve_hit(TileGlossary.KIND_BRICK, true, false), "bounce")
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/block_rules.gd`**

```gdscript
class_name BlockRules
extends RefCounted

static func resolve_hit(kind: int, player_is_big: bool, already_used: bool) -> String:
	if already_used:
		return "spent"
	match kind:
		TileGlossary.KIND_QUESTION: return "coin"
		TileGlossary.KIND_MILK_BRICK: return "milk"
		TileGlossary.KIND_BREAKABLE:
			return "broke" if player_is_big else "bounce"
	return "bounce"
```

- [ ] **Step 4: 跑測試確認通過** — Expected 4 個 PASS

- [ ] **Step 5: 建三個場景並接進 `LevelBuilder` 與 `main.gd`**

彈出物：金幣往上跳 90 px 後消失並計分；牛奶往上頂出後落在磚上、可撿。
`QuestionBlock` 被頂時整塊上移 12 px 再回位（Tween 0.18 s）。
用過的問號磚換成 `USED` 貼圖。

- [ ] **Step 6: 驗證與擷圖** — `tools/verify_game.sh` 全綠

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "加入磚塊互動、金幣與變身道具"
```

---

### Task 11: 丟金幣投射物

**Files:**
- Create: `scenes/coin_shot.tscn`, `scenes/coin_shot.gd`
- Modify: `scenes/main.gd`（接 `throw_requested`、扣彈藥）

**Interfaces:**
- Consumes: `RunStats.spend_coin`、`PlayerState.can_throw`
- Produces: `CoinShot.launch(dir: int)`；訊號 `hit_enemy(enemy: Node)`

**規則：** 只有 BIG 能丟，且 `RunStats.spend_coin()` 成功才真的生成。
投射物水平 460 px/s、重力 900 px/s²、碰到敵人即 `enemy.die()` 並加分、
碰到地形或飛出畫面即消失。刺球只能被投射物打死。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_throw_rules.gd`**

```gdscript
extends GutTest

func test_small_player_cannot_throw() -> void:
	var s := PlayerState.new()
	var r := RunStats.new(300)
	r.add_coin()
	assert_false(ThrowRules.can_fire(s, r))

func test_big_player_with_coin_can_throw() -> void:
	var s := PlayerState.new()
	s.collect_milk()
	var r := RunStats.new(300)
	r.add_coin()
	assert_true(ThrowRules.can_fire(s, r))

func test_big_player_without_coin_cannot_throw() -> void:
	var s := PlayerState.new()
	s.collect_milk()
	assert_false(ThrowRules.can_fire(PlayerState.new(), RunStats.new(300)))
	assert_false(ThrowRules.can_fire(s, RunStats.new(300)))

func test_fire_spends_exactly_one_coin() -> void:
	var s := PlayerState.new()
	s.collect_milk()
	var r := RunStats.new(300)
	r.add_coin()
	r.add_coin()
	assert_true(ThrowRules.fire(s, r))
	assert_eq(r.coins, 1)
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/throw_rules.gd`**（`can_fire` 檢查 `can_throw() and coins > 0`；`fire` 檢查後 `spend_coin`）

- [ ] **Step 4: 跑測試確認通過** — Expected 4 個 PASS

- [ ] **Step 5: 建 `coin_shot.tscn/gd` 並接進 `main.gd`**

- [ ] **Step 6: 驗證** — `tools/verify_game.sh` 全綠

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "加入大牛丟金幣攻擊，金幣兼作彈藥"
```

---

### Task 12: 移動平台、水管隱藏房與檢查點

**Files:**
- Create: `scenes/moving_platform.tscn/gd`, `scenes/pipe.tscn/gd`, `scenes/checkpoint.tscn/gd`, `levels/level1_pipe_a.txt`
- Modify: `scenes/level_builder.gd`、`scenes/main.gd`（關卡切換與重生點）

**Interfaces:**
- Consumes: `LevelMap`
- Produces:
  - `MovingPlatform.setup(vertical: bool, travel_cells: int)`（`AnimatableBody2D`，
    `sync_to_physics = true`，水平 4 格、垂直 3 格，速度 80 px/s，用 Tween 來回）
  - `Pipe` 訊號 `entered(target: String)`；`Pipe.target: String`
  - `Checkpoint` 訊號 `reached(position: Vector2)`
  - `Main.enter_level(path: String, spawn_override: Vector2 = Vector2.INF) -> void`
  - `Main.return_from_room() -> void`（回主關卡，玩家放在原水管右側一格的地面）

**關卡切換做法：** `Main` 同時只建構一張關卡。進水管時記下
`_return_position`，清掉 `Entities` 與 `TileMapLayer`，建構房間關卡；
房間裡的水管 `target` 為 `"__return__"`，觸發 `return_from_room()`。
計時與分數不重置（`RunStats` 活在 `Main`，不隨關卡重建）。

- [ ] **Step 1: 寫 `levels/level1_pipe_a.txt`**

```
name: 盤面暗房
time: 300
pipe1: __return__
---
####################
#                  #
#   o o o o o o    #
#                  #
#  M            1  #
#=====        =====#
#                  #
####################
```
（此房間無 `S` 與 `F`；`Main` 進房時用 `spawn_override` 指定落點，
`LevelMap` 的驗證因此需要放寬——見 Step 2。）

- [ ] **Step 2: 放寬驗證：加入 `room: true` 中繼資料**

在 `LevelMap` 加：`meta` 有 `room: true` 時跳過「恰好一個 `S`」與「至少一個 `F`/`K`」
兩條驗證。補測試：

```gdscript
func test_room_levels_skip_spawn_and_goal_validation() -> void:
	var m := LevelMap.parse("room: true\npipe1: __return__\n---\n# 1 #\n#####")
	assert_true(m.is_valid(), str(m.errors))
```
在 `level1_pipe_a.txt` 的中繼資料加上 `room: true`。

- [ ] **Step 3: 跑測試確認新測試先失敗、實作後通過**

Run: `tools/run_tests.sh`

- [ ] **Step 4: 建三個場景並接進 `LevelBuilder` 與 `main.gd`**

- [ ] **Step 5: 驗證與擷圖** — `tools/verify_game.sh` 全綠

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "加入移動平台、水管隱藏房與檢查點"
```

---

### Task 13: 關底 Boss 與旗竿

**Files:**
- Create: `scenes/boss.tscn/gd`, `scenes/goal_flag.tscn/gd`
- Modify: `scenes/level_builder.gd`、`scenes/main.gd`
- Test: `test/unit/test_boss_rules.gd`

**Interfaces:**
- Consumes: `EnemyRules`
- Produces:
  - `scripts/boss_rules.gd`：`BossRules.MAX_HP = 3`、`BossRules.SHOT_DAMAGE`（金幣 6 發 = 每發 0.5）、
    `BossRules.apply_stomp(hp: float) -> float`、`BossRules.apply_shot(hp: float) -> float`、
    `BossRules.is_dead(hp: float) -> bool`
  - `Boss` 訊號 `defeated`、`touched_player`；`Boss.hp: float`

**行為：** Boss 在關底約 6 格寬的範圍內來回踱步（90 px/s），每 2.5 秒朝玩家
拋一顆「跌停箭頭」。踩一次扣 1 點、金幣一發扣 0.5 點；受擊後 0.8 秒無敵並閃白。
擊敗後旗竿才可互動（旗竿在 Boss 存活時 `monitoring = false`）。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_boss_rules.gd`**

```gdscript
extends GutTest

func test_three_stomps_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 3:
		hp = BossRules.apply_stomp(hp)
	assert_true(BossRules.is_dead(hp))

func test_two_stomps_do_not_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	hp = BossRules.apply_stomp(hp)
	hp = BossRules.apply_stomp(hp)
	assert_false(BossRules.is_dead(hp))

func test_six_coin_shots_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 6:
		hp = BossRules.apply_shot(hp)
	assert_true(BossRules.is_dead(hp))

func test_five_coin_shots_do_not_kill_boss() -> void:
	var hp := float(BossRules.MAX_HP)
	for i in 5:
		hp = BossRules.apply_shot(hp)
	assert_false(BossRules.is_dead(hp))
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/boss_rules.gd`**

- [ ] **Step 4: 跑測試確認通過** — Expected 4 個 PASS

- [ ] **Step 5: 建 `boss.tscn/gd` 與 `goal_flag.tscn/gd`，接進 `LevelBuilder` 與 `main.gd`**

- [ ] **Step 6: 驗證** — `tools/verify_game.sh` 全綠

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "加入關底 Boss熊與終點旗竿"
```

---

### Task 14: HUD、相機與流程狀態機

**Files:**
- Create: `scenes/hud.tscn`, `scenes/hud.gd`, `assets/theme.tres`
- Modify: `scenes/main.gd`

**Interfaces:**
- Consumes: `RunStats`
- Produces:
  - `HUD.update_stats(stats: RunStats) -> void`
  - `HUD.show_message(title: String, subtitle: String) -> void`、`HUD.hide_message() -> void`
  - `Main` 流程常數 `TITLE/PLAYING/DEAD/GAME_OVER/CLEARED`
  - `scripts/flow.gd`：`Flow.next(state: int, event: String, lives_left: int) -> int`

- [ ] **Step 1: 寫失敗測試 `test/unit/test_flow.gd`**

```gdscript
extends GutTest

func test_start_moves_title_to_playing() -> void:
	assert_eq(Flow.next(Flow.TITLE, "start", 3), Flow.PLAYING)

func test_death_with_lives_left_returns_to_playing() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "died", 2), Flow.PLAYING)

func test_death_without_lives_is_game_over() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "died", 0), Flow.GAME_OVER)

func test_reaching_goal_clears() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "goal", 3), Flow.CLEARED)

func test_restart_from_game_over_goes_to_title() -> void:
	assert_eq(Flow.next(Flow.GAME_OVER, "restart", 0), Flow.TITLE)
	assert_eq(Flow.next(Flow.CLEARED, "restart", 3), Flow.TITLE)

func test_unknown_event_keeps_state() -> void:
	assert_eq(Flow.next(Flow.PLAYING, "sneeze", 3), Flow.PLAYING)
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL

- [ ] **Step 3: 寫 `scripts/flow.gd`**

- [ ] **Step 4: 跑測試確認通過** — Expected 6 個 PASS

- [ ] **Step 5: 建 `hud.tscn/gd` 與 `assets/theme.tres`**

`CanvasLayer` ＋ 上排 `HBoxContainer`（分數／金幣／生命／時間四個 `Label`）
＋ 置中的 `VBoxContainer` 訊息區（標題 `Label` ＋ 副標 `Label`），
字型用 `NotoSansTC-Bold.otf`，主標 64 px、副標 28 px，加深色描邊確保在天空背景上看得清。
標題畫面文字：「口袋牛牛大冒險」／「按空白鍵開始　方向鍵移動　空白鍵跳　Shift 丟金幣」。

- [ ] **Step 6: 把流程接進 `main.gd`**

`TITLE` 時暫停關卡邏輯（`Entities` 的 `process_mode` 設 `DISABLED`）；
`PLAYING` 每幀 `stats.tick(delta)`，時間到發 `died`；
`DEAD` 播 0.9 秒死亡動畫後重生於最後檢查點；`CLEARED` 呼叫 `stats.finish()` 並顯示結算。

- [ ] **Step 7: 驗證與擷圖三張（標題、遊玩、通關）**

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "加入 HUD、相機與遊戲流程狀態機"
```

---

### Task 15: 主關卡排版

**Files:**
- Create: `levels/level1.txt`
- Modify: `scenes/main.gd`（主關卡改讀 `level1.txt`）
- Test: `test/unit/test_level1_content.gd`

**Interfaces:**
- Consumes: `LevelMap`
- Produces: 約 300 格寬 × 14 格高的主關卡

**四段節奏**（依規格）：教學段 0–60 格、道具段 60–140 格、立體段 140–250 格、關底段 250–300 格。

- [ ] **Step 1: 寫失敗測試 `test/unit/test_level1_content.gd`**

```gdscript
extends GutTest

var m: LevelMap

func before_all() -> void:
	m = LevelMap.parse(FileAccess.get_file_as_string("res://levels/level1.txt"))

func test_level1_parses_cleanly() -> void:
	assert_true(m.is_valid(), str(m.errors))

func test_level1_is_a_long_level() -> void:
	assert_gt(m.width, 260)
	assert_lt(m.width, 340)
	assert_eq(m.height, 14)

func test_level1_has_every_mechanic() -> void:
	var types: Dictionary = {}
	for e in m.entities:
		types[e["type"]] = int(types.get(e["type"], 0)) + 1
	for needed in ["coin", "bear", "spikeball", "arrow", "platform_h",
			"platform_v", "pipe", "checkpoint", "goal", "boss"]:
		assert_true(types.has(needed), "主關卡缺少 %s" % needed)

func test_level1_has_blocks_of_each_kind() -> void:
	var kinds: Dictionary = {}
	for y in m.height:
		for x in m.width:
			var k := m.terrain_at(Vector2i(x, y))
			kinds[k] = true
	for needed in [TileGlossary.KIND_GROUND, TileGlossary.KIND_BRICK,
			TileGlossary.KIND_QUESTION, TileGlossary.KIND_MILK_BRICK,
			TileGlossary.KIND_BREAKABLE, TileGlossary.KIND_SPIKE]:
		assert_true(kinds.has(needed), "主關卡缺少地形 %d" % needed)

func test_teaching_section_has_no_hazards() -> void:
	for e in m.entities:
		if e["type"] in ["spikeball", "arrow"]:
			assert_gt(e["cell"].x, 60, "前 60 格不該有進階危險物")

func test_pipe_room_file_exists() -> void:
	assert_true(FileAccess.file_exists("res://levels/level1_pipe_a.txt"))
```

- [ ] **Step 2: 跑測試確認失敗** — Expected FAIL（`level1.txt` 不存在）

- [ ] **Step 3: 排版 `levels/level1.txt`**

用 Python 輔助組裝（`tools/build_level1.py`，把四段各自的字元區塊拼接並補齊行寬），
或直接手寫。排完務必目視每一段的擷圖，確認跳躍距離在 3.7 格跳躍高度與
4.4 格/秒跑速下都過得去（最寬的坑不超過 5 格）。

- [ ] **Step 4: 跑測試確認通過** — Expected 6 個 PASS

- [ ] **Step 5: 逐段擷圖確認**（相機起點、道具段、立體段、關底各一張）

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "排入主關卡：教學、道具、立體、關底四段節奏"
```

---

### Task 16: 整合測試、網頁匯出與說明文件

**Files:**
- Create: `tools/integration_check.gd`, `tools/integration_check.tscn`, `export_presets.cfg`, `README.md`
- Modify: `tools/verify_game.sh`（接上整合測試）

**Interfaces:**
- Consumes: 全部
- Produces: headless 整合測試、`build/web/index.html`、專案 README

- [ ] **Step 1: 寫 `tools/integration_check.gd`**

headless 檢查項（每項印「通過」或「失敗」，最後非零結束碼代表失敗）：
1. `levels/level1.txt` 與 `levels/level1_pipe_a.txt` 都能解析且 `is_valid()`
2. 主場景能 `instantiate` 並 `_ready` 不報錯
3. `LevelBuilder.build` 產出的實體數等於 `map.entities.size()`
4. 玩家在 60 幀內 `is_on_floor()` 為真（會落地，不會穿地）
5. 手動呼叫 `player.apply_stomp(false)` 後 `velocity.y` 等於 `PlayerPhysics.stomp_velocity(false)`
6. `RunStats` 撿金幣加分、`Flow.next` 通關轉態
7. 相機 `limit_right` 等於關卡寬度 × 64

- [ ] **Step 2: 把整合測試接進 `tools/verify_game.sh`（複製 Game2 的第三段）**

- [ ] **Step 3: 跑完整驗證**

Run: `tools/verify_game.sh`
Expected: `=== 全部驗證通過 ===`

- [ ] **Step 4: 寫 `export_presets.cfg`（Web preset，複製 Game2 並改輸出路徑）並匯出**

```bash
/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" build/web/index.html
```
Expected: `build/web/index.{html,js,wasm,pck}` 都產出

- [ ] **Step 5: 寫 `README.md`**（玩法、操作、開發指令、專案結構、架構重點、關卡字元表、授權，格式對齊 Game1/Game2）

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "加入整合測試、網頁匯出設定與專案說明"
```

---

## Self-Review

**1. 規格覆蓋**

| 規格章節 | 對應任務 |
|---|---|
| 技術決策（視窗、拉伸、操作、格子） | Task 1 |
| 架構（目錄、兩條規則、資料流） | Task 1、8 |
| 玩家物理（13 個參數） | Task 4 |
| 玩家狀態機（含丟金幣為 BIG 專屬） | Task 5、11 |
| 擠壓拉伸動畫 8 種情境 | Task 8 |
| 關卡格式與字元表 | Task 2、3 |
| 解析輸出與 4 條驗證 | Task 3（第 5 條 `room` 放寬在 Task 12） |
| 關卡設計四段節奏與隱藏房 | Task 15、12 |
| 相機 | Task 8、14 |
| HUD 與流程 | Task 14 |
| 素材管線 10 項產出 | Task 7 |
| 測試策略三層 | Task 2–6、9–14（單元）、16（整合）、8+（擷圖） |
| 網頁匯出 | Task 16 |

無缺口。

**2. 佔位符掃描**：無 TBD／TODO；每個測試步驟都有可執行的斷言程式碼；
每個實作步驟都指明檔案、類別、常數值與演算法順序。

**3. 型別一致性**：`TileGlossary.KIND_*` 在 Task 2 定義，Task 3、10、15 沿用同名；
`PlayerPhysics.step` 的 `Dictionary` 介面在 Task 4 定義，Task 8 沿用；
`RunStats.spend_coin` 在 Task 6 定義，Task 11 沿用；`EnemyRules.KIND_*` 在 Task 9
定義，Task 13 沿用。`LevelMap` 的 `room` 中繼資料在 Task 12 才引入，Task 3 的
驗證測試不受影響（測試資料未帶 `room`）。
