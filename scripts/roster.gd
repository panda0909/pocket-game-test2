class_name Roster
extends RefCounted

## 可選主角的名冊，是角色清單的唯一真相。
##
## 三隻是純換皮：碰撞箱、物理參數、狀態機全部共用，只有貼圖不同。這是刻意的
## ——關卡的幾何驗收（跳躍距離、磚台高度、大牛淨空）是照一組數值算出來的，
## 一旦某隻角色跳得比較低，同一張關卡對牠來說就可能有跳不上去的地方。要做
## 有數值差異的角色，得連帶把那些關卡測試改成「三組數值各驗一次」。
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
