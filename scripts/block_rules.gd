class_name BlockRules
extends RefCounted

## 從下方頂磚塊會發生什麼。純邏輯，因為「大牛頂可破磚才會碎」這種條件
## 分支最容易在改動時被弄錯。
##
## 問號磚與牛奶磚外觀相同（TileGlossary 讓它們共用圖集第 2 欄），玩家要頂
## 了才知道裡面是什麼。這讓每一塊磚都值得一試，也讓關卡設計多一個藏東西
## 的地方。

## 這幾種磚塊要各自記住「被頂過了沒」，所以不能進 TileMapLayer，
## 得生成獨立節點。
const _NODE_KINDS := [
	TileGlossary.KIND_QUESTION,
	TileGlossary.KIND_MILK_BRICK,
	TileGlossary.KIND_BREAKABLE,
]


static func needs_node(kind: int) -> bool:
	return _NODE_KINDS.has(kind)


## 回 "coin" / "milk" / "broke" / "bounce" / "spent"。
static func resolve_hit(kind: int, player_is_big: bool, already_used: bool) -> String:
	if already_used:
		return "spent"
	match kind:
		TileGlossary.KIND_QUESTION:
			return "coin"
		TileGlossary.KIND_MILK_BRICK:
			return "milk"
		TileGlossary.KIND_BREAKABLE:
			return "broke" if player_is_big else "bounce"
	return "bounce"


## 頂過之後該顯示哪一欄貼圖。可破磚被小牛頂不會變樣子，所以維持原欄。
static func spent_column(kind: int) -> int:
	if kind == TileGlossary.KIND_BREAKABLE:
		return TileGlossary.atlas_column(TileGlossary.KIND_BREAKABLE)
	return TileGlossary.atlas_column(TileGlossary.KIND_USED_BRICK)
