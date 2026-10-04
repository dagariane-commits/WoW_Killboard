import glob
import sys
import re

def check_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    clean_tokens = []
    in_str = None
    in_block_comment = False
    i = 0
    while i < len(content):
        c = content[i]
        if in_block_comment:
            if content[i:i+2] == "]]":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\" and i + 1 < len(content):
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if content[i:i+4] == "--[[":
            in_block_comment = True
            i += 4
            continue
        if content[i:i+2] == "--":
            nl_pos = content.find("\n", i)
            if nl_pos == -1:
                break
            i = nl_pos
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

    # 3. Standalone expression tuple check: commas inside parentheses that are not function calls/defs
    expr_p_stack = []
    for idx, c in enumerate(clean_text):
        if c == "(":
            pre = clean_text[max(0, idx-50):idx].rstrip()
            m = re.search(r"([a-zA-Z_0-9]+|[^\s])$", pre)
            is_call = False
            if m:
                tok = m.group(1)
                keywords = {"or", "and", "not", "return", "in", "if", "while", "until", "then", "do", "else", "elseif", "repeat"}
                if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*$", tok) and tok not in keywords:
                    is_call = True
                elif tok in ("]", ")"):
                    is_call = True
            expr_p_stack.append({"is_call": is_call, "pos": idx})
        elif c in ("{", "["):
            expr_p_stack.append({"is_call": True, "pos": idx})
        elif c == ",":
            if expr_p_stack and not expr_p_stack[-1]["is_call"]:
                line_no = clean_text[:idx].count("\n") + 1
                snippet = clean_text[max(0, idx-30):min(len(clean_text), idx+30)].replace("\n", " ").strip()
                print(f"[FAIL] {filepath}:{line_no}: Invalid comma in parenthesized expression: ')' expected near ',' -> ...{snippet}...")
                return False
        elif c in (")", "}", "]"):
            if expr_p_stack:
                expr_p_stack.pop()

    print(f"[PASS] {filepath}")
    return True

import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
all_ok = True
files = sorted(glob.glob(os.path.join(BASE_DIR, "Addon", "WoWKillboard", "*.lua")))
for f in files:
    if not check_file(f):
        all_ok = False

if all_ok:
    print(f"\nAll {len(files)} Lua files PASSED syntax structure validation.")
sys.exit(0 if all_ok else 1)
