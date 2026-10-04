from PIL import Image, ImageDraw

def generate_clean_crests():
    # 1. Alliance Crest from sample_crop.png
    crop = Image.open('tests/sample_crop.png').convert('RGBA')
    cx, cy, r = 74.0, 76.0, 60.0
    
    scale = 4
    w, h = crop.size
    mask = Image.new('L', (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([
        (cx - r) * scale,
        (cy - r) * scale,
        (cx + r) * scale,
        (cy + r) * scale
    ], fill=255)
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)
    crop.putalpha(mask)
    
    bbox = (int(cx - r), int(cy - r), int(cx + r + 1), int(cy + r + 1))
    circle_img = crop.crop(bbox)
    
    # 128x128 RGBA TGA (power-of-2 required by WoW client)
    alliance_tga = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    # Fill 124x124 so it touches edges cleanly with 2px transparent border
    resized = circle_img.resize((124, 124), Image.Resampling.LANCZOS)
    alliance_tga.paste(resized, (2, 2), resized)
    alliance_tga.save('Addon/WoWKillboard/Textures/crest_alliance.tga')
    alliance_tga.save('tests/crest_alliance_perfect.png')
    print('Generated clean crest_alliance.tga')

    # 2. Horde Crest from card_horde_square.png
    horde_src = Image.open(r'web\static\images\card_horde_square.png').convert('RGBA')
    hcx, hcy, hr = 512.0, 512.0, 310.0
    
    hw, hh = horde_src.size
    hmask = Image.new('L', (hw * scale, hh * scale), 0)
    hdraw = ImageDraw.Draw(hmask)
    hdraw.ellipse([
        (hcx - hr) * scale,
        (hcy - hr) * scale,
        (hcx + hr) * scale,
        (hcy + hr) * scale
    ], fill=255)
    hmask = hmask.resize((hw, hh), Image.Resampling.LANCZOS)
    horde_src.putalpha(hmask)
    
    hbbox = (int(hcx - hr), int(hcy - hr), int(hcx + hr + 1), int(hcy + hr + 1))
    hcircle = horde_src.crop(hbbox)
    
    horde_tga = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    hresized = hcircle.resize((124, 124), Image.Resampling.LANCZOS)
    horde_tga.paste(hresized, (2, 2), hresized)
    horde_tga.save('Addon/WoWKillboard/Textures/crest_horde.tga')
    horde_tga.save('tests/crest_horde_perfect.png')
    print('Generated clean crest_horde.tga')

if __name__ == '__main__':
    generate_clean_crests()
