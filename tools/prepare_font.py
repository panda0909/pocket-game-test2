"""把全字集的 Noto Sans TC 子集化成專案實際用得到的字元。

執行方式：
    tools/.venv/bin/python tools/prepare_font.py

為什麼需要：assets/fonts/NotoSansTC-Bold.otf 是 5.8 MB，匯入後的 fontdata
5.3 MB，而 index.pck 總共才 6.0 MB——字型佔了 88%。更糟的是 fontdata 本身
已經壓縮過，gzip 幾乎壓不動（5.96 MB），所以那 5.3 MB 是實打實的傳輸量。

而遊戲實際用到的相異漢字只有一百多個。玩家為了那一百多個字，下載了收錄
約兩萬字的整套字型。

wasm 的 39.5 MB 是 Godot 官方匯出範本的固有大小，動不了；index.pck 這 6 MB
是全站唯一能靠專案自己的決策砍掉的部分。

字元集怎麼決定：掃描 scenes/、scripts/、levels/ 裡所有雙引號字串字面值，
外加標點、數字、英文字母與一組保險用的常見字。掃描而不是手工維護清單，
是因為手工清單一定會漏——加一句新的提示文字卻忘了更新清單，那個字在
線上版就變成豆腐方塊，而本機因為用的是全字集版本完全看不出來。
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "fonts", "NotoSansTC-Bold.otf")
OUTPUT = os.path.join(ROOT, "assets", "fonts", "NotoSansTC-Bold.subset.otf")

SCAN_DIRS = ["scenes", "scripts", "levels", "tools"]
SCAN_SUFFIXES = (".gd", ".tscn", ".txt")

# 一定要留的字元：ASCII 可見字元、全形標點、常見符號。
ALWAYS = set(
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "　、。，！？：；「」『』（）《》〈〉—…‧·"
    + "◀▶▼▲◆■□●○★☆←→↑↓"
)

# 掃不到但可能動態組出來的字。寧可多留幾個字，也不要線上版出現豆腐塊。
SAFETY = set("零一二三四五六七八九十百千萬億分數金幣生命時間關卡秒新紀錄"
             "音效音樂繼續暫停放棄回標題最高通關剩餘條再玩一次")

STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def scan_characters() -> set:
    found = set()
    for folder in SCAN_DIRS:
        base = os.path.join(ROOT, folder)
        for dirpath, _dirnames, filenames in os.walk(base):
            for name in filenames:
                if not name.endswith(SCAN_SUFFIXES):
                    continue
                path = os.path.join(dirpath, name)
                try:
                    text = open(path, encoding="utf-8").read()
                except (UnicodeDecodeError, OSError):
                    continue
                if name.endswith(".txt") and folder == "levels":
                    # 關卡檔的地圖區是字元表，不是給人看的文字
                    text = text.split("---")[0]
                # 註解不會出現在畫面上。寫一段解釋用的中文註解不該逼子集
                # 把那些字也收進去——子集會越滾越大而且沒有理由。
                skip = ("#", "push_error(", "push_warning(", "print(")
                text = "\n".join(
                    line for line in text.split("\n")
                    if not line.lstrip().startswith(skip))
                for literal in STRING_LITERAL.findall(text):
                    found.update(literal)
    return found


def main() -> int:
    if not os.path.exists(SOURCE):
        print("找不到來源字型：%s" % SOURCE)
        return 1

    wanted = scan_characters() | ALWAYS | SAFETY
    # 過濾掉控制字元。注意不能只用 isprintable()：Python 認為全形空白
    # U+3000 是不可列印的（分類 Zs），而遊戲的介面文字大量用它排版——
    # 濾掉的話子集裡就沒有它，線上版每個全形空白都變成豆腐方塊。
    wanted = {c for c in wanted
              if ord(c) >= 0x20 and (c.isprintable() or c.isspace())}
    cjk = sum(1 for c in wanted if ord(c) > 0x2E80)
    print("掃到 %d 個字元（其中中日韓字 %d 個）" % (len(wanted), cjk))

    unicodes = ",".join("U+%04X" % ord(c) for c in sorted(wanted))
    before = os.path.getsize(SOURCE)

    result = subprocess.run(
        [sys.executable, "-m", "fontTools.subset", SOURCE,
         "--unicodes=" + unicodes,
         "--output-file=" + OUTPUT,
         "--layout-features=*",
         "--no-hinting",
         "--desubroutinize"],
        capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        return result.returncode

    after = os.path.getsize(OUTPUT)
    print("%s  %.2f MB → %.2f MB（%.0f%%）" % (
        os.path.relpath(OUTPUT, ROOT),
        before / 1048576.0, after / 1048576.0,
        100.0 * after / before))
    print()
    print("接下來：把 scenes/*.tscn 與程式碼裡引用的字型路徑換成子集版本，")
    print("並確認 export_presets.cfg 的 include_filter 有涵蓋它。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
