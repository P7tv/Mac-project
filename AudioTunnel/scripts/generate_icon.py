import os
import subprocess
import math
from PIL import Image, ImageDraw, ImageFilter

def create_audiotunnel_icon(output_icns_path):
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # 1. macOS Squircle Shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    margin = 110
    corner = 190
    s_draw.rounded_rectangle(
        [margin, margin + 25, size - margin, size - margin + 25],
        radius=corner,
        fill=(0, 0, 0, 160)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    img.paste(shadow, (0, 0), shadow)

    # 2. Main Squircle Body (Gradient: Deep Obsidian -> Electric Indigo / Navy)
    squircle = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(squircle)
    
    for y in range(margin, size - margin):
        factor = (y - margin) / float(size - 2 * margin)
        # Deep space black (#050b14) to rich electric navy (#0b2b4e)
        r = int(5 + factor * (12 - 5))
        g = int(11 + factor * (38 - 11))
        b = int(24 + factor * (78 - 24))
        sq_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new("L", (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        fill=255
    )

    # Border stroke
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    b_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        outline=(255, 255, 255, 65),
        width=4
    )

    squircle.putalpha(mask)
    img.paste(squircle, (0, 0), squircle)
    img.paste(border, (0, 0), border)

    # 3. Ambient Cyan Radial Glow in center
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    center_x, center_y = size // 2, size // 2 - 20
    for radius in range(260, 40, -15):
        alpha = int((1.0 - (radius / 260.0)) * 60)
        g_draw.ellipse(
            [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
            fill=(0, 242, 254, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(25))
    img.paste(glow, (0, 0), glow)

    # 4. Concentric Soundwave Tunnel Rings (Acoustic Ripples)
    rings = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(rings)
    radii = [130, 190, 250]
    alphas = [180, 110, 60]
    for r, a in zip(radii, alphas):
        r_draw.ellipse(
            [center_x - r, center_y - r, center_x + r, center_y + r],
            outline=(0, 229, 255, a),
            width=5
        )
    rings = rings.filter(ImageFilter.GaussianBlur(3))
    img.paste(rings, (0, 0), rings)

    # 5. Over-Ear Headphones Motif
    hp = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hp_draw = ImageDraw.Draw(hp)

    # Headphone Headband Arc (Top Arc)
    arc_box = [center_x - 170, center_y - 200, center_x + 170, center_y + 140]
    hp_draw.arc(arc_box, start=190, end=350, fill=(0, 242, 254, 255), width=28)

    # Inner headband highlight
    hp_draw.arc(arc_box, start=195, end=345, fill=(255, 255, 255, 240), width=8)

    # Earcups (Left and Right)
    cup_w, cup_h = 60, 130
    left_cup_x = center_x - 195
    right_cup_x = center_x + 135
    cup_y = center_y - 45

    # Shadow for earcups
    cup_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(cup_shadow)
    cs_draw.rounded_rectangle([left_cup_x, cup_y + 8, left_cup_x + cup_w, cup_y + cup_h + 8], radius=30, fill=(0, 0, 0, 140))
    cs_draw.rounded_rectangle([right_cup_x, cup_y + 8, right_cup_x + cup_w, cup_y + cup_h + 8], radius=30, fill=(0, 0, 0, 140))
    cup_shadow = cup_shadow.filter(ImageFilter.GaussianBlur(12))
    img.paste(cup_shadow, (0, 0), cup_shadow)

    # Left Earcup Body
    hp_draw.rounded_rectangle(
        [left_cup_x, cup_y, left_cup_x + cup_w, cup_y + cup_h],
        radius=28,
        fill=(15, 30, 55, 255),
        outline=(0, 242, 254, 255),
        width=5
    )
    # Right Earcup Body
    hp_draw.rounded_rectangle(
        [right_cup_x, cup_y, right_cup_x + cup_w, cup_y + cup_h],
        radius=28,
        fill=(15, 30, 55, 255),
        outline=(0, 242, 254, 255),
        width=5
    )

    # Inner Earcup Cushion Highlight
    hp_draw.rounded_rectangle(
        [left_cup_x + 10, cup_y + 16, left_cup_x + cup_w - 10, cup_y + cup_h - 16],
        radius=18,
        fill=(0, 229, 255, 160)
    )
    hp_draw.rounded_rectangle(
        [right_cup_x + 10, cup_y + 16, right_cup_x + cup_w - 10, cup_y + cup_h - 16],
        radius=18,
        fill=(0, 229, 255, 160)
    )

    img.paste(hp, (0, 0), hp)

    # 6. Audio Waveform Tunnel in Center
    wave = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave)
    
    # Sound wave bars across center
    bar_heights = [24, 48, 85, 130, 160, 120, 75, 45, 20]
    bar_spacing = 22
    start_bx = center_x - ((len(bar_heights) * bar_spacing) // 2)
    
    for i, h in enumerate(bar_heights):
        bx = start_bx + i * bar_spacing
        by1 = center_y + 10 - (h // 2)
        by2 = center_y + 10 + (h // 2)
        # Gradient bar color from neon blue to bright cyan
        w_draw.rounded_rectangle([bx, by1, bx + 10, by2], radius=5, fill=(0, 242, 254, 240))
        # Inner white shine
        w_draw.rounded_rectangle([bx + 2, by1 + 4, bx + 8, by2 - 4], radius=3, fill=(255, 255, 255, 200))

    img.paste(wave, (0, 0), wave)

    # 7. Multi-resolution generation
    iconset_dir = "/tmp/AudioTunnel.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    master_png = "/tmp/audiotunnel_master_1024.png"
    img.save(master_png)

    resolutions = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for res, filename in resolutions:
        resized = img.resize((res, res), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))

    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns_path], check=True)
    print(f"Generated {output_icns_path}")

if __name__ == "__main__":
    create_audiotunnel_icon("AudioTunnel/Resources/AppIcon.icns")
