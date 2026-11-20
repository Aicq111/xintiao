# -*- coding: utf-8 -*-
"""用 zipfile 重新打包 ipa：保留 Unix 权限位（Mach-O 可执行文件置 +x），修复 PackageExtractionFailed。"""
import os, sys, zipfile, stat

sys.stdout.reconfigure(encoding='utf-8')

PAYLOAD = r'D:\deepseek工作区\装机文件\payload_final\Payload'
OUT = r'D:\deepseek工作区\装机文件\薪跳v3.ipa'

MACHO_MAGICS = {
    b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
    b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
    b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca',
}

def is_macho(path):
    try:
        with open(path, 'rb') as f:
            return f.read(4) in MACHO_MAGICS
    except Exception:
        return False

count = 0
execs = 0
with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(PAYLOAD):
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, os.path.dirname(PAYLOAD)).replace('\\', '/')
            if is_macho(full):
                ext_attr = (stat.S_IFREG | 0o755) << 16
                execs += 1
            else:
                ext_attr = (stat.S_IFREG | 0o644) << 16
            zi = zipfile.ZipInfo(rel)
            zi.external_attr = ext_attr
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(full, 'rb') as f:
                z.writestr(zi, f.read())
            count += 1
        for name in sorted(dirs):
            rel = os.path.relpath(os.path.join(root, name), os.path.dirname(PAYLOAD)).replace('\\', '/') + '/'
            zi = zipfile.ZipInfo(rel)
            zi.external_attr = (stat.S_IFDIR | 0o755) << 16
            z.writestr(zi, b'')
            count += 1

print(f'打包完成: {OUT}')
print(f'条目数: {count}, 可执行文件数: {execs}, 大小: {os.path.getsize(OUT)/1024/1024:.1f} MB')
