class_name RunStats
extends RefCounted

## 一次遊戲的分數、金幣、生命與計時。純邏輯，活在 Main 裡，不隨關卡重建——
## 進水管隱藏房會重建整張關卡，但分數與剩餘時間必須延續。
##
## 金幣同時是分數與彈藥（丟金幣每發消耗一枚）。這讓「撿到的金幣要留著換分
## 還是拿去打怪」變成一個真的取捨，而不是撿了就沒事了。
## 花掉的金幣不退分——分數在撿到的瞬間就記帳了。

const COIN_SCORE := 50
const STOMP_SCORE := 100
const MILK_BONUS_SCORE := 1000
const TIME_BONUS_PER_SECOND := 10
const START_LIVES := 3

var score := 0
var coins := 0
var lives := START_LIVES
var time_left := 0.0

var _time_limit := 0


func _init(time_limit: int = 300) -> void:
	_time_limit = time_limit
	time_left = float(time_limit)


func add_coin() -> void:
	coins += 1
	score += COIN_SCORE


func add_stomp() -> void:
	score += STOMP_SCORE


func add_milk_bonus() -> void:
	score += MILK_BONUS_SCORE


func add_score(amount: int) -> void:
	score += amount


## 花一枚金幣當彈藥；沒有金幣回 false，呼叫方不該生成投射物。
func spend_coin() -> bool:
	if coins <= 0:
		return false
	coins -= 1
	return true


## 扣一命，回「還有命可以繼續」。
func lose_life() -> bool:
	lives = maxi(0, lives - 1)
	return lives > 0


## 倒數計時，回「時間到了」。
func tick(delta: float) -> bool:
	if time_left <= 0.0:
		return true
	time_left = maxf(0.0, time_left - delta)
	return time_left <= 0.0


## 通關結算：剩餘秒數換分。
func finish() -> void:
	score += seconds_left() * TIME_BONUS_PER_SECOND
	time_left = 0.0


## 死亡重生：時間重置，分數與金幣延續。
func restart_level() -> void:
	time_left = float(_time_limit)


## HUD 顯示用。向上取整，這樣「剩 0 秒」只在真的歸零時出現。
func seconds_left() -> int:
	return int(ceil(time_left))
