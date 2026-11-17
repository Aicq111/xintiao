# -*- coding: utf-8 -*-
"""把 pbxproj 中非十六进制的对象 ID（G/H/I/J/K/L 前缀）替换为合法十六进制 ID。"""
import re, io, sys
sys.stdout.reconfigure(encoding='utf-8')

fp = r'D:\deepseek工作区\薪跳App\ios\Runner.xcodeproj\project.pbxproj'
src = io.open(fp, 'r', encoding='utf-8').read()

prefixes = {'G': 'AB', 'H': 'AC', 'I': 'AD', 'J': 'AE', 'K': 'AF', 'L': 'B0'}
tokens = sorted(set(re.findall(r'[GHIJKL][0-9A-F]{23}', src)))
print('tokens to fix:', len(tokens))

for t in tokens:
    # 新 ID = 新前缀(2 位) + 原 ID 去掉首字母后的 22 位 = 24 位
    new = prefixes[t[0]] + t[2:]
    assert len(new) == 24, (t, new, len(new))
    assert all(c in '0123456789ABCDEF' for c in new), new
    src = src.replace(t, new)
    print(f'{t} -> {new}')

# 校验：不应再有任何含 G-Z 的 24 位 token
bad = re.findall(r'[0-9A-Z]{24}', src)
invalid = [b for b in bad if any(c in 'GHIJKLMNOPQRSTUVWXYZ' for c in b)]
print('remaining invalid:', invalid)

io.open(fp, 'w', encoding='utf-8', newline='\n').write(src)
print('written, len:', len(src))
