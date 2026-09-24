import glob
import sys
import re

def check_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()
    clean_lines = []
    in_block_comment = False
    for line in lines:
        if in_block_comment:
            if "]]" in line:
                in_block_comment = False
                line = line.split("]]", 1)[1]
            else:
                clean_lines.append("")
                continue
        while "--[[" in line:
            parts = line.split("--[[", 1)
            if "]]" in parts[1]:
                line = parts[0] + parts[1].split("]]", 1)[1]
            else:
                line = parts[0]
                in_block_comment = True
                break
        if "--" in line:
            line = line.split("--")[0]
        clean_lines.append(line)

    text = "\n".join(clean_lines)

    clean_tokens = []
    in_str = None
    i = 0
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\" and i + 1 < len(text):
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in ('"', "'"):
            in_str = c
            i += 1
            continue
        clean_tokens.append(c)
        i += 1

    clean_text = "".join(clean_tokens)
    
    # 1. Balanced brackets, parens, braces
    p_stack = []
    for idx, c in enumerate(clean_text):
        if c in "({[":
            p_stack.append((c, idx))
        elif c in ")}]":
            if not p_stack:
                print(f"[FAIL] {filepath}: Unmatched closing {c} at pos {idx}")
                return False
            top, _ = p_stack.pop()
            if (top == "(" and c != ")") or (top == "{" and c != "}") or (top == "[" and c != "]"):
                print(f"[FAIL] {filepath}: Mismatched {top} and {c}")
                return False

    if p_stack:
        top, idx = p_stack[-1]
        print(f"[FAIL] {filepath}: Unclosed {top} at pos {idx}")
        return False

    # 2. Balanced keywords
    tokens = re.findall(r"\b(?:function|if|then|elseif|else|while|for|do|repeat|until|end)\b", clean_text)
    kw_stack = []
    for t in tokens:
        if t in ("function", "while", "for", "repeat"):
            kw_stack.append(t)
        elif t == "if":
            kw_stack.append("if")
        elif t == "do":
            if kw_stack and kw_stack[-1] in ("while", "for"):
                # "while ... do" or "for ... do" share the same 'end'
                pass
            else:
                kw_stack.append("do")
        elif t in ("then", "elseif", "else"):
            # internal to 'if'
            pass
        elif t == "until":
            if not kw_stack or kw_stack[-1] != "repeat":
                print(f"[FAIL] {filepath}: Unexpected until")
                return False
            kw_stack.pop()
        elif t == "end":
            if not kw_stack:
                print(f"[FAIL] {filepath}: Unexpected end")
                return False
            kw_stack.pop()

    if kw_stack:
        print(f"[FAIL] {filepath}: Unclosed blocks: {kw_stack}")
        return False

    print(f"[PASS] {filepath}")
    return True

all_ok = True
files = glob.glob("c:/Users/SQUICK/WoW_Killboard/Addon/WoWKillboard/*.lua")
for f in files:
    if not check_file(f):
        all_ok = False

if all_ok:
    print(f"\nAll {len(files)} Lua files PASSED syntax structure validation.")
sys.exit(0 if all_ok else 1)
