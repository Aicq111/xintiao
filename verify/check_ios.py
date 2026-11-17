# -*- coding: utf-8 -*-
"""iOS 工程静态校验：XML 合法性 + pbxproj UUID 引用一致性 + 结构完整性。"""
import sys, re, os
from xml.dom import minidom

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(ROOT, 'ios')

ok = True

def fail(msg):
    global ok
    ok = False
    print('[X]', msg)

# ---------- 1. XML 文件合法性 ----------
xml_files = []
for dirpath, _, names in os.walk(IOS):
    for nm in names:
        if nm.endswith(('.plist', '.storyboard', '.xcworkspacedata')):
            xml_files.append(os.path.join(dirpath, nm))
xml_files.sort()

for fp in xml_files:
    rel = os.path.relpath(fp, ROOT)
    try:
        minidom.parse(fp)
        print('[OK] XML:', rel)
    except Exception as e:
        fail(f'XML {rel}: {e}')

# ---------- 2. pbxproj 校验 ----------
pbx = os.path.join(IOS, 'Runner.xcodeproj', 'project.pbxproj')
with open(pbx, 'r', encoding='utf-8') as f:
    src = f.read()

# 2.1 段落配对
for begin in re.finditer(r'/\* Begin ([A-Za-z]+) section \*/', src):
    pass
begins = re.findall(r'/\* Begin ([A-Za-z]+) section \*/', src)
ends = re.findall(r'/\* End ([A-Za-z]+) section \*/', src)
for b in begins:
    if b not in ends:
        fail(f'pbxproj 段落 {b} 缺少 End')
for e in ends:
    if e not in begins:
        fail(f'pbxproj 段落 {e} 缺少 Begin')
print('[OK] pbxproj 段落配对:', ', '.join(begins))

# 2.2 括号配平（字符串感知）
def strip_tokens(text):
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i+1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and text[i+1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i+1] == '/'):
                i += 1
            i += 2
            continue
        if c in '"\'':
            q = c
            i += 1
            while i < n and text[i] != q:
                if text[i] == '\\':
                    i += 2
                else:
                    i += 1
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)

body = strip_tokens(src)
counts = {ch: body.count(ch) for ch in '(){}'}
for a, b in (('(', ')'), ('{', '}')):
    if counts[a] != counts[b]:
        fail(f'pbxproj {a}{b} 不配对: {counts[a]} vs {counts[b]}')
print(f'[OK] pbxproj 括号配平 ( {counts["("]} / {{ {counts["{"]} )')

# 2.3 UUID 引用一致性（定义行 = UUID 后跟 " /*" 或 " = {"）
# 先检测非法 ID：pbxproj 对象 ID 必须是 24 位十六进制（G-Z 字母会导致 Xcode 解析失败）
invalid_tokens = [t for t in re.findall(r'[0-9A-Z]{24}', src)
                  if any(c in 'GHIJKLMNOPQRSTUVWXYZ' for c in t)]
if invalid_tokens:
    fail(f'pbxproj 存在非十六进制 ID: {sorted(set(invalid_tokens))}')
else:
    print('[OK] pbxproj 无非法 ID（全部为 24 位十六进制）')

all_ids = set(re.findall(r'[0-9A-F]{24}', src))
defs = set(m.group(1) for m in re.finditer(r'^\s*([0-9A-F]{24})(?: /\*| = \{)', src, re.M))
refs = all_ids - defs
missing = sorted(r for r in refs if r not in defs)
if missing:
    fail(f'pbxproj 引用了未定义的 UUID: {missing}')
else:
    print(f'[OK] pbxproj UUID 一致性（定义 {len(defs)} 个 / 引用 {len(refs)} 个，无悬空引用）')

# 2.4 结构完整性
must_have = ['isa = PBXProject;', 'isa = PBXNativeTarget;', 'productType = "com.apple.product-type.application";',
             'rootObject', 'ShellScriptBuildPhase', 'PBXSourcesBuildPhase', 'PBXResourcesBuildPhase',
             'PBXFrameworksBuildPhase', 'PRODUCT_BUNDLE_IDENTIFIER = com.xintiao.app;']
for token in must_have:
    if token not in src:
        fail(f'pbxproj 缺少关键结构: {token}')
if all(t in src for t in must_have):
    print('[OK] pbxproj 关键结构齐全（Runner 目标 / 三段构建 / 签名配置）')

# 2.5 目标构建阶段引用存在
target_block = re.search(r'C10000000000000000000001 /\* Runner \*/ = \{[^}]*buildPhases = \((.*?)\);', src, re.S)
if target_block:
    phase_ids = re.findall(r'[0-9A-F]{24}', target_block.group(1))
    for pid in phase_ids:
        if pid not in defs:
            fail(f'pbxproj 构建阶段引用未定义: {pid}')
    print(f'[OK] Runner 目标构建阶段 {len(phase_ids)} 个引用有效')
else:
    fail('pbxproj 未找到 Runner 目标的 buildPhases')

print()
print('结果:', '全部通过' if ok else '存在问题')
sys.exit(0 if ok else 1)
