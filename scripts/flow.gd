class_name Flow
extends RefCounted

## 遊戲流程的狀態轉移。抽出來是因為「死了還有命就回到遊玩、沒命才是結束」
## 這種分支寫在節點裡沒辦法測，而它一旦寫錯，玩家會遇到「明明還有命卻結束了」
## 這種最惱人的 bug。

const TITLE := 0
const PLAYING := 1
const GAME_OVER := 2
const CLEARED := 3


static func next(state: int, event: String, lives_left: int) -> int:
	match state:
		TITLE:
			if event == "start":
				return PLAYING
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


static func accepts_input(state: int) -> bool:
	return state == PLAYING


static func counts_down(state: int) -> bool:
	return state == PLAYING
