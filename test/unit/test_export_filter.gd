extends GutTest

## 網頁匯出的白名單驗收。
##
## export_presets.cfg 的 export_filter 是 "resources"，只匯出 main.tscn 的
## 相依樹；其餘靠 include_filter 手動列白名單。這個設計有個安靜的失敗模式：
## 新增一個資料夾卻忘了改白名單，本機一切正常，線上版缺圖或沒聲音，
## 而且不會有任何錯誤訊息——玩家只會覺得遊戲壞了。
##
## 這支測試把「白名單有沒有跟上」變成會失敗的事。

const PRESETS := "res://export_presets.cfg"

func _include_filter() -> String:
	var text := FileAccess.get_file_as_string(PRESETS)
	for line in text.split("\n"):
		if line.begins_with("include_filter="):
			return line.split("=", true, 1)[1].strip_edges().trim_prefix("\"") \
				.trim_suffix("\"")
	return ""

func test_export_presets_exists() -> void:
	assert_true(FileAccess.file_exists(PRESETS), "找不到 export_presets.cfg")

## assets/ 底下每個放了檔案的資料夾，都要有對應的白名單樣式。
func test_every_asset_folder_is_whitelisted() -> void:
	var filter := _include_filter()
	assert_false(filter.is_empty(), "讀不到 include_filter")
	for folder in _asset_folders():
		var covered := false
		for pattern in filter.split(","):
			if pattern.strip_edges().begins_with(folder):
				covered = true
				break
		assert_true(covered,
			"%s 底下有檔案，但 include_filter 沒有涵蓋它——線上版會缺這批素材"
				% folder)

## 蒐集 assets/ 下所有真的放了非 .import 檔案的資料夾。
func _asset_folders() -> Array:
	var folders: Array = []
	_walk("res://assets", folders)
	return folders

func _walk(path: String, folders: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var has_file := false
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			_walk(path + "/" + name, folders)
		elif not name.ends_with(".import"):
			has_file = true
		name = dir.get_next()
	dir.list_dir_end()
	if has_file:
		folders.append(path.trim_prefix("res://") + "/")

## 音效與音樂都要真的載得到。宣告了卻沒有檔案的話，遊戲會安靜地沒聲音。
func test_audio_resources_are_reachable() -> void:
	for name in AudioLibrary.sound_names():
		assert_not_null(AudioLibrary.sound(name), "音效 %s 載不到" % name)
	assert_not_null(AudioLibrary.MUSIC, "背景音樂載不到")
