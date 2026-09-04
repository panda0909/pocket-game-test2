extends Node

## 音效與音樂的播放。註冊成自動載入單例 Audio，所以任何節點都能
## Audio.play("jump")，不必自己持有 AudioStreamPlayer。
##
## 用一個小小的播放器池而不是每次 new 一個：同一幀可能同時撿到金幣、
## 踩到敵人、頂到磚，每次都建節點會在 Web 版造成明顯的抖動。
##
## process_mode 是 ALWAYS，因為暫停選單的音效要在 get_tree().paused
## 為真時照樣聽得到。

const VOICES := 8
const SETTINGS_PATH := "user://settings.cfg"

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer

var sfx_volume := 0.8
var music_volume := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.finished.connect(_loop_music)
	add_child(_music)

	load_settings()


func play(name: String) -> void:
	var stream := AudioLibrary.sound(name)
	if stream == null:
		return
	# 輪流用下一個播放器。滿了就從頭覆蓋——蓋掉最舊的那個聲音，
	# 比讓新的事件完全沒聲音好。
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.play()


func play_music() -> void:
	if _music.playing:
		return
	_music.stream = AudioLibrary.MUSIC
	_music.play()


func stop_music() -> void:
	_music.stop()


## WAV 匯入時沒開循環旗標，所以自己接 finished 重播。
## 這樣循環點由檔案長度決定，改音樂不必連匯入設定一起改。
func _loop_music() -> void:
	if _music.stream != null:
		_music.play()


func set_sfx_volume(linear: float) -> void:
	sfx_volume = AudioLibrary.clamp_volume(linear)
	_apply_bus("SFX", sfx_volume)


func set_music_volume(linear: float) -> void:
	music_volume = AudioLibrary.clamp_volume(linear)
	_apply_bus("Music", music_volume)


func _apply_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, AudioLibrary.linear_to_db(linear))
	AudioServer.set_bus_mute(index, linear <= 0.0001)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sfx_volume = AudioLibrary.clamp_volume(
			float(config.get_value("audio", "sfx", sfx_volume)))
		music_volume = AudioLibrary.clamp_volume(
			float(config.get_value("audio", "music", music_volume)))
	_apply_bus("SFX", sfx_volume)
	_apply_bus("Music", music_volume)
