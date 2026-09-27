#!/usr/bin/env python3
"""
Generate WoW-compatible TGA textures for WoWKillboard:
1. dark_war_bg.tga (1024x512): The dark atmospheric war room battlefield from the website.
2. medallion_border.tga (128x128): Mathematically centered antique gold circular medallion ring.
"""

import os
import math
from PIL import Image, ImageDraw

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(BASE_DIR, "Addon", "WoWKillboard", "Textures")
os.makedirs(TEX_DIR, exist_ok=True)

def generate_dark_war_bg():
    src = os.path.join(BASE_DIR, "web", "static", "images", "dark_war_bg.jpg")
    dst = os.path.join(TEX_DIR, "dark_war_bg.tga")
    if os.path.exists(src):
        im = Image.open(src).convert("RGB")
        im_resized = im.resize((1024, 512), Image.Resampling.LANCZOS)
        im_resized.save(dst, format="TGA")
        print(f"[TEXTURE] Successfully created: {dst} ({os.path.getsize(dst)} bytes)")
    else:
        print(f"[ERROR] Source not found: {src}")

def generate_medallion_border():
    dst = os.path.join(TEX_DIR, "medallion_border.tga")
    size = 128
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    cx, cy = size / 2.0, size / 2.0
    r_outer = 60.0
    r_inner = 46.0

    # Draw smooth anti-aliased concentric metallic gold ring
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy)

            if r_inner - 1.5 <= dist <= r_outer + 1.5:
                # Anti-aliasing alpha
                alpha = 1.0
                if dist > r_outer:
                    alpha = max(0.0, 1.0 - (dist - r_outer) / 1.5)
                elif dist < r_inner:
                    alpha = max(0.0, (dist - (r_inner - 1.5)) / 1.5)

                # Shading angle (light source at top-left: -45 deg)
                angle = math.atan2(dy, dx)
                light = math.cos(angle - (-math.pi * 0.75)) # light from top-left

                # Base metallic gold: R: 212, G: 163, B: 41 (#d4a329)
                # Outer bevel and inner bevel
                t = (dist - r_inner) / (r_outer - r_inner) # 0.0 at inner, 1.0 at outer
                bevel = math.sin(t * math.pi) # 1.0 at ridge center

                base_r = 185 + int(50 * light + 20 * bevel)
                base_g = 140 + int(45 * light + 15 * bevel)
                base_b = 35 + int(30 * light + 10 * bevel)

                base_r = min(255, max(40, base_r))
                base_g = min(230, max(30, base_g))
                base_b = min(180, max(10, base_b))

                # Rivets / notches at 4 cardinal and 4 ordinal points
                for rot in [0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi, -math.pi/4, -math.pi/2, -3*math.pi/4]:
                    diff = abs(angle - rot)
                    if diff < 0.06 and 51 <= dist <= 55:
                        base_r = min(255, base_r + 40)
                        base_g = min(255, base_g + 30)

                im.putpixel((x, y), (base_r, base_g, base_b, int(alpha * 255)))

    im.save(dst, format="TGA")
    print(f"[TEXTURE] Successfully created: {dst} ({os.path.getsize(dst)} bytes)")

def generate_classic_parchment_bg():
    """Generate high-resolution authentic aged parchment texture for Classic WoW quest log look."""
    dst = os.path.join(TEX_DIR, "classic_parchment_bg.tga")
    width, height = 1024, 512
    im = Image.new("RGB", (width, height), (225, 202, 155))
    draw = ImageDraw.Draw(im)

    # Procedural antique parchment synthesis: noise + fibers + vignette
    import random
    random.seed(1337) # Deterministic grain

    pixels = im.load()
    cx, cy = width / 2.0, height / 2.0

    for y in range(height):
        # Vertical gradient (slightly lighter at top, deeper warm amber at bottom)
        y_ratio = y / height
        base_lum = -10 + int(y_ratio * 12)

        for x in range(width):
            # Distance from center for vignette
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            vignette = (dx * dx + dy * dy) * 0.45

            # Fiber noise
            grain = random.randint(-8, 8)
            fiber_h = int(math.sin(x * 0.15) * 3)
            fiber_v = int(math.sin(y * 0.25) * 3)

            r = 228 + base_lum + grain + fiber_h - int(vignette * 45)
            g = 205 + base_lum + grain + fiber_v - int(vignette * 50)
            b = 158 + base_lum + grain - int(vignette * 55)

            # Clamp RGB bounds
            r = min(245, max(140, r))
            g = min(225, max(115, g))
            b = min(185, max(75, b))

            pixels[x, y] = (r, g, b)

    # Subtle inner parchment border line
    border_color = (155, 125, 75)
    draw.rectangle([8, 8, width - 9, height - 9], outline=border_color, width=2)
    draw.rectangle([14, 14, width - 15, height - 15], outline=(185, 155, 105), width=1)

    im.save(dst, format="TGA")
    print(f"[TEXTURE] Successfully created: {dst} ({os.path.getsize(dst)} bytes)")

if __name__ == "__main__":
    generate_dark_war_bg()
    generate_medallion_border()
    generate_classic_parchment_bg()
