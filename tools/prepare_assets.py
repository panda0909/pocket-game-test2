"""程式化產生 Game3 的 Q 版遊戲貼圖。

執行方式：
    tools/.venv/bin/python tools/prepare_assets.py

所有圖都以四倍尺寸繪製再縮小，藉此得到平滑邊緣。
相同輸入永遠產生相同輸出，可以安全地重複執行。

為什麼用程式畫而不是手繪或 AI 生圖：主角紅牛是圓潤造型加粗黑輪廓的卡通風，
Game2 那批寫實暗黑風的熊放在平台遊戲裡會被玩家貼著看，風格衝突會很明顯。
用程式畫能把「輪廓粗細、飽和度、圓角半徑」都變成腳本頂端的常數，整批素材
自然統一在同一個調性上，要調整改一個數字重跑就好。
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
ENEMIES = os.path.join(ASSETS, "enemies")

SUPERSAMPLE = 4
TILE = 64

# 全部素材共用的輪廓，這是「和紅牛看起來是同一套」的關鍵。
OUTLINE = (20, 20, 24, 255)
OUTLINE_W = 3

# 高光與陰影都用半透明白／黑疊在底色上，這樣同一組數值可以套用在
# 任何顏色的身體上，換配色時不必重算每一種明暗。
HIGHLIGHT = (255, 255, 255, 70)
SHADOW = (0, 0, 0, 52)

GROUND_TOP = (108, 176, 92, 255)
GROUND_BODY = (146, 104, 66, 255)
BRICK = (186, 116, 78, 255)
BRICK_LINE = (140, 82, 54, 255)
QUESTION = (240, 182, 54, 255)
QUESTION_DARK = (206, 142, 30, 255)
USED = (150, 138, 122, 255)
BREAKABLE = (206, 158, 106, 255)
SPIKE = (198, 204, 214, 255)
SPIKE_BASE = (120, 126, 138, 255)
PIPE = (76, 178, 128, 255)
PIPE_DARK = (48, 138, 96, 255)

COIN = (255, 196, 0, 255)
COIN_DARK = (214, 150, 0, 255)
MILK = (250, 250, 245, 255)
MILK_CAP = (226, 58, 66, 255)
FLAG_POLE = (176, 180, 190, 255)
FLAG_CLOTH = (226, 58, 66, 255)
PLATFORM_TOP = (238, 196, 96, 255)
PLATFORM_BODY = (168, 124, 62, 255)

BEAR = (140, 96, 64, 255)
BEAR_MUZZLE = (208, 176, 140, 255)
BEAR_TIE = (200, 52, 60, 255)
BOSS = (86, 74, 92, 255)
BOSS_MUZZLE = (156, 142, 160, 255)
CROWN = (250, 196, 62, 255)
SPIKEBALL = (198, 66, 78, 255)
SPIKEBALL_DARK = (152, 42, 54, 255)
# 台股跌停是綠色，所以「跌停箭頭」用綠色而不是紅色。
ARROW = (74, 190, 122, 255)
ARROW_DARK = (44, 148, 90, 255)

SKY_TOP = (126, 196, 238, 255)
SKY_BOTTOM = (206, 234, 250, 255)
CANDLE_LIGHT = (255, 255, 255, 46)
CANDLE_DARK = (255, 255, 255, 26)
CLOUD = (255, 255, 255, 150)

WHITE = (255, 255, 255, 255)


def canvas(width, height):
    """開一張四倍大的透明畫布。"""
    img = Image.new("RGBA", (width * SUPERSAMPLE, height * SUPERSAMPLE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def finish(img, width, height, path):
    out = img.resize((width, height), Image.LANCZOS)
    out.save(path)
    return out


def s(value):
    """把最終尺寸的數值換成畫布上的數值。"""
    return value * SUPERSAMPLE


def box(x, y, w, h):
    return [s(x), s(y), s(x + w) - 1, s(y + h) - 1]


def ellipse(draw, x, y, w, h, fill, outline=True):
    draw.ellipse(box(x, y, w, h), fill=fill,
                 outline=OUTLINE if outline else None,
                 width=s(OUTLINE_W) if outline else 0)


def round_rect(draw, x, y, w, h, radius, fill, outline=True):
    draw.rounded_rectangle(box(x, y, w, h), radius=s(radius), fill=fill,
                           outline=OUTLINE if outline else None,
                           width=s(OUTLINE_W) if outline else 0)


def shade_ellipse(img, x, y, w, h):
    """在橢圓範圍內加左上高光與右下陰影，做出圓潤的立體感。

    先畫在獨立圖層再用同一個橢圓當遮罩裁切，明暗才不會溢出輪廓。
    直接畫在主圖上會蓋到旁邊的部件。

    這裡必須用 alpha_composite 而不是 paste。paste 帶遮罩是「取代」像素，
    半透明的高光會把身體底色整片換成半透明白——熊會變成熊貓。多花一次
    通道相乘把遮罩併進圖層的 alpha，才是真正的疊加。
    """
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse(box(x, y, w, h), fill=255)

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.ellipse(box(x + w * 0.08, y + h * 0.06, w * 0.5, h * 0.42), fill=HIGHLIGHT)
    ld.ellipse(box(x + w * 0.32, y + h * 0.52, w * 0.62, h * 0.44), fill=SHADOW)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))

    img.alpha_composite(layer)


# --------------------------------------------------------------------------
# 地形圖集
# --------------------------------------------------------------------------

def draw_ground(draw, ox):
    """土塊，頂端一條草皮。草皮讓玩家一眼分得出「這是站得住的地面」。"""
    round_rect(draw, ox, 0, TILE, TILE, 4, GROUND_BODY)
    draw.rounded_rectangle(box(ox + 2, 2, TILE - 4, 16), radius=s(4), fill=GROUND_TOP)
    for i in range(3):
        cx = ox + 12 + i * 18
        draw.ellipse(box(cx, 22 + (i % 2) * 10, 8, 6), fill=(0, 0, 0, 34))


def draw_brick(draw, ox):
    """磚台。橫縱磚縫讓它和土塊在遠處也分得開。"""
    round_rect(draw, ox, 0, TILE, TILE, 4, BRICK)
    draw.rectangle(box(ox + 3, 30, TILE - 6, 3), fill=BRICK_LINE)
    draw.rectangle(box(ox + 30, 3, 3, 27), fill=BRICK_LINE)
    draw.rectangle(box(ox + 14, 33, 3, 28), fill=BRICK_LINE)
    draw.rectangle(box(ox + 46, 33, 3, 28), fill=BRICK_LINE)


def draw_question(draw, ox):
    """問號磚。牛奶磚外觀相同——玩家要頂了才知道裡面是什麼。"""
    round_rect(draw, ox, 0, TILE, TILE, 8, QUESTION)
    for dx, dy in ((7, 7), (TILE - 13, 7), (7, TILE - 13), (TILE - 13, TILE - 13)):
        draw.ellipse(box(ox + dx, dy, 6, 6), fill=QUESTION_DARK)
    # 問號：上方圓弧 + 下方短豎 + 一點
    draw.arc(box(ox + 20, 14, 24, 22), start=160, end=20,
             fill=OUTLINE, width=s(5))
    draw.rectangle(box(ox + 30, 30, 5, 10), fill=OUTLINE)
    draw.ellipse(box(ox + 29, 44, 7, 7), fill=OUTLINE)


def draw_used(draw, ox):
    """頂過的磚。灰掉並凹一格，玩家不會再浪費時間去頂它。"""
    round_rect(draw, ox, 0, TILE, TILE, 8, USED)
    for dx, dy in ((7, 7), (TILE - 13, 7), (7, TILE - 13), (TILE - 13, TILE - 13)):
        draw.ellipse(box(ox + dx, dy, 6, 6), fill=(114, 104, 92, 255))
    draw.rounded_rectangle(box(ox + 18, 24, 28, 16), radius=s(4), fill=(120, 110, 98, 255))


def draw_breakable(draw, ox):
    """可破磚。畫上裂縫暗示「這塊撞得動」。"""
    round_rect(draw, ox, 0, TILE, TILE, 4, BREAKABLE)
    draw.line([s(ox + 20), s(6), s(ox + 28), s(24), s(ox + 18), s(38),
               s(ox + 26), s(56)], fill=BRICK_LINE, width=s(3))
    draw.line([s(ox + 44), s(10), s(ox + 38), s(28), s(ox + 48), s(46)],
              fill=BRICK_LINE, width=s(3))


def draw_spike(draw, ox):
    """地刺。基座壓在下半格，尖端朝上，觸即受傷。"""
    draw.rounded_rectangle(box(ox + 2, 46, TILE - 4, 18), radius=s(3),
                           fill=SPIKE_BASE, outline=OUTLINE, width=s(OUTLINE_W))
    for i in range(3):
        left = ox + 6 + i * 18
        draw.polygon([s(left), s(50), s(left + 8), s(16), s(left + 16), s(50)],
                     fill=SPIKE, outline=OUTLINE, width=s(OUTLINE_W))


def draw_pipe(draw, ox):
    """水管口。上緣寬簷是「這裡可以進去」的視覺提示。"""
    draw.rectangle(box(ox + 8, 18, TILE - 16, TILE - 18), fill=PIPE)
    draw.rounded_rectangle(box(ox + 2, 2, TILE - 4, 20), radius=s(5), fill=PIPE,
                           outline=OUTLINE, width=s(OUTLINE_W))
    draw.rectangle(box(ox + 8, 22, 6, TILE - 22), fill=PIPE_DARK)
    draw.rectangle(box(ox + TILE - 16, 22, 6, TILE - 22), fill=PIPE_DARK)
    draw.line([s(ox + 8), s(22), s(ox + 8), s(TILE)], fill=OUTLINE, width=s(OUTLINE_W))
    draw.line([s(ox + TILE - 8) - 1, s(22), s(ox + TILE - 8) - 1, s(TILE)],
              fill=OUTLINE, width=s(OUTLINE_W))
    draw.ellipse(box(ox + 14, 6, 14, 10), fill=HIGHLIGHT)


# 順序必須和 TileGlossary.atlas_column 一致。
TILE_DRAWERS = [
    draw_ground, draw_brick, draw_question, draw_used,
    draw_breakable, draw_spike, draw_pipe,
]


def build_tiles():
    count = len(TILE_DRAWERS)
    img, draw = canvas(TILE * count, TILE)
    for i, drawer in enumerate(TILE_DRAWERS):
        drawer(draw, TILE * i)
    return finish(img, TILE * count, TILE, os.path.join(ASSETS, "tiles.png"))


# --------------------------------------------------------------------------
# 道具與場景物件
# --------------------------------------------------------------------------

def build_coin():
    size = 48
    img, draw = canvas(size, size)
    ellipse(draw, 2, 2, size - 4, size - 4, COIN)
    shade_ellipse(img, 2, 2, size - 4, size - 4)
    draw = ImageDraw.Draw(img)
    ellipse(draw, 13, 10, 22, 28, COIN_DARK, outline=False)
    ellipse(draw, 15, 12, 18, 24, COIN, outline=False)
    # 中央的向上箭頭：金幣同時是分數與彈藥，用漲勢符號暗示它有攻擊性
    draw.polygon([s(24), s(14), s(32), s(26), s(16), s(26)], fill=COIN_DARK)
    draw.rectangle(box(21, 26, 6, 10), fill=COIN_DARK)
    return finish(img, size, size, os.path.join(ASSETS, "coin.png"))


def build_milk():
    w, h = 44, 56
    img, draw = canvas(w, h)
    # 牛奶盒本體
    round_rect(draw, 4, 12, w - 8, h - 14, 5, MILK)
    # 屋頂式盒頂
    draw.polygon([s(4), s(14), s(w // 2), s(2), s(w - 4), s(14)],
                 fill=MILK, outline=OUTLINE, width=s(OUTLINE_W))
    draw.rectangle(box(w // 2 - 3, 2, 6, 12), fill=MILK_CAP)
    # 紅色向上箭頭 = 漲停
    draw.polygon([s(22), s(22), s(33), s(38), s(11), s(38)], fill=MILK_CAP)
    draw.rectangle(box(18, 38, 8, 11), fill=MILK_CAP)
    return finish(img, w, h, os.path.join(ASSETS, "milk.png"))


def build_flag():
    w, h = 64, 256
    img, draw = canvas(w, h)
    draw.rounded_rectangle(box(28, 8, 8, h - 12), radius=s(4), fill=FLAG_POLE,
                           outline=OUTLINE, width=s(OUTLINE_W))
    ellipse(draw, 22, 0, 20, 20, COIN)
    draw.polygon([s(36), s(26), s(36), s(74), s(60), s(50)],
                 fill=FLAG_CLOTH, outline=OUTLINE, width=s(OUTLINE_W))
    draw.rounded_rectangle(box(12, h - 22, 40, 18), radius=s(4), fill=PLATFORM_BODY,
                           outline=OUTLINE, width=s(OUTLINE_W))
    return finish(img, w, h, os.path.join(ASSETS, "flag.png"))


def build_platform():
    w, h = 192, 32
    img, draw = canvas(w, h)
    round_rect(draw, 2, 2, w - 4, h - 4, 8, PLATFORM_BODY)
    draw.rounded_rectangle(box(6, 5, w - 12, 11), radius=s(5), fill=PLATFORM_TOP)
    for i in range(5):
        cx = 24 + i * 36
        draw.ellipse(box(cx, 20, 8, 6), fill=(0, 0, 0, 40))
    return finish(img, w, h, os.path.join(ASSETS, "platform.png"))


def build_background():
    """天空漸層加遠景 K 線剪影。寬度等於視窗寬，供視差橫向重複捲動。

    K 線用半透明白，讓它讀起來是雲層後面的盤面，而不是會擋路的地形——
    平台遊戲最怕玩家把背景誤認為可以站的東西。
    """
    w, h = 1280, 720
    img = Image.new("RGBA", (w, h), SKY_TOP)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        color = tuple(
            int(SKY_TOP[i] + (SKY_BOTTOM[i] - SKY_TOP[i]) * t) for i in range(4)
        )
        draw.line([(0, y), (w, y)], fill=color)

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    # 用固定的等差序列產生高低起伏，不用隨機數——重跑要得到同一張圖
    for i in range(32):
        x = 14 + i * 40
        wave = math.sin(i * 0.7) * 90 + math.sin(i * 0.23) * 60
        top = 300 + wave
        height = 120 + abs(math.cos(i * 0.5)) * 150
        color = CANDLE_LIGHT if i % 2 == 0 else CANDLE_DARK
        ld.rectangle([x, top, x + 20, top + height], fill=color)
        ld.rectangle([x + 8, top - 34, x + 12, top + height + 34], fill=color)
    img.alpha_composite(layer)

    clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    for cx, cy, cw in ((150, 110, 200), (520, 70, 260), (900, 140, 220), (1180, 90, 180)):
        cd.ellipse([cx, cy, cx + cw, cy + cw * 0.36], fill=CLOUD)
        cd.ellipse([cx + cw * 0.22, cy - cw * 0.14, cx + cw * 0.72,
                    cy + cw * 0.3], fill=CLOUD)
    img.alpha_composite(clouds)

    img.save(os.path.join(ASSETS, "background.png"))
    return img


# --------------------------------------------------------------------------
# 敵人
# --------------------------------------------------------------------------

def _bear(size, body, muzzle, crown=False, angry=False):
    """Q 版熊：圓身、圓耳、豆豆眼、紅領帶。Boss 多一頂皇冠與怒眉。

    造型刻意和紅牛同構——圓身加粗黑輪廓加小四肢——這樣兩者放在同一畫面裡
    看起來是同一個世界的居民，而不是從兩套素材庫拼來的。
    """
    img, draw = canvas(size, size)
    u = size / 64.0

    def sc(v):
        return v * u

    # 耳朵先畫，才會被身體壓在後面
    ellipse(draw, sc(8), sc(4), sc(16), sc(16), body)
    ellipse(draw, sc(40), sc(4), sc(16), sc(16), body)
    # 腳
    ellipse(draw, sc(10), sc(48), sc(16), sc(14), body)
    ellipse(draw, sc(38), sc(48), sc(16), sc(14), body)
    # 身體
    ellipse(draw, sc(6), sc(10), sc(52), sc(46), body)
    shade_ellipse(img, sc(6), sc(10), sc(52), sc(46))
    draw = ImageDraw.Draw(img)
    # 口鼻
    ellipse(draw, sc(22), sc(30), sc(20), sc(15), muzzle)
    ellipse(draw, sc(29), sc(32), sc(6), sc(5), OUTLINE, outline=False)
    # 眼睛
    ellipse(draw, sc(19), sc(20), sc(7), sc(7), OUTLINE, outline=False)
    ellipse(draw, sc(38), sc(20), sc(7), sc(7), OUTLINE, outline=False)
    ellipse(draw, sc(21), sc(21), sc(3), sc(3), WHITE, outline=False)
    ellipse(draw, sc(40), sc(21), sc(3), sc(3), WHITE, outline=False)
    if angry:
        draw.line([sc(17) * SUPERSAMPLE, sc(15) * SUPERSAMPLE,
                   sc(28) * SUPERSAMPLE, sc(20) * SUPERSAMPLE],
                  fill=OUTLINE, width=int(sc(3) * SUPERSAMPLE))
        draw.line([sc(47) * SUPERSAMPLE, sc(15) * SUPERSAMPLE,
                   sc(36) * SUPERSAMPLE, sc(20) * SUPERSAMPLE],
                  fill=OUTLINE, width=int(sc(3) * SUPERSAMPLE))
    # 紅領帶：一眼看出是「股市熊」而不是森林裡的熊
    draw.polygon([sc(32) * SUPERSAMPLE, sc(44) * SUPERSAMPLE,
                  sc(25) * SUPERSAMPLE, sc(60) * SUPERSAMPLE,
                  sc(39) * SUPERSAMPLE, sc(60) * SUPERSAMPLE],
                 fill=BEAR_TIE, outline=OUTLINE, width=int(sc(2) * SUPERSAMPLE))
    if crown:
        # 尖角與冠帶分開畫。第一版把整頂皇冠寫成一條鋸齒多邊形，高度只有
        # 八格卻套上同樣粗的輪廓，縮圖後整頂變成一團黑——粗輪廓的風格是好的，
        # 但形狀得留得夠大才撐得住它。
        lw = max(1, int(sc(2) * SUPERSAMPLE))
        for peak_x in (24, 32, 40):
            draw.polygon([
                (sc(peak_x) * SUPERSAMPLE, sc(1) * SUPERSAMPLE),
                (sc(peak_x - 6) * SUPERSAMPLE, sc(13) * SUPERSAMPLE),
                (sc(peak_x + 6) * SUPERSAMPLE, sc(13) * SUPERSAMPLE),
            ], fill=CROWN, outline=OUTLINE, width=lw)
        round_rect(draw, sc(17), sc(9), sc(30), sc(7), sc(2), CROWN)
        for dot_x in (23, 32, 41):
            ellipse(draw, sc(dot_x - 2), sc(11), sc(4), sc(4), MILK_CAP,
                    outline=False)
    return img


def build_bear():
    size = 56
    img = _bear(size, BEAR, BEAR_MUZZLE)
    return finish(img, size, size, os.path.join(ENEMIES, "bear.png"))


def build_boss():
    size = 128
    img = _bear(size, BOSS, BOSS_MUZZLE, crown=True, angry=True)
    return finish(img, size, size, os.path.join(ENEMIES, "boss.png"))


def build_spikeball():
    size = 56
    img, draw = canvas(size, size)
    cx = cy = size / 2.0
    r = size * 0.30
    for i in range(10):
        a = i * math.tau / 10.0
        tip = (cx + math.cos(a) * size * 0.48, cy + math.sin(a) * size * 0.48)
        left = (cx + math.cos(a - 0.28) * r, cy + math.sin(a - 0.28) * r)
        right = (cx + math.cos(a + 0.28) * r, cy + math.sin(a + 0.28) * r)
        draw.polygon([(p[0] * SUPERSAMPLE, p[1] * SUPERSAMPLE)
                      for p in (tip, left, right)],
                     fill=SPIKEBALL_DARK, outline=OUTLINE, width=s(2))
    ellipse(draw, cx - r, cy - r, r * 2, r * 2, SPIKEBALL)
    shade_ellipse(img, cx - r, cy - r, r * 2, r * 2)
    draw = ImageDraw.Draw(img)
    # 兇眼：刺球不可踩，外觀必須讓玩家不敢踩
    ellipse(draw, cx - 9, cy - 5, 7, 8, WHITE, outline=False)
    ellipse(draw, cx + 2, cy - 5, 7, 8, WHITE, outline=False)
    ellipse(draw, cx - 7, cy - 2, 4, 4, OUTLINE, outline=False)
    ellipse(draw, cx + 4, cy - 2, 4, 4, OUTLINE, outline=False)
    return finish(img, size, size, os.path.join(ENEMIES, "spikeball.png"))


def build_arrow():
    """跌停箭頭。台股跌停是綠色，所以它是綠的。"""
    w, h = 52, 52
    img, draw = canvas(w, h)
    draw.polygon([s(26), s(48), s(48), s(24), s(34), s(24), s(34), s(6),
                  s(18), s(6), s(18), s(24), s(4), s(24)],
                 fill=ARROW, outline=OUTLINE, width=s(OUTLINE_W))
    # 眼睛放在箭頭最寬的那一段，才不會突出箭身之外
    ellipse(draw, 15, 26, 9, 9, WHITE, outline=False)
    ellipse(draw, 28, 26, 9, 9, WHITE, outline=False)
    ellipse(draw, 17, 29, 5, 5, OUTLINE, outline=False)
    ellipse(draw, 30, 29, 5, 5, OUTLINE, outline=False)
    draw.line([s(21), s(12), s(31), s(12)], fill=ARROW_DARK, width=s(3))
    return finish(img, w, h, os.path.join(ENEMIES, "arrow.png"))


def build_share_cover():
    """分享用的 Open Graph 預覽圖，1200x630。

    Facebook 不吃我們送過去的文字，只讀網址的 OG 標籤，所以分享長什麼樣子
    完全由這張圖和那幾行 meta 決定。1200x630 是 OG 的標準比例，小於
    600x315 的話 Facebook 會縮成小方圖。

    三隻主角並排放在盤面背景上——分享出去的人想炫耀的是「我玩了這個」，
    所以主角要夠大、標題要看得清。
    """
    width, height = 1200, 630
    img = Image.new("RGBA", (width, height), SKY_TOP)
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / (height - 1)
        color = tuple(
            int(SKY_TOP[i] + (SKY_BOTTOM[i] - SKY_TOP[i]) * t) for i in range(4)
        )
        draw.line([(0, y), (width, y)], fill=color)

    # 遠景 K 線，和遊戲背景同一套語彙
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for i in range(28):
        x = 12 + i * 43
        wave = math.sin(i * 0.7) * 70 + math.sin(i * 0.23) * 50
        top = 230 + wave
        bar = 110 + abs(math.cos(i * 0.5)) * 130
        ld.rectangle([x, top, x + 22, top + bar],
                     fill=CANDLE_LIGHT if i % 2 == 0 else CANDLE_DARK)
    img.alpha_composite(layer)

    # 地面
    ground = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ground)
    gd.rectangle([0, height - 96, width, height], fill=GROUND_BODY)
    gd.rectangle([0, height - 96, width, height - 76], fill=GROUND_TOP)
    img.alpha_composite(ground)

    # 三隻主角。原圖高 180，放大到 300 讓它們在縮圖裡也看得清。
    characters = ["red_bull.png", "dino.png", "gecko.png"]
    target_h = 300
    slots = [300, 600, 900]
    for name, cx in zip(characters, slots):
        path = os.path.join(ASSETS, "characters", name)
        if not os.path.exists(path):
            continue
        sprite = Image.open(path).convert("RGBA")
        scale = target_h / sprite.height
        sprite = sprite.resize(
            (max(1, int(sprite.width * scale)), target_h), Image.LANCZOS)
        img.alpha_composite(sprite, (cx - sprite.width // 2,
                                     height - 96 - target_h + 8))

    # 標題直接畫在圖上。OG 的 title 標籤在 Facebook 卡片上會另外顯示，
    # 但貼到 Threads 或存成圖片時只剩這張圖，所以圖自己要說得出名字。
    font_path = os.path.join(ASSETS, "fonts", "NotoSansTC-Bold.otf")
    if os.path.exists(font_path):
        title_font = ImageFont.truetype(font_path, 86)
        text = "口袋牛牛大冒險"
        td = ImageDraw.Draw(img)
        box = td.textbbox((0, 0), text, font=title_font)
        tx = (width - (box[2] - box[0])) // 2
        ty = 44
        # 粗描邊，和遊戲內的 HUD 同一個做法，淺色天空上才讀得清
        td.text((tx, ty), text, font=title_font, fill=(255, 255, 255, 255),
                stroke_width=10, stroke_fill=(20, 24, 34, 255))

    img.save(os.path.join(ASSETS, "share_cover.png"))
    return img


def main():
    os.makedirs(ENEMIES, exist_ok=True)
    outputs = [
        ("tiles.png", build_tiles()),
        ("coin.png", build_coin()),
        ("milk.png", build_milk()),
        ("flag.png", build_flag()),
        ("platform.png", build_platform()),
        ("background.png", build_background()),
        ("enemies/bear.png", build_bear()),
        ("enemies/spikeball.png", build_spikeball()),
        ("enemies/arrow.png", build_arrow()),
        ("enemies/boss.png", build_boss()),
        ("share_cover.png", build_share_cover()),
    ]
    for name, image in outputs:
        print("%-22s %s" % (name, image.size))


if __name__ == "__main__":
    main()
