class_name Flow
extends RefCounted

## 遊戲流程的狀態轉移。抽出來是因為「死了還有命就回到遊玩、沒命才是結束」
## 這種分支寫在節點裡沒辦法測，而它一旦寫錯，玩家會遇到「明明還有命卻結束了」
## 這種最惱人的 bug。

## 事件名稱。以前是散在各處的字串字面值，Flow.next 對認不得的事件一律
## 回傳原狀態——拼錯一個字的表現是「按了沒反應」，沒有任何錯誤訊息。
const START := "start"
const CONFIRM := "confirm"
const BACK := "back"
const DIED := "died"
const GOAL := "goal"
const RESTART := "restart"

const TITLE := 0
const PLAYING := 1
const GAME_OVER := 2
const CLEARED := 3
const SELECT := 4


static func next(state: int, event: String, lives_left: int) -> int:
	match state:
		TITLE:
			if event == START:
				return SELECT
		SELECT:
			match event:
				CONFIRM:
					return PLAYING
				BACK:
					return TITLE
		PLAYING:
			match event:
				DIED:
					return PLAYING if lives_left > 0 else GAME_OVER
				GOAL:
					return CLEARED
		GAME_OVER, CLEARED:
			if event == RESTART:
				return TITLE
	return state


## 只有遊玩中才讀玩家的移動輸入。選角畫面要吃走左右鍵，
## 不然主角會在背景裡跟著跑。
static func accepts_input(state: int) -> bool:
	return state == PLAYING


static func counts_down(state: int) -> bool:
	return state == PLAYING
