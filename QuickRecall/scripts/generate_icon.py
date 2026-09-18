import os
import subprocess
import math
from PIL import Image, ImageDraw, ImageFilter

def create_quickrecall_icon(output_icns_path):
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

    # 2. Main Squircle Body (Deep Obsidian Amber Gradient)
    squircle = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(squircle)
    
    for y in range(margin, size - margin):
        factor = (y - margin) / float(size - 2 * margin)
        # Deep space dark (#140c04) to rich warm amber (#3d2208)
        r = int(20 + factor * (65 - 20))
        g = int(12 + factor * (38 - 12))
        b = int(4 + factor * (12 - 4))
        sq_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new("L", (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        fill=255
    )

    # Border stroke with frosted gold glass rim
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    b_draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner,
        outline=(255, 215, 0, 75),
        width=4
    )

    squircle.putalpha(mask)
    img.paste(squircle, (0, 0), squircle)
    img.paste(border, (0, 0), border)

    # 3. Ambient Amber/Gold Radial Glow in center
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    center_x, center_y = size // 2, size // 2 - 10
    for radius in range(270, 40, -15):
        alpha = int((1.0 - (radius / 270.0)) * 80)
        g_draw.ellipse(
            [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
            fill=(255, 179, 0, alpha)
        )
    glow = glow.filter(ImageFilter.GaussianBlur(30))
    img.paste(glow, (0, 0), glow)

    # 4. Chrono-Recall Sweep Arc (Circular Memory Timeline)
    timeline = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(timeline)
    r_sweep = 210
    t_draw.arc(
        [center_x - r_sweep, center_y - r_sweep, center_x + r_sweep, center_y + r_sweep],
        start=40,
        end=320,
        fill=(255, 145, 0, 190),
        width=6
    )
    # Arrow head for recall time loop
    t_draw.polygon(
        [(center_x + r_sweep - 8, center_y - 20),
         (center_x + r_sweep + 24, center_y + 10),
         (center_x + r_sweep - 4, center_y + 36)],
        fill=(255, 215, 0, 240)
    )
    timeline = timeline.filter(ImageFilter.GaussianBlur(2))
    img.paste(timeline, (0, 0), timeline)

    # 5. Neural Lens / Magnifier (Visual Search & Recall)
    lens_r = 145
    lens_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ls_draw = ImageDraw.Draw(lens_shadow)
    ls_draw.ellipse(
        [center_x - lens_r, center_y - lens_r + 14, center_x + lens_r, center_y + lens_r + 14],
        fill=(0, 0, 0, 150)
    )
    lens_shadow = lens_shadow.filter(ImageFilter.GaussianBlur(14))
    img.paste(lens_shadow, (0, 0), lens_shadow)

    lens = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    l_draw = ImageDraw.Draw(lens)

    # Lens Outer Golden Bezel
    l_draw.ellipse(
        [center_x - lens_r, center_y - lens_r, center_x + lens_r, center_y + lens_r],
        fill=(40, 22, 6, 240),
        outline=(255, 215, 0, 255),
        width=8
    )

    # Lens Inner Glass
    inner_r = lens_r - 18
    l_draw.ellipse(
        [center_x - inner_r, center_y - inner_r, center_x + inner_r, center_y + inner_r],
        fill=(22, 12, 4, 220),
        outline=(255, 179, 0, 140),
        width=3
    )

    # Glass highlight reflection (Crescent arc)
    l_draw.arc(
        [center_x - inner_r + 10, center_y - inner_r + 10, center_x + inner_r - 10, center_y + inner_r - 10],
        start=200,
        end=290,
        fill=(255, 255, 255, 200),
        width=5
    )
    img.paste(lens, (0, 0), lens)

    # 6. OCR Text Glyphs & Laser Scanner Beam
    ocr = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    o_draw = ImageDraw.Draw(ocr)

    # Scanning Laser Beam (Horizontal neon coral / amber ray)
    beam_y = center_y
    o_draw.line(
        [(center_x - inner_r + 5, beam_y), (center_x + inner_r - 5, beam_y)],
        fill=(255, 82, 82, 240),
        width=5
    )
    o_draw.line(
        [(center_x - inner_r + 20, beam_y), (center_x + inner_r - 20, beam_y)],
        fill=(255, 255, 255, 250),
        width=2
    )

    # Optical Scanlines above and below beam
    for y_off in [-50, -25, 25, 50]:
        sy = center_y + y_off
        w_off = abs(y_off) * 0.8
        o_draw.line(
            [(center_x - inner_r + 30 + w_off, sy), (center_x + inner_r - 30 - w_off, sy)],
            fill=(255, 179, 0, 100),
            width=2
        )

    # Magnifier Handle (Bottom-Right)
    handle_len = 90
    hx1 = center_x + int(lens_r * 0.707)
    hy1 = center_y + int(lens_r * 0.707)
    hx2 = hx1 + int(handle_len * 0.707)
    hy2 = hy1 + int(handle_len * 0.707)
    o_draw.line([(hx1, hy1), (hx2, hy2)], fill=(255, 215, 0, 255), width=18)
    o_draw.line([(hx1 + 2, hy1 + 2), (hx2 - 2, hy2 - 2)], fill=(255, 255, 255, 230), width=6)

    # Neural Search Symbol inside lens (Search / Brain Glyphs)
    # Central target crosshair
    cr_len = 16
    o_draw.line([(center_x - cr_len, center_y), (center_x + cr_len, center_y)], fill=(255, 255, 255, 240), width=3)
    o_draw.line([(center_x, center_y - cr_len), (center_x, center_y + cr_len)], fill=(255, 255, 255, 240), width=3)

    img.paste(ocr, (0, 0), ocr)

    # 7. Multi-resolution generation with iconutil
    iconset_dir = "/tmp/QuickRecall.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    master_png = "/tmp/quickrecall_master_1024.png"
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
    create_quickrecall_icon("QuickRecall/Resources/AppIcon.icns")
