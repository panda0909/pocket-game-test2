class_name ScoreCardView
extends SubViewport

## 把一局的成績畫成一張 1200×630 的圖。
##
## 版面與渲染在這裡；「卡片上該寫什麼」是 scripts/score_card.gd 的事。
##
## 為什麼要 SubViewport 而不是截遊戲畫面：遊戲是 1280×720、上面還有結束選單，
## 而社群卡片要 1200×630（OG 標準比例，IG 也吃）。專門畫一張才控制得了版面。

const CANDLE_TINT := Color(1, 1, 1, 0.10)

@onready var _headline: Label = $Root/Headline
@onready var _subline: Label = $Root/Subline
@onready var _score: Label = $Root/Score
@onready var _stats: Label = $Root/Stats
@onready var _flawless: Label = $Root/Flawless
@onready var _character: TextureRect = $Root/Character
@onready var _candles: TextureRect = $Root/Candles
@onready var _brand: Label = $Root/Brand


func _ready() -> void:
	size = Vector2i(ScoreCard.WIDTH, ScoreCard.HEIGHT)
	# 只在被要求時畫一次。這張圖一局只產生一次，沒有理由每幀重繪。
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_candles.modulate = CANDLE_TINT
	# 圖上一定要有網址。IG 不吃連結、只吃圖——看到這張卡片的人如果找不到
	# 遊戲在哪，這條分享路徑就等於沒有出口。網址跟著 ShareText 走，
	# 換網域時卡片會自動跟上。
	_brand.text = "口袋牛牛大冒險　%s" % ShareText.PAGE_URL


## 填好內容並畫一張，回傳 PNG 位元組。
##
## headless 下渲染器是 dummy，get_image() 可能拿不到東西——那不是錯誤，
## 是那個環境本來就沒有畫面。回空陣列讓呼叫端自己決定怎麼降級。
func render_png(stats: RunStats, character_index: int, cleared: bool,
		time_left: int) -> PackedByteArray:
	_apply(ScoreCard.compose(stats, character_index, cleared, time_left))
	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var texture := get_texture()
	if texture == null:
		return PackedByteArray()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return PackedByteArray()
	return image.save_png_to_buffer()


func _apply(fields: Dictionary) -> void:
	_headline.text = fields["headline"]
	_subline.text = fields["character"]
	_score.text = "%d" % fields["score"]
	_character.texture = Roster.big_texture(fields["character_index"]) \
		if fields["cleared"] else Roster.texture(fields["character_index"])

	var parts: Array[String] = [
		"金幣 %d 枚" % fields["coins"],
		"收集率 %d%%" % fields["collect_pct"],
	]
	if fields["show_time"]:
		parts.append("剩餘 %d 秒" % fields["time_left"])
	_stats.text = "　　".join(parts)

	_flawless.visible = fields["flawless"]
