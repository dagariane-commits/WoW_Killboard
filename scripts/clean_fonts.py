import os

addon_dir = "Addon/WoWKillboard"

# Map codepoints directly to clean ASCII replacements
reps = {
    0x2694: "",         # crossed swords
    0xFE0F: "",         # variation selector
    0x1F4EF: "",        # postal horn
    0x1F4E2: "[Share]", # loudspeaker
    0x1F441: "",        # eye
    0x1F4CD: "",        # round pushpin
    0x1F4B0: "[Gold]",  # money bag
    0x1F3C6: "[Top]",   # trophy
    0x1F4DC: "[Cases]", # scroll
    0x23F3: "[Timer]",  # hourglass
    0x26D3: "",         # chains
    0x1F4BE: "[Save]",  # floppy disk
    0x2699: "[Settings]",# gear
    0x1F41E: "[Bug]",   # bug
    0x1F6A8: "[!]",     # siren
    0x2605: "*",        # star
    0x2713: "[OK]",     # checkmark
    0x2192: "->",       # right arrow
    0x1F6E1: "[Tank]",  # shield
    0x1F49A: "[Healer]",# green heart
    0x2014: " - ",      # em dash
    0x2022: " | ",      # bullet
    0x25CF: "*",        # black circle
}

for fname in os.listdir(addon_dir):
    if not fname.endswith(".lua"):
        continue
    path = os.path.join(addon_dir, fname)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    modified = []
    for char in content:
        code = ord(char)
        if code in reps:
            modified.append(reps[code])
        elif code > 127:
            print(f"[UNKNOWN NON-ASCII] {fname}: U+{code:04X} ({repr(char)})")
            modified.append("")
        else:
            modified.append(char)

    new_content = "".join(modified)
    if new_content != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"[CLEANED] Successfully sanitized {path}")

# Verify
total_non_ascii = 0
for fname in os.listdir(addon_dir):
    if not fname.endswith(".lua"):
        continue
    path = os.path.join(addon_dir, fname)
    with open(path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f):
            for c in line:
                if ord(c) > 127:
                    total_non_ascii += 1
                    print(f"[STILL NON-ASCII] {fname}:{i+1}: U+{ord(c):04X}")

print(f"Total remaining non-ASCII across all Addon Lua files: {total_non_ascii}")
