extends GutTest

## 字型子集化的安全網。
##
## assets/fonts/NotoSansTC-Bold.otf 是 5.6 MB 的全字集，但遊戲實際用到的
## 相異漢字只有幾百個——字型佔了 index.pck 的 88%，而且 fontdata 已經壓縮過，
## gzip 幾乎壓不動。子集化之後 5.57 MB → 0.14 MB。
##
## 代價是一個安靜的失敗模式：加一句新的提示文字，那些字如果不在子集裡，
## 線上版會顯示成豆腐方塊，而本機開發時看起來完全正常（因為原始字型還在）。
##
## 這支測試把它變成會失敗的事：掃描程式碼與場景裡所有字串字面值，
## 逐字問字型有沒有這個字形。

const SUBSET := "res://assets/fonts/NotoSansTC-Bold.subset.otf"
const SCAN_DIRS := ["res://scenes", "res://scripts"]

func test_subset_font_exists() -> void:
	assert_true(ResourceLoader.exists(SUBSET),
		"找不到子集字型，請跑 tools/.venv/bin/python tools/prepare_font.py")

func test_every_character_used_in_the_game_has_a_glyph() -> void:
	var font := load(SUBSET) as Font
	assert_not_null(font, "子集字型載不進來")
	if font == null:
		return

	var missing: Dictionary = {}
	for text: String in _all_string_literals():
		for i in text.length():
			var code: int = text.unicode_at(i)
			# 控制字元與跳脫序列殘留不算
			if code < 32:
				continue
			if not font.has_char(code):
				# 連碼位一起記。缺的常常是看不見的字元（全形空白之類），
				# 只印字元本身的話錯誤訊息會是一片空白。
				missing["U+%04X「%s」" % [code, char(code)]] = true

	assert_eq(missing.size(), 0,
		"這些字不在子集字型裡，線上版會變成豆腐方塊：%s\n（跑 tools/prepare_font.py 重新產生）"
			% ", ".join(missing.keys()))

## 掃出所有雙引號字串字面值。和 tools/prepare_font.py 用同一套規則，
## 兩邊看到的字元集才會一致。
func _all_string_literals() -> Array:
	var found: Array = []
	var pattern := RegEx.new()
	pattern.compile('"((?:[^"\\\\]|\\\\.)*)"')
	for dir_path in SCAN_DIRS:
		for path in _files_under(dir_path):
			var text := _without_comments(FileAccess.get_file_as_string(path))
			for m in pattern.search_all(text):
				found.append(m.get_string(1))
	return found

func _files_under(path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			out.append_array(_files_under(full))
		elif name.ends_with(".gd") or name.ends_with(".tscn"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


## 註解不會出現在畫面上，掃描時要略過——否則寫一段解釋用的中文註解
## 就會逼字型子集把那些字也收進去，子集會越滾越大而且沒有理由。
## 也略過 push_error / push_warning / print——那些字進的是主控台，不是畫面。
func _without_comments(text: String) -> String:
	var kept: PackedStringArray = []
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		# 主控台輸出不會出現在畫面上。
		if trimmed.begins_with("push_error(") or trimmed.begins_with("push_warning(") \
				or trimmed.begins_with("print("):
			continue
		kept.append(line)
	return "\n".join(kept)
