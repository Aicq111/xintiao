# -*- coding: utf-8 -*-
"""生成 App 图标 1024x1024：深色底 + 翡翠绿 ¥ + 应用名。"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.stdout.reconfigure(encoding='utf-8')

OUT_DIR = r'D:\deepseek工作区\薪跳App\ios\Runner\Assets.xcassets\AppIcon.appiconset'
OUT = os.path.join(OUT_DIR, 'icon_1024.png')

SIZE = 1024
img = Image.new('RGB', (SIZE, SIZE), (11, 18, 32))  # #0B1220
draw = ImageDraw.Draw(img)

# 中心光晕（翡翠绿）
glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r, alpha in [(430, 30), (330, 45), (240, 60)]:
    gd.ellipse([SIZE//2 - r, SIZE//2 - r, SIZE//2 + r, SIZE//2 + r],
               fill=(52, 211, 153, alpha))
glow = glow.filter(ImageFilter.GaussianBlur(80))
img = Image.alpha_composite(img.convert('RGBA'), glow).convert('RGB')
draw = ImageDraw.Draw(img)

def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

f_yen = font(r'C:\Windows\Fonts\segoeui.ttf', 430)
f_zh = font(r'C:\Windows\Fonts\msyh.ttc', 130)

def center_text(d, text, fnt, y, fill):
    try:
        bbox = d.textbbox((0, 0), text, font=fnt)
        w = bbox[2] - bbox[0]
    except Exception:
        w = d.textlength(text, font=fnt)
    d.text(((SIZE - w) // 2, y), text, font=fnt, fill=fill)

center_text(draw, '¥', f_yen, 240, (52, 211, 153))
center_text(draw, '薪跳', f_zh, 700, (240, 244, 248))

img.save(OUT, 'PNG')
print('icon saved:', OUT, os.path.getsize(OUT), 'bytes')
