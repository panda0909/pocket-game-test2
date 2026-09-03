extends Node

## 開發用擷圖工具：載入主場景、等指定幀數、把畫面存成 PNG 後結束。
## 有了它就能在沒有人盯著螢幕的情況下確認畫面真的畫出東西。
##
## 用法：
##     Godot --path . tools/capture.tscn -- <輸出路徑> <等待幀數> [模式] [X 位移格數]
##
## 模式：
##     title   只看標題畫面（預設）
##     select  停在選角畫面
##     game    直接開始遊戲
##     big     開始遊戲並讓玩家先變大、帶滿彈藥，用來確認 BIG 外觀
##     bull / dino / gecko  指定主角後直接開始
##
## 第四個參數把玩家往右移動指定格數，用來逐段檢查長關卡的排版。
##
## 這個場景不會被匯出（export_presets.cfg 已排除 tools/）。

const DEFAULT_FRAMES := 90
const DEFAULT_OUTPUT := "/tmp/godot_capture.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else DEFAULT_OUTPUT
	var frames: int = int(args[1]) if args.size() > 1 else DEFAULT_FRAMES
	var mode: String = args[2] if args.size() > 2 else "title"
	var shift_cells: int = int(args[3]) if args.size() > 3 else 0

	add_child(load("res://scenes/main.tscn").instantiate())
	var main: Node = get_child(0)
	await get_tree().process_frame

	const CHARACTERS := {"bull": 0, "dino": 1, "gecko": 2}

	if mode == "select":
		main.begin_game_to_select()
	elif mode != "title":
		main.begin_game(CHARACTERS.get(mode, -1))
		await get_tree().process_frame
		if shift_cells != 0:
			main.teleport_player(shift_cells)
		if mode == "big":
			main.debug_grant_powerup(20)

	# 等畫面真的畫過幾幀，否則擷到的會是還沒繪製的空白緩衝區
	for i in frames:
		await get_tree().process_frame

	if mode != "title" and mode != "select":
		print("擷圖狀態 %s" % main.debug_summary())

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("擷圖失敗：%s" % error_string(error))
		get_tree().quit(1)
		return
	print("已擷圖 %s %s" % [out_path, image.get_size()])
	get_tree().quit()
