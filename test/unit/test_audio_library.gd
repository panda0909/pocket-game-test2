extends GutTest

## 音效層的純邏輯：哪個事件配哪個聲音、音量怎麼換算。
## 播放本身要場景樹，但「該放什麼」不必——那部分留在這裡測。

func test_every_declared_sound_has_a_file_on_disk() -> void:
	var names := AudioLibrary.sound_names()
	assert_gt(names.size(), 10, "音效不該只有零星幾個")
	for name in names:
		var path := AudioLibrary.sound_path(name)
		assert_true(ResourceLoader.exists(path),
			"音效 %s 對應的檔案不存在：%s" % [name, path])

func test_music_file_exists() -> void:
	assert_true(ResourceLoader.exists(AudioLibrary.MUSIC_PATH))

func test_unknown_sound_returns_empty_path() -> void:
	assert_eq(AudioLibrary.sound_path("根本沒有這個音效"), "")

func test_linear_volume_maps_to_decibels() -> void:
	assert_almost_eq(AudioLibrary.linear_to_db(1.0), 0.0, 0.01)
	assert_lt(AudioLibrary.linear_to_db(0.5), 0.0)

## 靜音必須是真的聽不到，不是「很小聲」。
## linear2db(0) 是負無限大，直接丟給 AudioServer 會變成 NaN。
func test_zero_volume_is_silent_not_infinite() -> void:
	var db := AudioLibrary.linear_to_db(0.0)
	assert_lte(db, AudioLibrary.SILENT_DB)
	assert_true(is_finite(db), "靜音的分貝值必須是有限數")

func test_volume_is_clamped_to_valid_range() -> void:
	assert_eq(AudioLibrary.clamp_volume(-1.0), 0.0)
	assert_eq(AudioLibrary.clamp_volume(3.0), 1.0)
	assert_almost_eq(AudioLibrary.clamp_volume(0.4), 0.4, 0.001)
