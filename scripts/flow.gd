class_name Flow
extends RefCounted

## 遊戲流程的狀態轉移。抽出來是因為「死了還有命就回到遊玩、沒命才是結束」
## 這種分支寫在節點裡沒辦法測，而它一旦寫錯，玩家會遇到「明明還有命卻結束了」
## 這種最惱人的 bug。

const TITLE := 0
const PLAYING := 1
const GAME_OVER := 2
const CLEARED := 3
const SELECT := 4


static func next(state: int, event: String, lives_left: int) -> int:
	match state:
		TITLE:
			if event == "start":
				return SELECT
		SELECT:
			match event:
				"confirm":
					return PLAYING
				"back":
					return TITLE
		PLAYING:
			match event:
				"died":
					return PLAYING if lives_left > 0 else GAME_OVER
				"goal":
					return CLEARED
		GAME_OVER, CLEARED:
			if event == "restart":
				return TITLE
	return state


## 只有遊玩中才讀玩家的移動輸入。選角畫面要吃走左右鍵，
## 不然主角會在背景裡跟著跑。
static func accepts_input(state: int) -> bool:
	return state == PLAYING


static func counts_down(state: int) -> bool:
	return state == PLAYING
