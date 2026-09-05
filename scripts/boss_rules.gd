class_name BossRules
extends RefCounted

## 關底 Boss熊的血量規則。
##
## 三次踩踏或六發金幣。兩條路徑都留著是刻意的：玩家如果一路把金幣都丟光了
## 還是能靠踩踏過關，不會被卡在關底。踩踏風險高（要貼近）、金幣風險低但要
## 先攢彈藥，兩種玩法都成立。

## 移動與投擲的節奏。以前這幾個數字留在 boss.gd，而血量在這裡——
## 同一隻 Boss 的參數分居兩地，最需要調的那幾個反而沒有測試也沒有單一出處。
const GRAVITY := 1400.0
const WALK_SPEED := 90.0
const PATROL_HALF_WIDTH := 192.0
const THROW_INTERVAL := 2.5
## Boss 的碰撞箱。大牛身高 168 px（120 × BIG_SCALE 1.4），所以 104 高的 Boss
## 站在大牛旁邊比玩家還矮——關底的壓迫感整個沒了，而且牠和第 45 格的普通
## 小熊是同一個造型只多一頂皇冠。放大到 198 之後才明顯比玩家大一截。
##
## 上限受制於踩踏：頭頂 = 地面 768 − 198 = 570，而從地面滿跳腳底到 532，
## 還搆得到。再高就踩不到了。
const BODY_SIZE := Vector2(182, 198)
## 瞄準玩家身體中段。
const AIM_OFFSET := Vector2(0, 60)

## 玩家離 Boss 多近才顯示血條。設計解析度的半個畫面寬——Boss 一進視野
## 血條就在，但不會從第 0 格就掛著。
##
## 為什麼不用 VisibleOnScreenNotifier2D：那是渲染層的東西，headless 下不觸發，
## 於是這條規則沒辦法被測試守著。而「血條什麼時候出現」是設計決定，
## 本來就該是一條可測的規則。
const BAR_RANGE := 700.0

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


## 踱步方向：走出範圍就往回。
static func patrol_direction(current_x: float, origin_x: float,
		direction: int) -> int:
	if absf(current_x - origin_x) <= PATROL_HALF_WIDTH:
		return direction
	return -1 if current_x > origin_x else 1


## 投射物的初速。與 EnemyRules.dive_velocity 同理：零向量要有安全的預設方向。
static func aim_velocity(from: Vector2, target: Vector2,
		speed: float) -> Vector2:
	var to_target := target - from
	if to_target.length_squared() < 1.0:
		return Vector2.DOWN * speed
	return to_target.normalized() * speed


## 該不該顯示 Boss 血條。
static func should_show_bar(player_x: float, boss_x: float) -> bool:
	return absf(player_x - boss_x) <= BAR_RANGE
