class_name ScoreCard
extends RefCounted

## 成績卡的內容。純資料，版面與渲染是 scenes/score_card.gd 的事。
##
## 為什麼需要動態成績卡：以前分享出去的預覽圖是固定的三隻角色合照——
## A 玩家通關拿 12340 分、B 玩家開場就死，兩人貼到 Facebook 的東西一模一樣。
## 動態牆上沒有任何個人化訊號，而那是社群傳播最致命的一種缺陷：分享出去
## 的東西不是「我」的，是「它」的。
##
## 而且結束畫面以前還主動把那張固定圖標成「社群分享預覽」，等於在按下
## 分享之前就告訴玩家：你分享出去的跟你這局無關。
##
## 尺寸用 1200×630（OG 標準比例），Instagram 也吃這個比例。

const WIDTH := 1200
const HEIGHT := 630


## 卡片上要印的每一個欄位。
static func compose(stats: RunStats, character_index: int, cleared: bool,
		time_left: int) -> Dictionary:
	var index := Roster.clamp_index(character_index)
	return {
		"headline": "通關" if cleared else "闖關紀錄",
		"character": "%s・%s" % [Roster.name_of(index),
			"走完盤面大道" if cleared else "倒在盤面大道"],
		"character_index": index,
		"score": stats.score,
		"coins": stats.found["coin"],
		"collect_pct": stats.collect_percent(),
		"time_left": time_left if cleared else 0,
		"show_time": cleared,
		# 無傷只有真的通關才算。半路無傷死掉不是成就。
		"flawless": cleared and stats.flawless,
		"cleared": cleared,
	}


## 存下來的檔名。帶分數，玩家連存三張才不會互相覆蓋。
static func filename(stats: RunStats, cleared: bool) -> String:
	return "口袋牛牛_%s_%d分.png" % ["通關" if cleared else "紀錄", stats.score]
