extends Node

## 把遊戲事件交給網頁。註冊成自動載入單例 Telemetry。
##
## 這一層刻意什麼都不知道：它不認識任何分析服務、不帶任何端點、不存任何
## 識別碼。它只呼叫瀏覽器裡的 window.pocketGameEvent(name, props)，而那個
## 函式在 HTML 殼裡預設是空的——要不要接分析、接哪一家，由專案擁有者
## 在殼裡決定。
##
## 這樣做的理由很簡單：埋點會把資料送出使用者的瀏覽器，而那是一個
## 需要專案擁有者明確同意的決定，不是一個可以預設開啟的功能。
##
## 事件名稱與可送出的欄位在 scripts/telemetry_events.gd，那裡有測試守著
## 「只送得出白名單裡的欄位」。

const HOOK := "pocketGameEvent"


## 送一個事件。回傳有沒有真的送出去（非網頁環境一律沒有）。
func send(event_name: String, props: Dictionary = {}) -> bool:
	var name := TelemetryEvents.sanitize_name(event_name)
	if name.is_empty():
		# 打錯字的事件如果照送，報表上那個事件永遠是 0 而且沒人會發現。
		push_error("未知的埋點事件：%s" % event_name)
		return false
	if not OS.has_feature("web"):
		return false
	var payload := JSON.stringify(TelemetryEvents.sanitize(props))
	var script := """
(function (name, payload) {
  try {
    if (typeof window.%s === 'function') {
      window.%s(name, JSON.parse(payload));
    }
  } catch (e) { /* telemetry must never break the game */ }
})(%s, %s);
""" % [HOOK, HOOK, JSON.stringify(name), JSON.stringify(payload)]
	JavaScriptBridge.eval(script, true)
	return true
