class_name BuildResult
extends RefCounted

## LevelBuilder.build() 的回傳值。
##
## 以前是字串鍵的 Dictionary。三個最熱的跨層介面都這樣寫，代價是型別檢查
## 完全失效：result["spawn_position"] 打錯一個字母要跑到那一幀才炸，而且
## 靜態分析看不到。改成小結構之後，打錯欄位名是編譯期就報。

var spawn_position := Vector2.ZERO
var level_size := Vector2.ZERO
## 實際生成了幾個實體節點。給驗收用。
var entities_built := 0


static func make(spawn: Vector2, size: Vector2, built: int) -> BuildResult:
	var result := BuildResult.new()
	result.spawn_position = spawn
	result.level_size = size
	result.entities_built = built
	return result
