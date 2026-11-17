# -*- coding: utf-8 -*-
"""检查 Dart 文件的括号配平（跳过字符串与注释），辅助发现手写代码的低级语法错误。"""
import sys, re, io, os

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def strip_tokens(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        # 行注释
        if c == '/' and i + 1 < n and src[i+1] == '/':
            while i < n and src[i] != '\n': i += 1
            continue
        # 块注释
        if c == '/' and i + 1 < n and src[i+1] == '*':
            i += 2
            while i + 1 < n and not (src[i] == '*' and src[i+1] == '/'): i += 1
            i += 2
            continue
        # 字符串：单/双/三引号，支持 r 前缀与反斜杠转义
        if c == 'r' and i + 1 < n and src[i+1] in "'\"":
            q = src[i+1]
            triple = i + 3 < n and src[i+2] == q and src[i+3] == q
            i += 2
            if triple:
                i += 2
                while i + 2 < n and not (src[i] == q and src[i+1] == q and src[i+2] == q): i += 1
                i += 3
            else:
                i += 1
                while i < n and src[i] != q: i += 1
                i += 1
            continue
        if c in "'\"":
            q = c
            triple = i + 2 < n and src[i+1] == q and src[i+2] == q
            i += 1
            if triple:
                i += 2
                while i + 2 < n and not (src[i] == q and src[i+1] == q and src[i+2] == q): i += 1
                i += 3
            else:
                while i < n and src[i] != q:
                    if src[i] == '\\': i += 2
                    else: i += 1
                i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)

pairs = {'(': ')', '{': '}', '[': ']'}
ok = True
files = []
for dirpath, _, names in os.walk(os.path.join(ROOT, 'lib')):
    for nm in names:
        if nm.endswith('.dart'):
            files.append(os.path.join(dirpath, nm))
files.append(os.path.join(ROOT, 'test', 'engine_test.dart'))
files.sort()

for fp in files:
    with io.open(fp, 'r', encoding='utf-8') as f:
        src = f.read()
    body = strip_tokens(src)
    stack = []
    line = 1
    errs = []
    # 用逐行计数定位错误行：直接统计即可，行号用原始源码重建
    counts = {'(': 0, ')': 0, '{': 0, '}': 0, '[': 0, ']': 0}
    for ch in body:
        if ch in counts:
            counts[ch] += 1
    bad = []
    for a, b in pairs.items():
        if counts[a] != counts[b]:
            bad.append(f'{a}{b} 不配对 ({counts[a]} vs {counts[b]})')
    # 顺序检查（近似，用栈）
    stack = []
    for ch in body:
        if ch in '({[':
            stack.append(ch)
        elif ch in ')}]':
            if not stack or pairs.get(stack[-1]) != ch:
                bad.append(f'顺序错误: 遇到 {ch} 但栈顶是 {stack[-1] if stack else "空"}')
                break
            stack.pop()
    rel = os.path.relpath(fp, ROOT)
    if bad:
        ok = False
        print(f'[X] {rel}: ' + '; '.join(bad))
    else:
        print(f'[OK] {rel}: 括号配平')

print('\n结果:', '全部通过' if ok else '存在问题')
sys.exit(0 if ok else 1)
