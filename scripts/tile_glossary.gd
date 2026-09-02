class_name TileGlossary
extends RefCounted

## 關卡文字檔裡「一個字元」的語意，是全專案唯一的真相來源。
##
## 為什麼要獨立成一個類別：關卡解析器、關卡建構器、磚塊規則、素材圖集切割
## 四個地方都得知道「`?` 是問號磚、問號磚是實心、它在圖集第 3 格」。散落在
## 各處的話，加一種格子就得同時改四個地方，而且漏改不會有人告訴你。
##
## 地形與實體刻意分成兩張表。同一個格子不會同時是地形和實體——實體所在的格
## 子地形一律是空的，敵人與道具站在自己的節點裡，不進 TileMapLayer。

const KIND_EMPTY := 0
const KIND_GROUND := 1
const KIND_BRICK := 2
const KIND_QUESTION := 3
const KIND_MILK_BRICK := 4
const KIND_BREAKABLE := 5
const KIND_SPIKE := 6
const KIND_USED_BRICK := 7

## 水管口不是地形（水管是實體節點），但貼圖和地形共用同一張圖集，
## 所以欄位編號也在這裡定義，讓 pipe.tscn 不必自己記數字。
const PIPE_ATLAS_COLUMN := 6

const _TERRAIN := {
	" ": KIND_EMPTY,
	"#": KIND_GROUND,
	"=": KIND_BRICK,
	"?": KIND_QUESTION,
	"M": KIND_MILK_BRICK,
	"x": KIND_BREAKABLE,
	"^": KIND_SPIKE,
}

const _ENTITY := {
	"o": "coin",
	"b": "bear",
	"s": "spikeball",
	"a": "arrow",
	"P": "platform_h",
	"V": "platform_v",
	"C": "checkpoint",
	"S": "spawn",
	"F": "goal",
	"K": "boss",
}

## 尖刺刻意不算實心：它用 Area2D 造成傷害，玩家該踩得進去而不是站在上面。
const _SOLID := [
	KIND_GROUND, KIND_BRICK, KIND_QUESTION,
	KIND_MILK_BRICK, KIND_BREAKABLE, KIND_USED_BRICK,
]

## 對應 assets/tiles.png 的橫向欄位順序。牛奶磚與問號磚外觀相同（都是問號），
## 玩家要頂了才知道裡面是什麼——這是刻意的，讓每塊磚都值得一試。
const _ATLAS_COLUMN := {
	KIND_GROUND: 0,
	KIND_BRICK: 1,
	KIND_QUESTION: 2,
	KIND_MILK_BRICK: 2,
	KIND_USED_BRICK: 3,
	KIND_BREAKABLE: 4,
	KIND_SPIKE: 5,
}

const _PIPE_DIGITS := "123456789"


## 回傳字元的地形種類，不是地形（含未知字元）回 -1。
static func terrain_kind(ch: String) -> int:
	return _TERRAIN.get(ch, -1)


## 回傳字元的實體型別字串，不是實體回空字串。
static func entity_type(ch: String) -> String:
	if pipe_index(ch) > 0:
		return "pipe"
	return _ENTITY.get(ch, "")


static func is_known(ch: String) -> bool:
	return _TERRAIN.has(ch) or _ENTITY.has(ch) or pipe_index(ch) > 0


static func is_solid(kind: int) -> bool:
	return _SOLID.has(kind)


## 圖集欄位；空格與未知種類回 -1（代表不需要畫）。
static func atlas_column(kind: int) -> int:
	return _ATLAS_COLUMN.get(kind, -1)


## "1"–"9" 回 1–9，其餘回 0。
static func pipe_index(ch: String) -> int:
	if ch.length() != 1:
		return 0
	return _PIPE_DIGITS.find(ch) + 1
