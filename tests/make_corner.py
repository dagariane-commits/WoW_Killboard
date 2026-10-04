from PIL import Image, ImageDraw
import numpy as np

def make_corner_bracket():
    src = Image.open(r'C:\Users\SQUICK\.gemini\antigravity\brain\7c9d8aaf-239e-448b-9ff9-09f42711f2f6\classic_death_toast_scaled_1791083337160.jpg').convert('RGBA')
    # The corner bracket in mockup:
    # Let's crop (45, 270, 95, 320)
    crop = src.crop((45, 270, 95, 320))
    # In this 50x50 crop, the outer frame edge starts at x=5, y=5.
    # Outside the frame (x < 5 or y < 5) is dark background.
    # Let's find the mask where it's part of the frame:
    w, h = crop.size
    arr = np.array(crop)
    # The frame corner: outer corner bevel is at (4, 4) with chamfer
    # Let's create an alpha mask for the outer corner
    mask = Image.new('L', (w, h), 255)
    draw = ImageDraw.Draw(mask)
    # Chamfer outer top-left corner
    # Outside x < 4 or y < 4 or (x+y < 12)
    for y in range(h):
        for x in range(w):
            if x < 4 or y < 4 or (x + y < 14):
                mask.putpixel((x, y), 0)
    
    crop.putalpha(mask)
    
    # Place on 64x64 TGA
    tga = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    tga.paste(crop, (0, 0), crop)
    tga.save('Addon/WoWKillboard/Textures/corner_bracket.tga')
    tga.save('tests/corner_bracket_preview.png')
    print('Saved corner_bracket.tga and preview.png')

if __name__ == '__main__':
    make_corner_bracket()
