"""產生遊戲的音效與背景音樂到 assets/audio/。

執行方式：
    python3 tools/prepare_audio.py
    （純標準函式庫，不需要任何套件）

為什麼用程式產生而不是找現成音檔：和 prepare_assets.py 同一個理由——
素材的來源、授權與可重現性都留在版本庫裡。相同輸入永遠產生相同的位元組，
想調整某個音效就改這裡的參數，不必回去翻是從哪個網站下載的。

風格是 8-bit 方波，因為 Q 版像素造型配合成音色最自然，而且方波用純數學
就能合成，不需要取樣素材。

聲音設計的原則：短。跳躍音超過 0.15 秒就會蓋掉下一次跳躍的回饋，
玩家連跳時聽到的會是一團糊掉的聲音。
"""

import math
import os
import struct
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio")

# 音名對頻率。只列實際用得到的。
NOTES = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
    "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99,
    "A5": 880.00, "B5": 987.77,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98,
}


def _square(t, freq, duty=0.5):
    """方波。duty 控制音色亮度：0.5 圓潤、0.125 尖銳。"""
    if freq <= 0.0:
        return 0.0
    phase = (t * freq) % 1.0
    return 1.0 if phase < duty else -1.0


def _triangle(t, freq):
    if freq <= 0.0:
        return 0.0
    phase = (t * freq) % 1.0
    return 4.0 * abs(phase - 0.5) - 1.0


def _noise(i):
    """確定性的偽亂數雜訊。用固定遞迴而不是 random，才能重現。"""
    x = (i * 1103515245 + 12345) & 0x7FFFFFFF
    return (x / 0x3FFFFFFF) - 1.0


def _envelope(pos, attack=0.01, release=0.35):
    """線性起音與收音。pos 是 0..1 的相對位置。"""
    if pos < attack:
        return pos / attack
    if pos > 1.0 - release:
        return max(0.0, (1.0 - pos) / release)
    return 1.0


def tone(freq_from, freq_to, duration, duty=0.5, volume=0.35,
         attack=0.01, release=0.35, wave_fn=None):
    """一段掃頻音。freq_from 到 freq_to 線性滑音。"""
    frames = int(RATE * duration)
    out = []
    phase = 0.0
    for i in range(frames):
        pos = i / max(1, frames - 1)
        freq = freq_from + (freq_to - freq_from) * pos
        # 用相位累加而不是 t*freq，滑音才不會在頻率變化時爆音
        phase += freq / RATE
        if wave_fn is None:
            value = 1.0 if (phase % 1.0) < duty else -1.0
        else:
            value = wave_fn(phase, freq)
        out.append(value * _envelope(pos, attack, release) * volume)
    return out


def noise_burst(duration, volume=0.25, release=0.6):
    frames = int(RATE * duration)
    return [
        _noise(i) * _envelope(i / max(1, frames - 1), 0.005, release) * volume
        for i in range(frames)
    ]


def sequence(steps, duty=0.5, volume=0.35):
    """一串音符。steps 是 (音名或 None, 秒數) 的清單。"""
    out = []
    for name, dur in steps:
        freq = NOTES[name] if name else 0.0
        out.extend(tone(freq, freq, dur, duty=duty, volume=volume,
                        attack=0.008, release=0.25))
    return out


def mix(*tracks):
    """疊加多軌，長度取最長的。"""
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    return out


def write_wav(name, samples):
    path = os.path.join(OUT_DIR, name + ".wav")
    frames = bytearray()
    for value in samples:
        # 軟削峰而不是硬切。硬切在疊軌爆音時會產生刺耳的方波失真。
        clamped = math.tanh(value)
        frames.extend(struct.pack("<h", int(clamped * 32000)))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))
    return path


def build_music():
    """背景音樂。四小節循環，方波主旋律配三角波低音。

    刻意寫得單純：關卡要跑好幾分鐘，複雜的旋律聽第三遍就開始煩。
    """
    beat = 0.24
    melody_steps = [
        ("E5", beat), ("E5", beat), (None, beat), ("E5", beat),
        (None, beat), ("C5", beat), ("E5", beat), ("G5", beat * 2),
        (None, beat * 2),
        ("G4", beat * 2), (None, beat * 2),

        ("C5", beat * 1.5), ("G4", beat * 1.5), (None, beat),
        ("E4", beat * 1.5), ("A4", beat), ("B4", beat),
        ("A4", beat), ("G4", beat), ("E5", beat), ("G5", beat),
        ("A5", beat), ("F5", beat), ("G5", beat),
        (None, beat), ("E5", beat), ("C5", beat), ("D5", beat),
        ("B4", beat * 2),
    ]
    bass_steps = [
        ("C4", beat * 2), ("G4", beat * 2), ("C4", beat * 2), ("G4", beat * 2),
        ("C4", beat * 2), ("G4", beat * 2), ("C4", beat * 2), ("G4", beat * 2),
        ("F4", beat * 2), ("C4", beat * 2), ("G4", beat * 2), ("C4", beat * 2),
        ("F4", beat * 2), ("C4", beat * 2), ("G4", beat * 2), ("C4", beat * 2),
    ]
    melody = sequence(melody_steps, duty=0.5, volume=0.16)
    bass = []
    for name, dur in bass_steps:
        freq = NOTES[name] / 2.0
        bass.extend(tone(freq, freq, dur, volume=0.13, attack=0.01,
                         release=0.2,
                         wave_fn=lambda p, f: _triangle(p, 1.0)))
    return mix(melody, bass)


SOUNDS = {
    # 跳躍：上行滑音。短到不會蓋掉下一次跳躍。
    "jump": lambda: tone(300, 720, 0.11, duty=0.5, volume=0.30, release=0.5),
    # 踩死敵人：下行，和跳躍相反，聽得出方向性
    "stomp": lambda: tone(640, 180, 0.10, duty=0.25, volume=0.34, release=0.5),
    # 金幣：兩個音，第二個高五度。經典的「叮咚」
    "coin": lambda: sequence([("B5", 0.045), ("E6", 0.14)],
                             duty=0.5, volume=0.26),
    # 頂磚：低而悶的一下
    "bump": lambda: tone(180, 110, 0.09, duty=0.5, volume=0.30, release=0.6),
    # 磚塊破掉：雜訊爆
    "brick_break": lambda: mix(noise_burst(0.22, volume=0.22),
                               tone(400, 90, 0.18, duty=0.25, volume=0.16)),
    # 變大：上行大三和弦
    "powerup": lambda: sequence(
        [("C5", 0.07), ("E5", 0.07), ("G5", 0.07), ("C6", 0.20)],
        duty=0.5, volume=0.28),
    # 受傷變小：下行，和變大相反
    "hurt": lambda: sequence(
        [("C6", 0.06), ("G5", 0.06), ("E5", 0.06), ("C5", 0.18)],
        duty=0.25, volume=0.28),
    # 死亡：長的下行滑音，讓那 0.9 秒的停頓有東西聽
    "death": lambda: mix(
        sequence([("G5", 0.12), ("E5", 0.10), ("C5", 0.10)],
                 duty=0.5, volume=0.26),
        tone(520, 60, 0.85, duty=0.5, volume=0.22, release=0.5)),
    # 丟金幣：短促的氣音
    "throw": lambda: mix(noise_burst(0.07, volume=0.14),
                         tone(760, 480, 0.07, duty=0.125, volume=0.20)),
    # 打中 Boss：雜訊加低頻
    "boss_hit": lambda: mix(noise_burst(0.14, volume=0.20),
                            tone(260, 150, 0.14, duty=0.25, volume=0.24)),
    # 打倒 Boss
    "boss_down": lambda: mix(
        noise_burst(0.5, volume=0.18),
        tone(420, 50, 0.55, duty=0.5, volume=0.26, release=0.5)),
    # 加一條命
    "one_up": lambda: sequence(
        [("E5", 0.08), ("G5", 0.08), ("E6", 0.08), ("C6", 0.08),
         ("D6", 0.08), ("G6", 0.24)], duty=0.5, volume=0.26),
    # 通關小號角
    "clear": lambda: sequence(
        [("C5", 0.11), ("E5", 0.11), ("G5", 0.11), ("C6", 0.11),
         ("G5", 0.11), ("C6", 0.42)], duty=0.5, volume=0.28),
    # 檢查點
    "checkpoint": lambda: sequence([("G4", 0.07), ("C5", 0.07), ("E5", 0.18)],
                                   duty=0.5, volume=0.24),
    # 進水管
    "pipe": lambda: tone(520, 120, 0.28, duty=0.25, volume=0.26, release=0.5),
    # 選單移動與確認
    "menu_move": lambda: tone(520, 520, 0.05, duty=0.25, volume=0.20),
    "menu_confirm": lambda: sequence([("E5", 0.06), ("A5", 0.14)],
                                     duty=0.5, volume=0.24),
    # 時間快沒了的警告
    "hurry": lambda: sequence([("E6", 0.07), (None, 0.05), ("E6", 0.07)],
                              duty=0.25, volume=0.22),
    # 「這個現在還不行」。條件不成立的操作一定要有聲音——
    # 完全沒反應會讓玩家以為那個鍵是壞的，然後永遠不再按它。
    "denied": lambda: sequence([("D4", 0.06), ("C4", 0.12)],
                               duty=0.125, volume=0.20),
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, make in sorted(SOUNDS.items()):
        path = write_wav(name, make())
        print("已寫入 %s（%.2f 秒）"
              % (os.path.relpath(path, ROOT),
                 os.path.getsize(path) / (RATE * 2.0)))
    path = write_wav("bgm", build_music())
    print("已寫入 %s（%.2f 秒，循環）"
          % (os.path.relpath(path, ROOT),
             os.path.getsize(path) / (RATE * 2.0)))


if __name__ == "__main__":
    main()
