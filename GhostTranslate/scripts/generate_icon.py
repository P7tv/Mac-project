#!/usr/bin/env python3
import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_ghost_icon(size=1024):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Outer squircle padding
    pad = int(size * 0.1)
    card_rect = [pad, pad, size - pad, size - pad]
    radius = int(size * 0.22)
    
    # Background gradient on card
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    
    # Rounded base squircle
    bg_draw.rounded_rectangle(card_rect, radius=radius, fill=(15, 20, 32, 255))
    
    # Diagonal subtle gradient overlay
    for i in range(pad, size - pad):
        factor = (i - pad) / (size - 2 * pad)
        r = int(12 + factor * 20)
        g = int(16 + factor * 30)
        b = int(28 + factor * 55)
        # horizontal slice tint
        bg_draw.line([(pad, i), (size - pad, i)], fill=(r, g, b, int(255 * 0.85)))
    
    # Squircle mask
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(card_rect, radius=radius, fill=255)
    
    # Composite card
    card_layer = Image.composite(bg, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask)
    image.paste(card_layer, (0, 0), card_layer)
    
    # Draw border glow
    border_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border_layer)
    b_draw.rounded_rectangle(card_rect, radius=radius, outline=(0, 230, 255, 160), width=int(size * 0.015))
    image.paste(border_layer, (0, 0), border_layer)
    
    # Center coordinates
    cx = size // 2
    cy = size // 2
    
    # Draw Ghost Body
    ghost_w = int(size * 0.38)
    ghost_h = int(size * 0.46)
    gx0 = cx - ghost_w // 2
    gy0 = cy - ghost_h // 2 - int(size * 0.02)
    gx1 = cx + ghost_w // 2
    gy1 = gy0 + ghost_h
    
    ghost_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(ghost_layer)
    
    # Dome head
    head_r = ghost_w // 2
    g_draw.pieslice([gx0, gy0, gx1, gy0 + ghost_w], 180, 360, fill=(240, 250, 255, 230))
    # Body rectangle
    g_draw.rectangle([gx0, gy0 + head_r, gx1, gy1 - int(ghost_w * 0.2)], fill=(240, 250, 255, 230))
    
    # Ghost wavy bottom feet (3 scallops)
    scallop_w = ghost_w / 3.0
    for s in range(3):
        sx0 = gx0 + s * scallop_w
        sx1 = sx0 + scallop_w
        sy0 = gy1 - int(ghost_w * 0.25)
        sy1 = gy1
        g_draw.ellipse([sx0, sy0, sx1, sy1], fill=(240, 250, 255, 230))
        
    # Ghost Eyes (large cute friendly eyes looking slightly up/right)
    eye_r = int(ghost_w * 0.11)
    eye_y = gy0 + int(ghost_h * 0.32)
    left_eye_x = cx - int(ghost_w * 0.22)
    right_eye_x = cx + int(ghost_w * 0.14)
    
    g_draw.ellipse([left_eye_x, eye_y, left_eye_x + eye_r * 2, eye_y + eye_r * 2], fill=(16, 24, 40, 255))
    g_draw.ellipse([right_eye_x, eye_y, right_eye_x + eye_r * 2, eye_y + eye_r * 2], fill=(16, 24, 40, 255))
    
    # Eye highlights
    hl_r = int(eye_r * 0.35)
    g_draw.ellipse([left_eye_x + int(eye_r * 0.8), eye_y + int(eye_r * 0.3),
                    left_eye_x + int(eye_r * 0.8) + hl_r * 2, eye_y + int(eye_r * 0.3) + hl_r * 2],
                   fill=(255, 255, 255, 255))
    g_draw.ellipse([right_eye_x + int(eye_r * 0.8), eye_y + int(eye_r * 0.3),
                    right_eye_x + int(eye_r * 0.8) + hl_r * 2, eye_y + int(eye_r * 0.3) + hl_r * 2],
                   fill=(255, 255, 255, 255))
    
    # Translation sound waves (arcs on left and right)
    for r_offset in [int(size * 0.26), int(size * 0.32)]:
        # Left wave
        g_draw.arc([cx - r_offset, cy - r_offset - int(size * 0.02),
                    cx + r_offset, cy + r_offset - int(size * 0.02)],
                   135, 225, fill=(0, 230, 255, 180), width=int(size * 0.015))
        # Right wave
        g_draw.arc([cx - r_offset, cy - r_offset - int(size * 0.02),
                    cx + r_offset, cy + r_offset - int(size * 0.02)],
                   -45, 45, fill=(0, 230, 255, 180), width=int(size * 0.015))
                   
    # Composite ghost with soft shadow
    shadow = ghost_layer.filter(ImageFilter.GaussianBlur(int(size * 0.03)))
    image.paste(shadow, (0, int(size * 0.02)), shadow)
    image.paste(ghost_layer, (0, 0), ghost_layer)
    
    return image

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    res_dir = os.path.join(project_dir, "Resources")
    os.makedirs(res_dir, exist_ok=True)
    
    iconset_dir = os.path.join(res_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    base_image = create_ghost_icon(1024)
    
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]
    
    for s, name in sizes:
        resized = base_image.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))
        
    icns_path = os.path.join(res_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"Generated AppIcon.icns at: {icns_path}")

if __name__ == "__main__":
    main()
