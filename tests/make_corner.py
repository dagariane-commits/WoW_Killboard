from PIL import Image, ImageDraw
import numpy as np

def make_clean_corner():
    # Render at 4x (256x256) and supersample down to 64x64 for crisp, clean antialiased edges
    high = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(high)

    # Base polygon for L-bracket
    # Arm length: 96px at 4x (24px at 1x)
    # Arm thickness: 28px at 4x (7px at 1x)
    # Corner chamfer: 16px at 4x (4px at 1x)
    poly = [(16, 0), (96, 0), (96, 26), (26, 26), (26, 96), (0, 96), (0, 16)]

    # Draw outer border / dark bronze frame
    hdraw.polygon(poly, fill=(35, 24, 8, 255))

    # Inset body with antique bronze/gold tone
    inset_poly = [(18, 3), (94, 3), (94, 24), (24, 24), (24, 94), (3, 94), (3, 18)]
    hdraw.polygon(inset_poly, fill=(185, 142, 48, 255))

    # Outer highlights (metallic shine)
    hdraw.line([(18, 3), (94, 3)], fill=(255, 235, 145, 255), width=2)
    hdraw.line([(3, 18), (3, 94)], fill=(255, 235, 145, 255), width=2)
    hdraw.line([(3, 18), (18, 3)], fill=(255, 248, 195, 255), width=3)

    # Inner bevel shadow
    hdraw.line([(24, 24), (94, 24)], fill=(85, 60, 15, 255), width=2)
    hdraw.line([(24, 24), (24, 94)], fill=(85, 60, 15, 255), width=2)

    # Circular rivet/stud at (36, 36) (9px at 1x)
    rx, ry, rr = 36, 36, 10
    hdraw.ellipse([rx-rr, ry-rr, rx+rr, ry+rr], fill=(45, 30, 10, 255))
    hdraw.ellipse([rx-rr+2, ry-rr+2, rx+rr-2, ry+rr-2], fill=(225, 180, 70, 255))
    hdraw.ellipse([rx-rr+4, ry-rr+4, rx-rr+7, ry-rr+7], fill=(255, 255, 230, 255))

    # Downsample with Lanczos
    corner = high.resize((64, 64), Image.Resampling.LANCZOS)
    corner.save('Addon/WoWKillboard/Textures/corner_bracket.tga')
    corner.save('tests/clean_corner.png')
    print('Generated clean corner_bracket.tga with 100% transparent background.')

if __name__ == '__main__':
    make_clean_corner()
