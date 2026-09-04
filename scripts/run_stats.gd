class_name RunStats
extends RefCounted

## 一次遊戲的分數、金幣、生命與計時。純邏輯，活在 Main 裡，不隨關卡重建——
## 進水管隱藏房會重建整張關卡，但分數與剩餘時間必須延續。
##
## 金幣同時是分數與彈藥（丟金幣每發消耗一枚）。這讓「撿到的金幣要留著換分
## 還是拿去打怪」變成一個真的取捨，而不是撿了就沒事了。
##
## 丟出去的金幣會把撿到時記的分數退掉。以前不退分，於是取捨根本不成立——
## 分數已經入袋，留著只是佔位，最優解永遠是「撿到就丟」。

const COIN_SCORE := 50
const MILK_BONUS_SCORE := 1000
const TIME_BONUS_PER_SECOND := 10
const START_LIVES := 3
const MAX_LIVES := 9
## 每跨過這個分數送一條命。沒有補命管道的話，15 個畫面的關卡配 3 條命、
## 三次失誤就要從第 0 欄重來，對休閒導向的吉祥物遊戲太嚴苛。
const EXTRA_LIFE_SCORE := 5000

var score := 0
var coins := 0
var lives := START_LIVES
var time_left := 0.0

var _time_limit := 0
## 已經領過的加命里程碑數，避免同一個門檻重複送。
var _lives_granted := 0


func _init(time_limit: int = 300) -> void:
	_time_limit = time_limit
	time_left = float(time_limit)


func add_coin() -> void:
	coins += 1
	add_score(COIN_SCORE)


func add_milk_bonus() -> void:
	add_score(MILK_BONUS_SCORE)


func add_score(amount: int) -> void:
	score = maxi(0, score + amount)
	_grant_milestone_lives()


## 分數跨過里程碑就送命。用「應得總數減已發總數」算，
## 一次加很多分（例如通關的時間獎勵）也不會漏發。
func _grant_milestone_lives() -> void:
	var earned := score / EXTRA_LIFE_SCORE
	while _lives_granted < earned:
		_lives_granted += 1
		add_life()


func add_life() -> void:
	lives = mini(MAX_LIVES, lives + 1)


## 花一枚金幣當彈藥；沒有金幣回 false，呼叫方不該生成投射物。
## 撿到時記的分數會一併退掉——這樣「留著換分還是拿去打怪」才是真的取捨。
func spend_coin() -> bool:
	if coins <= 0:
		return false
	coins -= 1
	score = maxi(0, score - COIN_SCORE)
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
	add_score(seconds_left() * TIME_BONUS_PER_SECOND)
	time_left = 0.0


## 死亡重生：時間重置，分數與金幣延續。
func restart_level() -> void:
	time_left = float(_time_limit)


## HUD 顯示用。向上取整，這樣「剩 0 秒」只在真的歸零時出現。
func seconds_left() -> int:
	return int(ceil(time_left))
