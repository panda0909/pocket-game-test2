class_name ShareText
extends RefCounted

## 分享成績用的文字與網址。純字串處理，不碰 JS 也不碰節點，所以可以完整測。
##
## 三個平台的能力差很多，這裡只負責產出「能用」的東西：
##
##   Threads   官方 web intent 支援預填文字，所以文字會完整帶過去。
##   Facebook  sharer.php 只吃網址，**不吃我們給的文字**——它自己去讀那個
##             網址的 Open Graph 標籤。所以 FB 的分享長相取決於 head_include
##             注入的 OG 標籤，不是這裡的字串。
##   Instagram 沒有任何網頁分享網址可以預填貼文。它那顆按鈕做的是把文字
##             複製到剪貼簿，讓玩家自己貼——這是網頁上唯一能替他做完的事。

const PAGE_URL := "https://panda0909.github.io/pocket-game-test2/"
const GAME_NAME := "《口袋牛牛大冒險》"

const FACEBOOK_SHARER := "https://www.facebook.com/sharer/sharer.php?u=%s"
const THREADS_INTENT := "https://www.threads.net/intent/post?text=%s"


## 成績文字，不含網址。
static func compose(stats: RunStats, character_index: int, cleared: bool) -> String:
	var who := Roster.name_of(character_index)
	if cleared:
		return "我用%s通關了%s！分數 %d、金幣 %d 枚" % [
			who, GAME_NAME, stats.score, stats.coins]
	return "我用%s在%s拿到 %d 分，你破得了嗎？" % [who, GAME_NAME, stats.score]


## 成績文字加上遊戲網址。收到的人要點得進來，網址放最後最容易被自動連結。
static func full_message(stats: RunStats, character_index: int,
		cleared: bool) -> String:
	return "%s %s" % [compose(stats, character_index, cleared), PAGE_URL]


## Facebook 分享視窗。只帶網址——文字它不收。
static func facebook_url() -> String:
	return FACEBOOK_SHARER % PAGE_URL.uri_encode()


## Threads 發文意圖，文字會預填。
static func threads_url(message: String) -> String:
	return THREADS_INTENT % message.uri_encode()
