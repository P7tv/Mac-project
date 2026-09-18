import os
import subprocess
import math
from PIL import Image, ImageDraw, ImageFilter

def create_airbridge_icon(output_icns_path):
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # 1. Ambient Drop Shadow for macOS squircle
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    margin = 110
    corner = 190
    s_draw.rounded_rectangle(
        [margin, margin + 25, size - margin, size - margin + 25],
        radius=corner,
        fill=(0, 0, 0, 165)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    img.paste(shadow, (0, 0), shadow)

    # 2. Main Squircle Body (Deep Obsidian -> Rich Emerald/Cyan Gradient)
    squircle = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(squircle)
    
    for y in range(margin, size - margin):
        factor = (y - margin) / float(size - 2 * margin)
        # Deep obsidian teal (#051814) to electric mint/cyan (#0a362e)
        r = int(5 + factor * (12 - 5))
        g = int(24 + factor * (58 - 24))
        b = int(20 + factor * (52 - 20))
        sq_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new("L", (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        fill=255
    )

    # Border stroke with frosted glass rim
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    b_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        outline=(255, 255, 255, 70),
        width=4
    )

    squircle.putalpha(mask)
    img.paste(squircle, (0, 0), squircle)
    img.paste(border, (0, 0), border)

    # 3. Ambient Emerald/Cyan Radial Glow in center
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    center_x, center_y = size // 2, size // 2 - 10
    for radius in range(260, 40, -15):
        alpha = int((1.0 - (radius / 260.0)) * 75)
        g_draw.ellipse(
            [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
            fill=(0, 242, 254, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    img.paste(glow, (0, 0), glow)

    # 4. Floating Glassmorphic Clipboard Base
    clip_w, clip_h = 320, 390
    clip_x = (size - clip_w) // 2
    clip_y = center_y - 140

    # Clipboard shadow
    clip_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(clip_shadow)
    cs_draw.rounded_rectangle(
        [clip_x, clip_y + 18, clip_x + clip_w, clip_y + clip_h + 18],
        radius=36,
        fill=(0, 0, 0, 150)
    )
    clip_shadow = clip_shadow.filter(ImageFilter.GaussianBlur(16))
    img.paste(clip_shadow, (0, 0), clip_shadow)

    # Clipboard card
    clipboard = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(clipboard)
    c_draw.rounded_rectangle(
        [clip_x, clip_y, clip_x + clip_w, clip_y + clip_h],
        radius=32,
        fill=(14, 38, 35, 245),
        outline=(16, 185, 129, 200),
        width=4
    )
    # Clipboard clip top
    c_draw.rounded_rectangle(
        [center_x - 60, clip_y - 18, center_x + 60, clip_y + 22],
        radius=12,
        fill=(20, 60, 52, 255),
        outline=(0, 242, 254, 255),
        width=3
    )
    img.paste(clipboard, (0, 0), clipboard)

    # 5. Glowing Digital Transmission Arcs (Wireless Air Bridge)
    arcs = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    a_draw = ImageDraw.Draw(arcs)

    # Pulse arcs connecting left and right
    radii = [90, 140, 190]
    for r in radii:
        a_draw.arc(
            [center_x - r, center_y + 40 - r, center_x + r, center_y + 40 + r],
            start=200,
            end=340,
            fill=(0, 242, 254, 210),
            width=6
        )
        a_draw.arc(
            [center_x - r + 4, center_y + 40 - r + 4, center_x + r - 4, center_y + 40 + r - 4],
            start=205,
            end=335,
            fill=(255, 255, 255, 180),
            width=2
        )
    arcs = arcs.filter(ImageFilter.GaussianBlur(2))
    img.paste(arcs, (0, 0), arcs)

    # 6. Center Bridge Beam & Digital Sync Arrows
    beam = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(beam)

    # Horizontal Bridge Runway
    rw_y = center_y + 60
    b_draw.rounded_rectangle(
        [center_x - 170, rw_y, center_x + 170, rw_y + 16],
        radius=8,
        fill=(16, 185, 129, 220)
    )
    b_draw.rounded_rectangle(
        [center_x - 150, rw_y + 3, center_x + 150, rw_y + 13],
        radius=5,
        fill=(255, 255, 255, 240)
    )

    # Dual Nodes (Mac Node on Left, Phone/PC Node on Right)
    b_draw.ellipse([center_x - 185, rw_y - 12, center_x - 145, rw_y + 28], fill=(0, 242, 254, 255), outline=(255, 255, 255, 240), width=3)
    b_draw.ellipse([center_x + 145, rw_y - 12, center_x + 185, rw_y + 28], fill=(16, 185, 129, 255), outline=(255, 255, 255, 240), width=3)

    # Upward Air Wave Arrows inside Clipboard
    for i, offset in enumerate([-50, 0, 50]):
        ay = center_y - 65
        ax = center_x + offset
        # Document text line
        b_draw.rounded_rectangle([center_x - 90, center_y - 60 + i * 32, center_x + 90, center_y - 50 + i * 32], radius=5, fill=(0, 242, 254, 180))

    img.paste(beam, (0, 0), beam)

    # 7. Multi-resolution generation with iconutil
    iconset_dir = "/tmp/AirBridge.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    master_png = "/tmp/airbridge_master_1024.png"
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
    create_airbridge_icon("AirBridge/Resources/AppIcon.icns")
