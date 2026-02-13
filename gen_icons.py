from PIL import Image, ImageDraw
import os

sizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    r = int(size * 0.22)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=(0, 151, 54))
    cx, cy = size // 2, int(size * 0.38)
    cw = int(size * 0.18)
    ch = int(size * 0.42)
    draw.rounded_rectangle(
        [cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2],
        radius=max(3, size // 40), fill='white'
    )
    hw = int(size * 0.36)
    hh = int(size * 0.18)
    draw.rounded_rectangle(
        [cx - hw // 2, cy - hh // 2, cx + hw // 2, cy + hh // 2],
        radius=max(3, size // 40), fill='white'
    )
    py = int(size * 0.76)
    pr = max(2, int(size * 0.06))
    draw.ellipse([cx - pr, py - pr, cx + pr, py + pr], fill='white')
    rr = max(3, int(size * 0.10))
    draw.ellipse([cx - rr, py - rr, cx + rr, py + rr], outline='white', width=max(1, size // 60))
    aw = int(size * 0.12)
    at_y = int(size * 0.62)
    ab = int(size * 0.72)
    draw.polygon(
        [(cx, ab + max(2, size // 30)), (cx - aw, at_y + size // 20), (cx + aw, at_y + size // 20)],
        fill=(255, 255, 255, 200)
    )
    return img.convert('RGB')

out_dir = 'mobile_app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for name, sz in sizes.items():
    icon = create_icon(sz)
    icon.save(os.path.join(out_dir, name))
    print(f'Created {name} ({sz}x{sz})')

print('All icons generated!')
