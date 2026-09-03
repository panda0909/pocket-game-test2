class_name ThrowRules
extends RefCounted

## 丟金幣的條件。獨立成一個類別是因為它跨了兩個狀態物件——體型與彈藥——
## 而「條件沒過就不該扣彈藥」這種事寫在節點裡很容易漏。
##
## 丟金幣是 BIG 專屬能力，每發消耗一枚撿到的金幣。這讓一個道具解鎖兩件事
## （變耐打、解鎖攻擊），也讓金幣從「撿了就沒事」變成一個取捨。

static func can_fire(state: PlayerState, stats: RunStats) -> bool:
	return state.can_throw() and stats.coins > 0


## 真的開火：條件過了才扣彈藥。回傳是否成功。
static func fire(state: PlayerState, stats: RunStats) -> bool:
	if not can_fire(state, stats):
		return false
	return stats.spend_coin()
