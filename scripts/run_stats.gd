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
## 第一次喝到漲停牛奶。這是整場最重要的轉折（同時解鎖不會一擊死與攻擊），
## 以前它給 0 分也沒有任何浮字，而重複拿才給的 1000 分反而是玩家不需要的那次。
const MILK_FIRST_SCORE := 500
## 已經是大牛時再拿一塊。零風險的重複收集，不該是全關第二大的單筆收益
## （僅次於 Boss 的 3000），否則刷分的最優解就是繞回去重拿。
const MILK_BONUS_SCORE := 200
## 通關時每剩一秒換多少分。
##
## 10 分/秒太低：三條支線的收益換算成時間單價是 100–130 分/秒，差一個
## 數量級，於是「全收集 vs 衝時間」根本不是取捨——全收集無條件輾壓。
## 40 分/秒讓兩邊的量級對得上，取捨才第一次成立。
const TIME_BONUS_PER_SECOND := 40
const START_LIVES := 3
const MAX_LIVES := 9
## 每跨過這個分數送一條命。沒有補命管道的話，15 個畫面的關卡配 3 條命、
## 三次失誤就要從第 0 欄重來，對休閒導向的吉祥物遊戲太嚴苛。
const EXTRA_LIFE_SCORE := 5000

var score := 0
var coins := 0
var lives := START_LIVES
var time_left := 0.0
## 這一局撿過／打倒過多少。和 coins 不同：coins 是手上剩的彈藥，
## 這裡問的是「走過多少內容」，花掉的金幣仍然算撿過。
var found := {"coin": 0, "enemy": 0, "milk": 0}
var targets := {"coin": 0, "enemy": 0, "milk": 0}
## 這一局有沒有受過傷。無傷是硬派玩家最愛的自我設限，而判定成本近乎零。
var flawless := true

var _time_limit := 0
## 已經領過的加命里程碑數，避免同一個門檻重複送。
var _lives_granted := 0
## 沒有加過分的金幣（開局送的）。丟出去時不該退分。
var _unscored_coins := 0


func _init(time_limit: int = 300) -> void:
	_time_limit = time_limit
	time_left = float(time_limit)


func add_coin() -> void:
	coins += 1
	found["coin"] += 1
	add_score(COIN_SCORE)


## 關卡有多少可收集的東西。收集率的分母。
func set_targets(coin: int, enemy: int, milk: int) -> void:
	targets = {"coin": maxi(0, coin), "enemy": maxi(0, enemy),
		"milk": maxi(0, milk)}


func count_enemy_defeated() -> void:
	found["enemy"] += 1


func count_milk_found() -> void:
	found["milk"] += 1


## 受過傷就不再是無傷。死一次重生也不會洗掉——無傷是一整局的事。
func count_damage_taken() -> void:
	flawless = false


## 收集率。三類各佔三分之一，不是「加起來除以總數」——否則金幣多的關卡
## 會讓敵人與牛奶的權重被稀釋到看不見。
func collect_percent() -> int:
	var counted := 0
	var total := 0.0
	for key in targets:
		var goal: int = targets[key]
		if goal <= 0:
			continue
		counted += 1
		total += minf(1.0, float(found[key]) / float(goal))
	if counted == 0:
		return 0
	return int(round(total / float(counted) * 100.0))


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


## 送幾枚開局金幣。角色特性用的，不加分——所以丟出去時也不扣分，
## 否則那個「特性」實際上是負分。
func grant_starting_coins(amount: int) -> void:
	coins += amount
	_unscored_coins += amount


## 花一枚金幣當彈藥；沒有金幣回 false，呼叫方不該生成投射物。
##
## 撿到時記的分數會一併退掉——這樣「留著換分還是拿去打怪」才是真的取捨。
## 但開局送的金幣當初沒有加分，退分時也要跳過，不然紅牛的「多兩枚金幣」
## 會變成 −100 分的陷阱。
func spend_coin() -> bool:
	if coins <= 0:
		return false
	coins -= 1
	if _unscored_coins > 0:
		_unscored_coins -= 1
		return true
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
