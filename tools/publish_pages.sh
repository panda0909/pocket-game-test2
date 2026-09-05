#!/usr/bin/env bash
# 匯出網頁版並發佈到 GitHub Pages 的 gh-pages 分支。
#
# 用法：
#     tools/publish_pages.sh
#
# 為什麼用獨立的 gh-pages 分支而不是 main 的 docs/：main 只放原始碼，
# 匯出產物（index.wasm 將近 40 MB）不該混進原始碼的歷史裡。gh-pages 的
# 歷史也刻意每次重建成單一 commit，避免每發佈一次就多存一份 40 MB。
#
# 為什麼不用 GitHub Actions 自動建置：那需要在 CI 裡裝 Godot 與匯出範本。
# 測試本身已經接上 CI（.github/workflows/verify.yml），匯出留在本機。
#
# 前置條件：
#   - 已安裝 Godot 4.7.2 的網頁匯出範本
#   - gh 已登入，或 git 能推到 origin
#
# 注意：匯出設定的 variant/thread_support 必須維持 false。GitHub Pages
# 沒辦法設定 COOP/COEP 標頭，開了執行緒支援的版本在上面會載不起來。

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)
# shellcheck source=tools/godot_env.sh
. tools/godot_env.sh

REMOTE=$(git remote get-url origin)
SITE=$(echo "$REMOTE" | sed -E 's#.*github.com[:/]([^/]+)/([^/.]+)(\.git)?#https://\1.github.io/\2#')
SOURCE_SHA=$(git rev-parse --short HEAD)
WEB_DIR="build/web"
PAGES_DIR="build/pages-repo"

# 發佈前一定要跑測試。以前這支腳本從頭到尾沒有呼叫過 run_tests.sh 或
# verify_game.sh——15 支單元測試與整合測試在發佈路徑上一次都沒被觸發，
# 唯一的品質門檻是「index.wasm 這個檔案存在」。
if [ "${SKIP_VERIFY:-0}" != "1" ]; then
	echo "== 發佈前驗證 =="
	tools/verify_game.sh
	echo
fi

# 工作區有未提交的變更就拒絕發佈：線上跑的東西必須對得回一個 commit。
if ! git diff --quiet || ! git diff --cached --quiet; then
	echo "工作區還有未提交的變更，先提交再發佈"
	echo "（真的要發佈目前狀態的話，設 ALLOW_DIRTY=1）"
	[ "${ALLOW_DIRTY:-0}" = "1" ] || exit 1
fi

echo "== 匯出網頁版 =="
# 一定要先清空。Godot 匯出遇到資源錯誤時常常仍回傳 0，set -e 擋不住；
# 目錄不清空的話，殘留的舊 pck 或舊 wasm 會被當成新產物推上線，
# 而腳本完全不會察覺。
rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR"
# 全新 clone 沒有 build/，補一個 .gdignore 免得 Godot 把匯出產物
# 當成專案資源掃進來。
touch build/.gdignore
"$GODOT" --headless --path . --export-release "Web" "$WEB_DIR/index.html"

# index.wasm 是匯出範本的複製品，幾乎一定會產生；真正裝著遊戲內容的是
# index.pck。以前只檢查 wasm，pck 沒產生或殘缺一樣會被推上線。
for required in index.html index.js index.wasm index.pck; do
	if [ ! -s "$WEB_DIR/$required" ]; then
		echo "匯出失敗：$WEB_DIR/$required 不存在或是空的"
		exit 1
	fi
done
# 載入進度文字與直向轉橫提示。找不到標記會 exit 1，發佈流程跟著停——
# 靜靜地沒套用比壞掉還糟，那會變成「線上版少了一半改善而沒人知道」。
echo
echo "== 加上載入文字與直向提示 =="
python3 tools/patch_web_shell.py "$WEB_DIR/index.html"

echo
echo "產物大小："
du -h "$WEB_DIR"/index.{wasm,pck,js} | sed 's/^/  /'

echo
echo "== 準備 gh-pages 內容 =="
rm -rf "$PAGES_DIR"
mkdir -p "$PAGES_DIR"
cp -R "$WEB_DIR"/. "$PAGES_DIR"/
# 讓 GitHub Pages 直接送檔案，不要跑 Jekyll
touch "$PAGES_DIR/.nojekyll"

# OG 預覽圖要放在網站根目錄。index.html 裡的 og:image 是絕對網址，
# 指向 <站台>/share_cover.png——Facebook 的爬蟲抓不到就沒有預覽圖。
cp assets/share_cover.png "$PAGES_DIR/share_cover.png"

# .import 是 Godot 的內部匯入中繼資料，對網站毫無用處，還會洩漏
# .godot/imported/ 的路徑結構。
find "$PAGES_DIR" -name '*.import' -delete

# OG 標籤在 export_presets.cfg 裡是寫死的絕對網址。任何人 fork 之後發佈，
# 社群分享卡片仍會指向原作者的站台——圖抓不到、連結導錯人。
# 這裡依實際的 remote 改寫。
if [ -f "$PAGES_DIR/index.html" ]; then
	sed -i '' -E "s#https://[a-zA-Z0-9_-]+\.github\.io/[a-zA-Z0-9_.-]+#$SITE#g" \
		"$PAGES_DIR/index.html" 2>/dev/null || \
	sed -i -E "s#https://[a-zA-Z0-9_-]+\.github\.io/[a-zA-Z0-9_.-]+#$SITE#g" \
		"$PAGES_DIR/index.html"
fi

# 線上版要對得回一個 commit，出 bug 時才重現得了。
printf '%s\n' "$SOURCE_SHA" > "$PAGES_DIR/version.txt"

cd "$PAGES_DIR"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C ../.. config user.name)" \
	-c user.email="$(git -C ../.. config user.email)" \
	commit -q -m "發佈網頁版 ${SOURCE_SHA} $(date '+%Y-%m-%d %H:%M')"
git remote add origin "$REMOTE"

echo
echo "== 推送 =="
# 每次都重建單一 commit，所以要 force。gh-pages 上沒有需要保留的歷史。
# 不加 -q：推送是這支腳本唯一不可逆的動作，輸出要看得到。
git push --force origin gh-pages

cd "$ROOT"
echo
echo "已發佈 ${SOURCE_SHA}。網址："
echo "  ${SITE}/"
