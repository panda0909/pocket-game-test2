class_name Roster
extends RefCounted

## 可選主角的名冊，是角色清單的唯一真相。
##
## 三隻是純換皮：碰撞箱、物理參數、狀態機全部共用，只有貼圖不同。這是刻意的
## ——關卡的幾何驗收（跳躍距離、磚台高度、大牛淨空）是照一組數值算出來的，
## 一旦某隻角色跳得比較低，同一張關卡對牠來說就可能有跳不上去的地方。要做
## 有數值差異的角色，得連帶把那些關卡測試改成「三組數值各驗一次」。
##
## 三隻的原圖都是 180 px 高，所以 Player 的 BASE_SPRITE_SCALE 直接適用，
## 不需要為個別角色調縮放。壁虎的原圖較寬（150 vs 131／129），視覺上會比另
## 兩隻寬一點，尾巴會突出碰撞箱——平台遊戲的慣例是「看起來大、判定小」，
## 對玩家有利，所以保留。

const COUNT := 3
const DEFAULT_INDEX := 0

const _NAMES := ["紅牛", "綠恐龍", "橘壁虎"]
const _TEXTURES := [
	"res://assets/characters/red_bull.png",
	"res://assets/characters/dino.png",
	"res://assets/characters/gecko.png",
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


## 往前或往後選一隻，走到頭會繞回另一端。
static func cycle(index: int, step: int) -> int:
	return posmod(clamp_index(index) + step, COUNT)
