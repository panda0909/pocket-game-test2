class_name Powerup
extends Area2D

## 漲停牛奶。從磚裡頂出來，斜斜落到地面上等人撿。
##
## 走過兩個版本才對：
##
## 第一版停在磚上。拿不到——磚塊為了讓大牛鑽得過去必須離地 3 格，停在它
## 上面的道具就落在 460 px 高，而玩家從地面起跳頭頂只到 532 px（y 越小越高）。
##
## 第二版改成用 RayCast2D 往下找地面自己掉。還是拿不到，而且原因更隱晦：
## 射線第一個打到的就是它自己剛頂出來的那塊磚，於是它落在磚頂，等於回到
## 第一版。
##
## 現在的版本由 Main 用關卡資料直接算出該落在哪一列——關卡是純資料，這種
## 「底下第一格實心地面在哪」的問題本來就該問資料，而不是在場景裡打射線。
## 順便往側邊偏一點，看起來是從磚邊滑下來的，不會穿過磚身。

const POP_HEIGHT := 44.0
const POP_TIME := 0.24
const FALL_TIME := 0.42
const SIDE_DRIFT := 52.0
## 貼圖 52 高，原點在中心，所以落地時中心要比地面高這麼多。
const GROUND_OFFSET := 26.0

var _landed := false


func _ready() -> void:
	add_to_group("powerup")


## 由 Main 呼叫。target_ground_y 是地面表面的像素 y，direction 是滑落方向。
func drop_to(target_ground_y: float, direction: int) -> void:
	var landing := Vector2(position.x + SIDE_DRIFT * direction,
		target_ground_y - GROUND_OFFSET)

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - POP_HEIGHT, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", landing, FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_landed)


func _on_landed() -> void:
	_landed = true
	var bob := create_tween().set_loops()
	bob.tween_property(self, "scale", Vector2(1.07, 0.93), 0.55) \
		.set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "scale", Vector2(1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE)
