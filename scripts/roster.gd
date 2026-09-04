class_name Roster
extends RefCounted

## 可選主角的名冊，是角色清單的唯一真相。
##
## 三隻共用碰撞箱、跳躍高度與走路速度。差異只在「一樣或更寬鬆」的方向：
## 衝刺速度、土狼時間、初始金幣。
##
## 為什麼只能往寬鬆的方向：關卡的幾何驗收（跳躍距離、磚台高度、大牛淨空）
## 是照一組數值算出來的。某隻角色只要跳得比較低或跑得比較慢，同一張關卡
## 對牠就可能有跳不上去、跨不過去的地方，而測試只驗了基準那一組。往寬鬆的
## 方向走則永遠安全——關卡對牠只會更好過。test_roster.gd 有一條測試釘著
## 這個約束，把任何一隻調得比基準難就會失敗。
##
## 純換皮的問題是選角變成純粹的延遲：那是玩家開始前的第一個決策點，
## 但這個決策在機制上是空的，選誰結果完全一樣。
##
## 所有狀態圖統一整理成 180 px 高，所以 Player 的 BASE_SPRITE_SCALE 直接適用。
## 裝備、走路與變身圖都是獨立 sprite；碰撞箱仍然只由 Player 控制。

const COUNT := 3
const DEFAULT_INDEX := 0

const _NAMES := ["紅牛", "綠恐龍", "橘壁虎"]
const _TEXTURES := [
	"res://assets/characters/red_bull_adventure.png",
	"res://assets/characters/dino_adventure.png",
	"res://assets/characters/gecko_adventure.png",
]

const _WALK_TEXTURES := [
	"res://assets/characters/red_bull_walk.png",
	"res://assets/characters/dino_walk.png",
	"res://assets/characters/gecko_walk.png",
]

const _BIG_TEXTURES := [
	"res://assets/characters/red_bull_big.png",
	"res://assets/characters/dino_big.png",
	"res://assets/characters/gecko_big.png",
]


## 每隻角色的手感修飾值。只有這三項，而且全部是「一樣或更寬鬆」。
const _TRAITS := [
	{
		"sprint_speed": PlayerPhysics.SPRINT_SPEED,
		"coyote_time": PlayerPhysics.COYOTE_TIME,
		"start_coins": 2,
		"blurb": "口袋裡多兩枚金幣，開局就有彈藥",
	},
	{
		"sprint_speed": PlayerPhysics.SPRINT_SPEED * 1.08,
		"coyote_time": PlayerPhysics.COYOTE_TIME,
		"start_coins": 0,
		"blurb": "衝刺再快一點，長直線跑得比誰都遠",
	},
	{
		"sprint_speed": PlayerPhysics.SPRINT_SPEED,
		"coyote_time": PlayerPhysics.COYOTE_TIME + 0.06,
		"start_coins": 0,
		"blurb": "踏出平台邊緣後還有更久可以起跳",
	},
]


static func traits(index: int) -> Dictionary:
	return _TRAITS[clamp_index(index)]


## 把任何數字夾成合法索引。參數壞掉時寧可回到預設角色，
## 也不要讓主角變成一張不存在的貼圖。
static func clamp_index(index: int) -> int:
	if index < 0 or index >= COUNT:
		return DEFAULT_INDEX
	return index


static func name_of(index: int) -> String:
	return _NAMES[clamp_index(index)]


static func texture_path(index: int) -> String:
	return _TEXTURES[clamp_index(index)]


static func walk_texture_path(index: int) -> String:
	return _WALK_TEXTURES[clamp_index(index)]


static func big_texture_path(index: int) -> String:
	return _BIG_TEXTURES[clamp_index(index)]


## 往前或往後選一隻，走到頭會繞回另一端。
static func cycle(index: int, step: int) -> int:
	return posmod(clamp_index(index) + step, COUNT)
