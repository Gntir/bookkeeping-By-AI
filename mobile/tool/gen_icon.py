# -*- coding: utf-8 -*-
# 生成启动图标（方案B：对话气泡 + ¥）
# 产物：mipmap-*/ic_launcher.png（旧版）+ mipmap-*/ic_launcher_foreground.png（自适应前景）
# 用法：backend/.venv/Scripts/python mobile/tool/gen_icon.py
import os
from PIL import Image, ImageDraw, ImageFont

RES = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
GREEN = (46, 158, 107, 255)  # #2E9E6B，与 App 主题色一致
WHITE = (255, 255, 255, 255)

FONT_CANDIDATES = [r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\msyhbd.ttf"]


def load_font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def draw_bubble(img, S, bubble_rect, radius, tail_pts, yen_center, yen_size):
    """在 img 上按 S 缩放比例画气泡 + ¥"""
    d = ImageDraw.Draw(img)
    r = [int(v * S) for v in bubble_rect]
    d.rounded_rectangle(r, radius=int(radius * S), fill=WHITE)
    d.polygon([(int(x * S), int(y * S)) for x, y in tail_pts], fill=WHITE)
    d.text((int(yen_center[0] * S), int(yen_center[1] * S)), "¥",
           font=load_font(int(yen_size * S)), fill=GREEN, anchor="mm")


def make_legacy():
    """旧版图标：绿底圆角方形（圆角烘焙进 PNG）"""
    base, S = 1024, 2
    img = Image.new("RGBA", (base * S, base * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([int(v * S) for v in (43, 43, 981, 981)], radius=int(213 * S), fill=GREEN)
    draw_bubble(img, S, (192, 256, 832, 683), 149,
                [(384, 661), (384, 832), (555, 661)], (512, 480), 320)
    img = img.resize((base, base), Image.LANCZOS)
    for name, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        out = os.path.join(RES, f"mipmap-{name}", "ic_launcher.png")
        img.resize((size, size), Image.LANCZOS).save(out)
        print("written", out)


def make_foreground():
    """自适应图标前景：透明底，内容控制在中央 66% 安全区内"""
    base, S = 432, 3
    img = Image.new("RGBA", (base * S, base * S), (0, 0, 0, 0))
    draw_bubble(img, S, (116, 140, 316, 273), 47,
                [(176, 268), (176, 320), (222, 268)], (216, 204), 100)
    img = img.resize((base, base), Image.LANCZOS)
    for name, size in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
        out = os.path.join(RES, f"mipmap-{name}", "ic_launcher_foreground.png")
        img.resize((size, size), Image.LANCZOS).save(out)
        print("written", out)


if __name__ == "__main__":
    make_legacy()
    make_foreground()
    print("done")
