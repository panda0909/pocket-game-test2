class_name EnemyRules
extends RefCounted

## 三種敵人的規則。純邏輯，所以「什麼算踩到」這種容易寫錯的判定有測試守著。
##
## 三種敵人各自教玩家一件事：
##   小熊     可以踩 —— 基本的攻擊手段
##   刺球     不可以踩 —— 有些東西只能繞過或用金幣打
##   跌停箭頭 會主動來找你 —— 站在原地不動不一定安全
##
## 刺球不可踩是這組設計的關鍵。如果所有敵人都能踩，玩家會養成「看到就跳上去」
## 的反射，關卡就沒有辨識的樂趣了。

const KIND_BEAR := 0
const KIND_SPIKEBALL := 1
const KIND_ARROW := 2

const BEAR_SPEED := 60.0
const SPIKEBALL_SPEED := 30.0

const ARROW_TRIGGER_RANGE := 320.0
const ARROW_DIVE_SPEED := 260.0
## 箭頭懸空時的上下浮動。頻率與振幅原本寫死在 enemy.gd 裡，
## 於是同一隻敵人的參數散在兩個檔案，調手感要翻兩處。
const ARROW_FLOAT_SPEED := 2.4
const ARROW_FLOAT_AMPLITUDE := 24.0
## 瞄準玩家身體中段而不是腳底，不然俯衝會擦過去。
const ARROW_AIM_OFFSET := Vector2(0, 40)

const GRAVITY := 1400.0
## 敵人也要有終端速度。少了它，任何離開地板的敵人（磚台被打碎、被放在坑上方）
## 會無限加速下墜，節點永不釋放，_physics_process 永遠在跑。
const TERMINAL_FALL := 900.0

## 踩踏容差：上一幀腳底就算已經越過敵人頭頂這麼多像素，仍然算踩到。
## 少了它判定窗會窄到玩家覺得遊戲在耍賴；太大則會讓「從側面貼上去」也被
## 誤判成踩。12 px 約是敵人身高的四分之一。
const STOMP_TOLERANCE := 12.0

## 各種敵人的碰撞箱。半高是踩踏判定要用的，而「踩上去能彈多高」是關卡
## 排版要問的問題——所以這份尺寸屬於規則層，不是節點層。以前它留在
## enemy.gd 裡，關卡的幾何驗收就問不到。
const _BODY := {
	KIND_BEAR: Vector2(44, 50),
	KIND_SPIKEBALL: Vector2(46, 46),
	KIND_ARROW: Vector2(40, 44),
}

const _STOMPABLE := [KIND_BEAR, KIND_ARROW]

const _SPEED := {
	KIND_BEAR: BEAR_SPEED,
	KIND_SPIKEBALL: SPIKEBALL_SPEED,
	KIND_ARROW: 0.0,
}

const _TYPE_TO_KIND := {
	"bear": KIND_BEAR,
	"spikeball": KIND_SPIKEBALL,
	"arrow": KIND_ARROW,
}

## preload 而不是執行期 load：路徑打錯是編譯期就報，而且資源有了明確的
## 參考，不必再靠 export_presets.cfg 的 include_filter 手動列白名單。
const _TEXTURE := {
	KIND_BEAR: preload("res://assets/enemies/bear.png"),
	KIND_SPIKEBALL: preload("res://assets/enemies/spikeball.png"),
	KIND_ARROW: preload("res://assets/enemies/arrow.png"),
}

## 箭頭會主動追人，所以踩死它值多一點分。
const _SCORE := {
	KIND_BEAR: 100,
	KIND_SPIKEBALL: 200,
	KIND_ARROW: 150,
}


static func body_size(kind: int) -> Vector2:
	return _BODY.get(kind, Vector2(44, 44))


static func body_height(kind: int) -> float:
	return body_size(kind).y


static func is_stompable(kind: int) -> bool:
	return _STOMPABLE.has(kind)


static func patrol_speed(kind: int) -> float:
	return _SPEED.get(kind, 0.0)


static func score(kind: int) -> int:
	return _SCORE.get(kind, 0)


static func kind_from_type(type: String) -> int:
	return _TYPE_TO_KIND.get(type, -1)


static func texture(kind: int) -> Texture2D:
	return _TEXTURE.get(kind)


static func texture_path(kind: int) -> String:
	var res: Texture2D = _TEXTURE.get(kind)
	return "" if res == null else res.resource_path


## 巡邏轉向：前方有牆或前方沒地板就回頭。
static func turn_direction(direction: int, blocked_ahead: bool,
		floor_ahead: bool) -> int:
	if blocked_ahead or not floor_ahead:
		return -direction
	return direction


## 這次接觸算不算踩到？
##
## 判定看的是**上一幀**腳底在不在敵人頭頂上方，不是當幀的相對位置。
##
## 為什麼不能用當幀位置：第一版拿「腳底相對敵人中心」判，可判定的區間只有
## 幾個像素寬——偵測要等碰撞框重疊才開始，而那時腳底已經陷進敵人體內一截。
## 玩家以 600 px/s 墜落一幀移動 10 px，實測會從「還在上面」直接跳到「已經
## 穿過腰部」，整個窗口被跨過去，於是每次都判成受傷。用上一幀的位置就對幀率
## 免疫：只要腳底是從上面越過頭頂線的，不管一幀跨多遠都算踩到。
##
## player_velocity_y  玩家垂直速度（正值代表下墜）
## previous_feet_y    上一幀玩家腳底的世界座標 y
## enemy_top_y        敵人頭頂的世界座標 y
static func is_stomp(player_velocity_y: float, previous_feet_y: float,
		enemy_top_y: float) -> bool:
	if player_velocity_y <= 0.0:
		return false
	return previous_feet_y <= enemy_top_y + STOMP_TOLERANCE


## 套用重力並夾住終端速度。
static func apply_gravity(velocity_y: float, delta: float) -> float:
	return minf(velocity_y + GRAVITY * delta, TERMINAL_FALL)


## 懸空浮動時的垂直速度。
static func float_velocity(phase: float) -> Vector2:
	return Vector2(0.0, sin(phase) * ARROW_FLOAT_AMPLITUDE)


## 俯衝速度。
##
## 不要直接寫 (target - from).normalized() * SPEED：玩家剛好站在瞄準點上時
## 那是零向量，Godot 的 normalized() 回 Vector2.ZERO 且不報錯，箭頭會停在
## 半空中抖動直到玩家走開。零向量時往下衝，至少行為是可預期的。
static func dive_velocity(from: Vector2, target: Vector2) -> Vector2:
	var to_target := target - from
	if to_target.length_squared() < 1.0:
		return Vector2.DOWN * ARROW_DIVE_SPEED
	return to_target.normalized() * ARROW_DIVE_SPEED
