from PIL import Image, ImageDraw, ImageFont
import os
import math

size = 1024
img = Image.new('RGBA', (size, size), '#0B1E3A')
d = ImageDraw.Draw(img)

for r in range(500, 0, -8):
    alpha = int(120 * (1 - r / 500))
    d.ellipse((512 - r, 512 - r, 512 + r, 512 + r), fill=(30, 144, 255, alpha))

badge_r = 340
cx, cy = 512, 500
d.ellipse((cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r), fill='#122C53', outline='#60A5FA', width=14)

drop = [(cx, cy - 190), (cx - 130, cy + 20), (cx, cy + 180), (cx + 130, cy + 20)]
d.polygon(drop, fill='#38BDF8')
d.polygon([(cx, cy - 120), (cx - 70, cy + 20), (cx, cy + 120), (cx + 70, cy + 20)], fill='#DBF4FF')

gear_r1, gear_r2 = 90, 120
for i in range(12):
    a = i * math.pi / 6
    x1, y1 = cx + int(math.cos(a) * gear_r1), cy + int(math.sin(a) * gear_r1)
    x2, y2 = cx + int(math.cos(a) * gear_r2), cy + int(math.sin(a) * gear_r2)
    d.line((x1, y1, x2, y2), fill='#93C5FD', width=10)

d.ellipse((cx - 85, cy - 85, cx + 85, cy + 85), fill='#0B1E3A', outline='#93C5FD', width=10)
d.ellipse((cx - 26, cy - 26, cx + 26, cy + 26), fill='#93C5FD')

try:
    font = ImageFont.truetype('arial.ttf', 84)
except Exception:
    font = ImageFont.load_default()

text = 'WSSH'
b = d.textbbox((0, 0), text, font=font)
tw, th = b[2] - b[0], b[3] - b[1]
d.text((cx - tw // 2, 860), text, fill='#E2E8F0', font=font)

os.makedirs('assets/branding', exist_ok=True)
out_path = os.path.join('assets', 'branding', 'app_brand.png')
img.save(out_path)
print(f'Created {out_path}')