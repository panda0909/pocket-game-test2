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

## 踩踏判定的容差：玩家腳底必須高過敵人中心這麼多像素才算踩到。
## 太小會讓「從側面貼上去」被誤判成踩，太大則會讓明顯踩到的判定不成立。
const STOMP_MARGIN := 8.0

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

const _TEXTURE := {
	KIND_BEAR: "res://assets/enemies/bear.png",
	KIND_SPIKEBALL: "res://assets/enemies/spikeball.png",
	KIND_ARROW: "res://assets/enemies/arrow.png",
}

## 箭頭會主動追人，所以踩死它值多一點分。
const _SCORE := {
	KIND_BEAR: 100,
	KIND_SPIKEBALL: 200,
	KIND_ARROW: 150,
}


static func is_stompable(kind: int) -> bool:
	return _STOMPABLE.has(kind)


static func patrol_speed(kind: int) -> float:
	return _SPEED.get(kind, 0.0)


static func score(kind: int) -> int:
	return _SCORE.get(kind, 0)


static func kind_from_type(type: String) -> int:
	return _TYPE_TO_KIND.get(type, -1)


static func texture_path(kind: int) -> String:
	return _TEXTURE.get(kind, "")


## 巡邏轉向：前方有牆或前方沒地板就回頭。
static func turn_direction(direction: int, blocked_ahead: bool,
		floor_ahead: bool) -> int:
	if blocked_ahead or not floor_ahead:
		return -direction
	return direction


## 這次接觸算不算踩到？
##
## player_velocity_y  玩家垂直速度（正值代表下墜）
## relative_y         玩家腳底相對敵人中心的位置（負值代表在上面）
## enemy_half_height  敵人半高，用來換算容差
static func is_stomp(player_velocity_y: float, relative_y: float,
		enemy_half_height: float) -> bool:
	if player_velocity_y <= 0.0:
		return false
	return relative_y < -minf(STOMP_MARGIN, enemy_half_height * 0.5)
