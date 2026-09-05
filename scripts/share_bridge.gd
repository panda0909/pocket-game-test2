class_name ShareBridge
extends RefCounted

## 把分享動作交給瀏覽器。這是唯一碰平台 API 的地方。
##
## 放在 scripts/ 而不是 scenes/：它整支只用 OS / JavaScriptBridge /
## DisplayServer / JSON，沒有任何節點或場景樹依賴，符合「scripts/ 放不繼承
## Node 的純運算類別」這條分層定義。ShareText 本來就在這裡，兩者成對。
##
## 非網頁環境（編輯器、headless、整合測試）一律回 false 而不是報錯——
## 這樣整合測試能走完整個選單流程，不必為了「這裡沒有瀏覽器」而跳過。
##
## 兩個網頁上的老問題，所以每個動作都有備援並回報成敗：
##   彈出視窗   window.open 只在使用者手勢的呼叫堆疊裡才允許。Godot 在自己
##              的幀迴圈處理輸入，可能已經離開那個手勢，於是被擋掉。
##   剪貼簿     瀏覽器的 clipboard API 需要權限與手勢，可能靜靜失敗。


static func is_available() -> bool:
	return OS.has_feature("web")


## 開分享頁面。先試新分頁，被擋就直接導覽當前分頁。
##
## 為什麼需要備援：Godot 把瀏覽器的輸入事件排進自己的幀迴圈才處理，所以
## window.open 的呼叫已經離開了使用者手勢的堆疊，瀏覽器有理由把它當成
## 未經同意的彈出視窗擋掉。被擋是偵測得到的（window.open 回 null），
## 所以只在真的被擋時才離開遊戲——分數已經定案，玩家按上一頁就回來了。
##
## 回傳是否成功交給瀏覽器處理。
static func open_url(url: String) -> bool:
	if not is_available():
		return false
	var script := """
(function(u){
  var w = null;
  try { w = window.open(u, '_blank', 'noopener'); } catch (e) { w = null; }
  if (w) { return 'popup'; }
  // 彈出視窗被擋：直接帶著整個分頁過去，總比什麼都沒發生好。
  window.location.href = u;
  return 'navigate';
})(%s);
""" % JSON.stringify(url)
	var result: Variant = JavaScriptBridge.eval(script, true)
	# JS 寫了回傳值就要接住。以前直接 return true，於是 eval 拋例外時
	# 也照樣顯示「正在開啟 Facebook 分享」。
	return result == "popup" or result == "navigate"


## 複製到剪貼簿。DisplayServer 的實作在某些瀏覽器上會靜靜失敗，
## 所以再用 navigator.clipboard 補一次。
static func copy_to_clipboard(text: String) -> bool:
	if not is_available():
		# 桌面與編輯器版本 DisplayServer 直接就能複製，成敗問它本人。
		# 以前這裡先複製成功、再因為「不是網頁版」回 false，於是玩家
		# 明明複製好了卻看到「複製失敗，請手動選取」。
		if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			return false
		DisplayServer.clipboard_set(text)
		return DisplayServer.clipboard_get() == text
	DisplayServer.clipboard_set(text)
	var script := """
(function(t){
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(t);
      return true;
    }
  } catch (e) {}
  try {
    var a = document.createElement('textarea');
    a.value = t;
    a.style.position = 'fixed';
    a.style.opacity = '0';
    document.body.appendChild(a);
    a.select();
    document.execCommand('copy');
    document.body.removeChild(a);
    return true;
  } catch (e) { return false; }
})(%s);
""" % JSON.stringify(text)
	return JavaScriptBridge.eval(script, true) == true


## 把一張 PNG 交給瀏覽器：能用原生分享就分享，否則存檔。
##
## 這是 Instagram 唯一可行的路徑——IG 不吃連結、只吃圖，而以前的「複製成績
## 文字」貼到 IG 之後那串網址還不能點，等於白做。
##
## navigator.share 需要使用者手勢，而 Godot 在自己的幀迴圈處理輸入，可能已經
## 離開那個堆疊（和 window.open 同一個老問題）。所以一定要有存檔備援，
## 而且回傳值要說清楚走的是哪一條。
static func share_image(png: PackedByteArray, text: String,
		filename: String) -> String:
	if png.is_empty():
		return "empty"
	if not is_available():
		return "unsupported"
	var script := """
(function(b64, caption, name){
  try {
    var bin = atob(b64);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
    var blob = new Blob([bytes], { type: 'image/png' });
    try {
      var file = new File([blob], name, { type: 'image/png' });
      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        navigator.share({ files: [file], text: caption });
        return 'shared';
      }
    } catch (e) { /* 落到存檔 */ }
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
    return 'saved';
  } catch (e) { return 'failed'; }
})(%s, %s, %s);
""" % [JSON.stringify(Marshalls.raw_to_base64(png)),
	JSON.stringify(text), JSON.stringify(filename)]
	var result: Variant = JavaScriptBridge.eval(script, true)
	return str(result) if result != null else "failed"
