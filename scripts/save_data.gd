class_name SaveData
extends RefCounted

## 玩家的最佳紀錄。純資料加合併規則，所以「什麼情況該覆蓋紀錄」有測試守著；
## 讀寫檔案那一層薄薄一段在最下面。
##
## 為什麼需要它：結束畫面的分享按鈕預設玩家想刷分，但重開瀏覽器分數就歸零，
## 刷分沒有對照組。三隻角色是純換皮也沒有解鎖物，重玩動機只剩
## 「我剛剛那次比較快」。

const PATH := "user://save.cfg"

var best_score := 0
var best_coins := 0
## 通關時剩下幾秒。越多代表打得越快；沒通關過就是 0。
var best_time_left := 0
## 通關過就永遠是 true，之後打不完也不會被清掉。
var cleared := false
## 最佳收集率。和最高分各留各的——衝分的那局常常不是收集最多的那局。
var best_collect_pct := 0
## 有沒有無傷通關過。拿過就永遠是拿過。
var flawless_clear := false


## 記一局的成績，回傳「有沒有刷新最高分」。
func record_run(score: int, coins: int, did_clear: bool, time_left: int,
		collect_pct := 0, flawless := false) -> bool:
	var is_record := score > best_score
	best_score = maxi(best_score, score)
	best_coins = maxi(best_coins, coins)
	best_collect_pct = maxi(best_collect_pct, collect_pct)
	if did_clear:
		cleared = true
		best_time_left = maxi(best_time_left, time_left)
		# 無傷只有真的通關才算。半路無傷死掉不是成就。
		flawless_clear = flawless_clear or flawless
	return is_record


func to_dict() -> Dictionary:
	return {
		"best_score": best_score,
		"best_coins": best_coins,
		"best_time_left": best_time_left,
		"cleared": cleared,
		"best_collect_pct": best_collect_pct,
		"flawless_clear": flawless_clear,
	}


## 欄位缺漏或型別不對一律退回預設。存檔是玩家硬碟上的檔案，
## 可能被改壞、被舊版本寫過、或根本不存在——這裡不能崩。
static func from_dict(data: Dictionary) -> SaveData:
	var save := SaveData.new()
	save.best_score = _as_int(data.get("best_score"))
	save.best_coins = _as_int(data.get("best_coins"))
	save.best_time_left = _as_int(data.get("best_time_left"))
	save.cleared = _as_bool(data.get("cleared"))
	save.best_collect_pct = mini(100, _as_int(data.get("best_collect_pct")))
	save.flawless_clear = _as_bool(data.get("flawless_clear"))
	return save


## 存檔是玩家硬碟上的檔案，欄位型別可能是任何東西。直接寫 value == true
## 在 GDScript 裡遇到 int 會噴「Invalid operands 'int' and 'bool'」——
## 那正是「不能崩」的這一層最不該發生的事。
static func _as_bool(value: Variant) -> bool:
	return value is bool and value


static func _as_int(value: Variant) -> int:
	if value is int:
		return maxi(0, value)
	if value is float:
		return maxi(0, int(value))
	return 0


static func load_from_disk() -> SaveData:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return SaveData.new()
	var data: Dictionary = {}
	for key in ["best_score", "best_coins", "best_time_left", "cleared",
			"best_collect_pct", "flawless_clear"]:
		if config.has_section_key("record", key):
			data[key] = config.get_value("record", key)
	return SaveData.from_dict(data)


func save_to_disk() -> void:
	var config := ConfigFile.new()
	for key in to_dict():
		config.set_value("record", key, to_dict()[key])
	config.save(PATH)
