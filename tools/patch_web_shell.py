"""替匯出的 index.html 加上載入進度文字與直向提示。

執行方式：
    python3 tools/patch_web_shell.py build/web/index.html

為什麼是後處理而不是自訂 HTML 殼：Godot 的 `html/custom_html_shell` 需要一份
帶 `$GODOT_*` 佔位符的完整殼，而那份殼含有功能偵測、錯誤處理與 service worker
的邏輯。自己維護一份分支的話，每次升級引擎都要手動比對差異，而漏掉的部分
不會有任何錯誤——只會在某個瀏覽器上安靜地壞掉。

後處理的風險是「標記變了就沒套用」，所以每一處都硬失敗：找不到就 exit 1，
發佈流程會停下來。

補的兩件事：

  載入文字  玩家在 4G 上要等 10–40 秒，而那段時間畫面上是 Godot 官方的
            機器人 logo、一條沒有數字的進度條、一個字都沒有。這是整個漏斗裡
            時間最長的單一畫面，而它在幫別人的引擎打廣告。

  直向提示  遊戲是 16:9 橫向，而從社群 App 開連結預設就是直向。直向時遊戲被
            壓成螢幕中間的一條細長條（上下黑邊佔 71%），所有虛擬按鍵縮到
            23–42 pt，全部低於最小觸控目標。而全專案沒有任何轉向提示。
"""

import os
import sys

STYLE_MARKER = "</style>"
BODY_MARKER = '<div id="status">'
PROGRESS_MARKER = """				if (current > 0 && total > 0) {
					statusProgress.value = current;
					statusProgress.max = total;"""

EXTRA_STYLE = """
/* --- 以下由 tools/patch_web_shell.py 加入 --- */
#loading-title {
	position: absolute; top: 62%; left: 0; right: 0;
	text-align: center; color: #eef4fa; z-index: 2;
	font-family: system-ui, -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
	font-size: 22px; font-weight: 700; letter-spacing: .02em;
	text-shadow: 0 2px 8px rgba(0,0,0,.6);
	pointer-events: none;
}
#loading-title small {
	display: block; margin-top: 8px;
	font-size: 14px; font-weight: 400; color: #a9bccc; letter-spacing: .04em;
}
#status.hidden-status #loading-title { display: none; }

/* 直向遮罩。純 CSS media query，不必碰 Godot。 */
#rotate-hint {
	display: none;
	position: fixed; inset: 0; z-index: 100;
	background: #0d1117; color: #eef4fa;
	flex-direction: column; align-items: center; justify-content: center;
	gap: 22px; text-align: center; padding: 24px;
	font-family: system-ui, -apple-system, "PingFang TC", "Microsoft JhengHei", sans-serif;
}
#rotate-hint .glyph {
	font-size: 68px; line-height: 1;
	animation: rotate-nudge 2.2s ease-in-out infinite;
}
#rotate-hint .line { font-size: 20px; font-weight: 700; }
#rotate-hint .sub { font-size: 14px; color: #a9bccc; max-width: 22em; line-height: 1.7; }
@keyframes rotate-nudge {
	0%, 45%, 100% { transform: rotate(0deg); }
	60%, 85%      { transform: rotate(90deg); }
}
@media (prefers-reduced-motion: reduce) {
	#rotate-hint .glyph { animation: none; }
}
/* 只在「直向」且「螢幕不夠寬」時擋。桌面把視窗拉窄不該被擋住。 */
@media (orientation: portrait) and (max-width: 900px) {
	#rotate-hint { display: flex; }
}
"""

EXTRA_BODY = """<div id="rotate-hint">
			<div class="glyph">\U0001F4F1</div>
			<div class="line">請把手機轉成橫向</div>
			<div class="sub">這是一款橫向捲軸遊戲，直向時畫面會被壓成一條細長條，
			虛擬按鍵也會小到按不準。</div>
		</div>
"""

EXTRA_TITLE = """			<div id="loading-title">口袋牛牛大冒險<small id="loading-pct">載入中…</small></div>
"""

PROGRESS_PATCH = """				if (current > 0 && total > 0) {
					statusProgress.value = current;
					statusProgress.max = total;
					const pct = Math.round((current / total) * 100);
					const label = document.getElementById('loading-pct');
					if (label) {
						label.textContent = '載入中 ' + pct + '%　約 '
							+ (total / 1048576).toFixed(0) + ' MB';
					}"""


def patch(path: str) -> int:
    with open(path, encoding="utf-8") as handle:
        html = handle.read()

    steps = [
        (STYLE_MARKER, EXTRA_STYLE + STYLE_MARKER, "載入文字與直向提示的樣式"),
        (BODY_MARKER, EXTRA_BODY + BODY_MARKER, "直向遮罩"),
        (PROGRESS_MARKER, PROGRESS_PATCH, "載入百分比"),
    ]
    for marker, replacement, label in steps:
        if marker not in html:
            print("找不到標記，無法套用「%s」——Godot 的 HTML 殼可能改版了。" % label)
            print("標記：%r" % marker[:60])
            return 1
        html = html.replace(marker, replacement, 1)
        print("已套用：%s" % label)

    # 載入標題要放在 #status 裡面，才會跟著一起隱藏
    anchor = '<div id="status-notice"></div>'
    if anchor not in html:
        print("找不到 status-notice，無法插入載入標題")
        return 1
    html = html.replace(anchor, anchor + "\n" + EXTRA_TITLE, 1)
    print("已套用：載入標題")

    with open(path, "w", encoding="utf-8") as handle:
        handle.write(html)
    print("已寫入 %s" % path)
    return 0


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    if not os.path.exists(path):
        print("找不到檔案：%s" % path)
        return 1
    return patch(path)


if __name__ == "__main__":
    raise SystemExit(main())
