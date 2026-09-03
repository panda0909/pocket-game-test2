class_name BossRules
extends RefCounted

## 關底 Boss熊的血量規則。
##
## 三次踩踏或六發金幣。兩條路徑都留著是刻意的：玩家如果一路把金幣都丟光了
## 還是能靠踩踏過關，不會被卡在關底。踩踏風險高（要貼近）、金幣風險低但要
## 先攢彈藥，兩種玩法都成立。

const MAX_HP := 3
const STOMP_DAMAGE := 1.0
const SHOT_DAMAGE := 0.5
const HIT_INVINCIBLE_TIME := 0.8
const SCORE := 3000


static func apply_stomp(hp: float) -> float:
	return maxf(0.0, hp - STOMP_DAMAGE)


static func apply_shot(hp: float) -> float:
	return maxf(0.0, hp - SHOT_DAMAGE)


static func is_dead(hp: float) -> bool:
	return hp <= 0.0


static func health_ratio(hp: float) -> float:
	return clampf(hp / float(MAX_HP), 0.0, 1.0)
