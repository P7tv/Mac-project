import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_keysync_icon(output_icns_path):
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Shadow for squircle
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

    # 2. Main Squircle Body (Gradient Simulation)
    squircle = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(squircle)
    
    # Draw vertical gradient
    for y in range(margin, size - margin):
        factor = (y - margin) / float(size - 2 * margin)
        # Deep Obsidian -> Rich Violet -> Indigo
        r = int(18 + factor * (90 - 18))
        g = int(12 + factor * (28 - 12))
        b = int(45 + factor * (165 - 45))
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
        outline=(255, 255, 255, 60),
        width=4
    )

    squircle.putalpha(mask)
    img.paste(squircle, (0, 0), squircle)
    img.paste(border, (0, 0), border)

    # 3. Floating 3D Keycap (Keyboard Symbolism)
    key_w, key_h = 340, 240
    key_x = (size - key_w) // 2
    key_y = 330

    # Keycap base shadow
    key_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ks_draw = ImageDraw.Draw(key_shadow)
    ks_draw.rounded_rectangle(
        [key_x, key_y + 15, key_x + key_w, key_y + key_h + 15],
        radius=40,
        fill=(0, 0, 0, 140)
    )
    key_shadow = key_shadow.filter(ImageFilter.GaussianBlur(16))
    img.paste(key_shadow, (0, 0), key_shadow)

    # Keycap body
    keycap = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    k_draw = ImageDraw.Draw(keycap)
    
    # Bevel bottom
    k_draw.rounded_rectangle(
        [key_x, key_y + 16, key_x + key_w, key_y + key_h + 16],
        radius=36,
        fill=(35, 15, 65, 255)
    )
    # Key top surface
    k_draw.rounded_rectangle(
        [key_x + 6, key_y + 6, key_x + key_w - 6, key_y + key_h - 6],
        radius=32,
        fill=(55, 25, 105, 255),
        outline=(168, 85, 247, 180),
        width=4
    )
    img.paste(keycap, (0, 0), keycap)

    # Keycap Inner Glow & Keyboard Icon
    icon_draw = ImageDraw.Draw(img)
    # Keyboard grid dots/keys inside keycap
    for row in range(3):
        for col in range(5):
            bx = key_x + 55 + col * 48
            by = key_y + 55 + row * 45
            bw = 36
            bh = 28
            if row == 2 and col in [1, 2, 3]: # spacebar
                if col == 1:
                    icon_draw.rounded_rectangle([bx, by, bx + 132, by + bh], radius=6, fill=(192, 132, 252, 220))
                continue
            icon_draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=6, fill=(168, 85, 247, 200))

    # 4. Gliding Neon Mouse Cursor & Light Trail
    # Light beam / glide wave
    trail = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(trail)
    t_draw.line([(280, 680), (740, 680)], fill=(0, 242, 254, 180), width=6)
    t_draw.line([(320, 680), (700, 680)], fill=(255, 255, 255, 240), width=3)
    trail = trail.filter(ImageFilter.GaussianBlur(4))
    img.paste(trail, (0, 0), trail)

    # Mouse cursor pointer
    cursor = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(cursor)
    
    # Cursor coordinate points
    cx, cy = 540, 580
    c_points = [
        (cx, cy),
        (cx, cy + 140),
        (cx + 42, cy + 106),
        (cx + 80, cy + 160),
        (cx + 104, cy + 144),
        (cx + 66, cy + 90),
        (cx + 120, cy + 90)
    ]
    # Cursor shadow
    c_shadow_pts = [(x + 8, y + 10) for x, y in c_points]
    c_draw.polygon(c_shadow_pts, fill=(0, 0, 0, 150))
    cursor = cursor.filter(ImageFilter.GaussianBlur(6))
    img.paste(cursor, (0, 0), cursor)

    # Actual Cursor
    fg_draw = ImageDraw.Draw(img)
    fg_draw.polygon(c_points, fill=(255, 255, 255, 255), outline=(0, 242, 254, 255))
    
    # Save master PNG
    iconset_dir = "/tmp/KeySync.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    master_png = "/tmp/keysync_master_1024.png"
    img.save(master_png)

    # Render standard icon resolutions
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

    # Compile with iconutil
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", output_icns_path], check=True)
    print(f"Generated {output_icns_path}")

if __name__ == "__main__":
    create_keysync_icon("KeySync/Resources/AppIcon.icns")
