class_name PlayerState
extends RefCounted

## 玩家的體型與無敵狀態。純邏輯，狀態轉移表的每一格都有測試。
##
## 為什麼要有「變大」這一層：它讓關卡設計多了一個節奏工具。放牛奶磚的位置
## 就是安全點，玩家也會願意為了那塊磚去冒險。而且撞一下不會直接死，長關卡
## 才不會變成「一失誤就重來十五個畫面」。
##
## 丟金幣是 BIG 專屬能力（見 ThrowRules）。這樣一個道具解鎖兩件事——變耐打
## 與解鎖攻擊——就不必再多做第三階道具。

const SMALL := 0
const BIG := 1

const INVINCIBLE_TIME := 1.2
const BIG_SCALE := 1.4

var size := SMALL
var invincible_left := 0.0


func is_invincible() -> bool:
	return invincible_left > 0.0


func is_big() -> bool:
	return size == BIG


func can_throw() -> bool:
	return is_big()


## 身體縮放倍率，供 player.gd 的擠壓拉伸當基準。
func body_scale() -> float:
	return BIG_SCALE if is_big() else 1.0


func advance(delta: float) -> void:
	if invincible_left > 0.0:
		invincible_left = maxf(0.0, invincible_left - delta)


## 回 "died" / "shrank" / "ignored"。
func take_hit() -> String:
	if is_invincible():
		return "ignored"
	if is_big():
		size = SMALL
		invincible_left = INVINCIBLE_TIME
		return "shrank"
	return "died"


## 回 "grew" / "bonus"。
func collect_milk() -> String:
	if is_big():
		return "bonus"
	size = BIG
	return "grew"


func reset() -> void:
	size = SMALL
	invincible_left = 0.0
