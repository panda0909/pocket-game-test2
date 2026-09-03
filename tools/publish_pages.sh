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
# 為什麼不用 GitHub Actions 自動建置：那需要在 CI 裡裝 Godot 與匯出範本，
# 為了一個單人專案不值得。這支腳本在本機跑，效果一樣。
#
# 前置條件：
#   - 已安裝 Godot 4.7.2 的網頁匯出範本
#   - gh 已登入，或 git 能推到 origin
#
# 注意：匯出設定的 variant/thread_support 必須維持 false。GitHub Pages
# 沒辦法設定 COOP/COEP 標頭，開了執行緒支援的版本在上面會載不起來。

set -euo pipefail

GODOT="${GODOT:-/Users/hongming/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."

REMOTE=$(git remote get-url origin)
WEB_DIR="build/web"
PAGES_DIR="build/pages-repo"

echo "== 匯出網頁版 =="
mkdir -p "$WEB_DIR"
"$GODOT" --headless --path . --export-release "Web" "$WEB_DIR/index.html"

if [ ! -f "$WEB_DIR/index.wasm" ]; then
	echo "匯出失敗：找不到 $WEB_DIR/index.wasm"
	exit 1
fi

echo
echo "== 準備 gh-pages 內容 =="
rm -rf "$PAGES_DIR"
mkdir -p "$PAGES_DIR"
cp -R "$WEB_DIR"/. "$PAGES_DIR"/
# 讓 GitHub Pages 直接送檔案，不要跑 Jekyll
touch "$PAGES_DIR/.nojekyll"

cd "$PAGES_DIR"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C ../.. config user.name)" \
	-c user.email="$(git -C ../.. config user.email)" \
	commit -q -m "發佈網頁版 $(date '+%Y-%m-%d %H:%M')"
git remote add origin "$REMOTE"

echo
echo "== 推送 =="
# 每次都重建單一 commit，所以要 force。gh-pages 上沒有需要保留的歷史。
git push -q --force origin gh-pages

cd ../..
echo
echo "已發佈。網址："
echo "  https://$(echo "$REMOTE" | sed -E 's#.*github.com[:/]([^/]+)/([^/.]+)(\.git)?#\1.github.io/\2#')/"
