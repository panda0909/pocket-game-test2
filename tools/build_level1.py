"""組裝主關卡 levels/level1.txt。

執行方式：
    tools/.venv/bin/python tools/build_level1.py
    （不需要 Pillow，系統 python3 也可以跑）

為什麼用腳本組裝而不是直接手寫那張文字檔：關卡有 300 欄，手寫時每一行的
欄位都得自己數對齊，改一個坑的寬度要同時改好幾行。用座標函式描述「這一段
從第 28 格到第 44 格是地面、第 32 格站一隻熊」，段落之間就能安全地插入與
移動，而且讀起來就是關卡設計的意圖。

產出的 level1.txt 仍然是純文字、可 diff、可手改——腳本只是排版工具，
不是唯一的編輯途徑。改完手改的版本如果要重跑腳本，記得腳本會蓋掉它。

四段節奏：
    教學段  0–64    只有平地、單格落差、小熊。學會跑、跳、踩。
    道具段  65–145  問號磚、可破磚、牛奶、尖刺、刺球。學會頂磚、變大、丟金幣。
    立體段  146–252 移動平台、深坑、水管暗房、跌停箭頭。垂直操作與冒險取捨。
    關底段  253–299 Boss熊與旗竿。

兩條幾何約束，都由 test/unit/ 下的測試守著：

  所有坑不超過 4 格寬。跳躍高度 236 px（3.7 格）、跑速 280 px/s，滿跳水平
  最遠約 5.1 格，留一格安全邊際。垂直落差改用移動平台解決，不用寬坑。

  可頂的磚塊底下要留 3 格淨空。大牛碰撞箱高 168 px，放在第 9 列的磚塊底下
  只有 128 px，小牛過得去但變大後會嵌在磚裡。同理，站得上去的磚台不能高過
  跳躍上限——第 9 列（192 px）可以，第 8 列（256 px）就得靠移動平台當中繼。
"""

import os

WIDTH = 300
HEIGHT = 14
FLOOR = HEIGHT - 1          # 第 13 列是關卡底部
GROUND_TOP = HEIGHT - 2     # 常規地面表面在第 12 列
STAND = GROUND_TOP - 1      # 站在常規地面上的東西放第 11 列

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "levels", "level1.txt")

grid = [[" "] * WIDTH for _ in range(HEIGHT)]


def ground(x0, x1, top=GROUND_TOP):
    """從 top 列一路填到關卡底部。含頭含尾。"""
    for x in range(x0, x1 + 1):
        for y in range(top, HEIGHT):
            grid[y][x] = "#"


def bricks(x0, x1, row, char="="):
    for x in range(x0, x1 + 1):
        grid[row][x] = char


def put(x, y, char):
    grid[y][x] = char


def coins(xs, row):
    for x in xs:
        put(x, row, "o")


# --- 教學段：只有平地、單格落差、小熊 -------------------------------------
ground(0, 15)
put(3, STAND, "S")
coins([6, 8], STAND - 2)
put(11, STAND, "b")

# 一格高的台階。走不上去、得跳——第一次要求玩家按跳鍵的地方。
ground(16, 24, GROUND_TOP - 1)

# 第一個坑。三格，跳得很輕鬆，用來確認玩家真的學會了跳。
ground(28, 44)
bricks(33, 36, STAND - 2)
coins([34, 35], STAND - 3)
put(32, STAND, "b")
put(39, STAND, "b")

# 第一個坑上方擺一排金幣：給玩家一個「跳準一點」的理由，
# 而不是整整一個畫面只有平地。
coins([45, 46, 47], STAND - 2)

ground(48, 64)
put(52, STAND, "b")
coins([55, 56, 57], STAND - 3)
put(58, STAND, "b")
put(60, STAND, "C")

# --- 道具段：頂磚、變大、丟金幣 -------------------------------------------
ground(65, 85)
# 四塊一排：問號、可破、牛奶、問號。外觀上問號磚與牛奶磚一樣，
# 玩家得一塊塊頂過去才知道牛奶藏在哪。
put(68, STAND - 3, "?")
put(69, STAND - 3, "x")
put(70, STAND - 3, "M")
put(71, STAND - 3, "?")
put(78, STAND, "b")

ground(89, 105)
# 地刺放在地面上，逼玩家在平地上也得跳。
put(95, STAND, "^")
put(96, STAND, "^")
put(103, STAND, "^")
bricks(92, 95, STAND - 2)
coins([93, 94], STAND - 3)
# 上層也放一隻小熊。少了牠，拿到牛奶的玩家會被磚台擋著走上層，
# 順便完全避開底下的刺球——強化道具變成「繞過危險」而不是「面對危險」。
put(94, STAND - 3, "b")
# 第一顆刺球。它踩不死，只能繞過或用金幣打——牛奶就在前面幾格，
# 玩家如果頂到了，這裡剛好是第一個試用丟金幣的地方。
put(99, STAND - 2, "s")

ground(110, 130)
put(114, STAND - 3, "?")
put(115, STAND - 3, "?")
put(120, STAND - 3, "M")
put(121, STAND - 3, "x")
put(122, STAND - 3, "x")
put(118, STAND - 1, "s")
put(126, STAND, "b")
coins([111, 112, 113], STAND - 4)

ground(134, 145)
put(141, STAND, "C")

# --- 立體段：移動平台、暗房、跌停箭頭 -------------------------------------
ground(146, 158)
put(150, STAND, "b")

ground(163, 175)
# 垂直平台是通往上層磚台的唯一路徑。上面有五枚金幣與一隻箭頭守著。
#
# 平台起點放第 10 列而不是第 9 列：第 9 列離地 256 px，而跳躍上限是 236 px，
# 邊界只剩幾個像素，實際玩起來就是「這裡老是上不去」。
#
# 磚台右緣收在 175 而不是 176：地面到 175 為止，176 正上方就是坑。玩家站在
# 第 6 列時相機被夾住，關卡底部完全在畫面外——他看不到下面是什麼就踩空了，
# 而且這條路還是被五枚金幣一路引導過去的。
put(168, STAND - 2, "V")
bricks(171, 175, STAND - 5)
coins([171, 172, 173, 174], STAND - 6)
put(173, STAND - 7, "a")

ground(180, 196)
# 水管通往暗房：一排金幣加一塊牛奶磚。看不到裡面有什麼，願意冒險的人才會下去。
put(186, STAND, "1")
put(192, STAND, "b")

ground(201, 215)
# 水平平台橫跨在坑上方。不搭它也跳得過去，搭它可以拿到上層的金幣。
put(200, STAND - 3, "P")
bricks(203, 208, STAND - 2)
coins([204, 205, 206, 207], STAND - 3)
put(205, STAND - 3, "b")
put(206, STAND - 1, "s")
put(210, STAND - 5, "a")

ground(220, 236)
put(224, STAND - 3, "?")
put(225, STAND - 3, "x")
put(226, STAND - 3, "?")
# 這座垂直平台原本什麼都不通往，玩家沒有理由踏上去。
# 行程頂端擺兩枚金幣——從地面跳不到，只有搭平台才拿得到。
put(230, STAND - 4, "V")
coins([230, 231], STAND - 8)
put(233, STAND, "b")
coins([221, 222], STAND - 2)

ground(241, 252)
put(248, STAND, "C")

# --- 關底段：Boss熊與旗竿 --------------------------------------------------
ground(253, 299)
put(258, STAND - 3, "?")
coins([262, 264, 266], STAND - 2)
# Boss 在左右各三格的範圍內踱步，兩側留空給玩家閃避與繞後。
put(272, STAND, "K")
# 旗竿緊接在 Boss 之後。以前放在第 295 格，打倒 Boss 還要走 23 格空地，
# 關底的高潮整個被洩掉。
put(285, STAND, "F")

header = "\n".join([
    "name: 盤面大道",
    "time: 300",
    "pipe1: level1_pipe_a",
    "---",
])

lines = ["".join(row).rstrip() for row in grid]
with open(OUT, "w") as handle:
    handle.write(header + "\n" + "\n".join(lines) + "\n")

print("已寫入 %s（%d 欄 × %d 列）" % (OUT, WIDTH, HEIGHT))
