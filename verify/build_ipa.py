# -*- coding: utf-8 -*-
"""通用重打包脚本：GitHub 构建产物 zip → 无小组件标准 ipa（保留 Unix 权限）。
用法: python build_ipa.py <输入zip路径> [输出ipa路径]
"""
import os, sys, zipfile, stat, shutil, tempfile

sys.stdout.reconfigure(encoding='utf-8')

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

def main():
    if len(sys.argv) < 2:
        print('用法: python build_ipa.py <输入zip> [输出ipa]')
        sys.exit(1)
    src_zip = os.path.abspath(sys.argv[1])
    out_ipa = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else \
        os.path.splitext(src_zip)[0] + '.ipa'
    tmp = tempfile.mkdtemp(prefix='ipa_build_')

    # 1. 解压
    with zipfile.ZipFile(src_zip) as z:
        z.extractall(tmp)

    # 2. 定位 .app：zip 可能含 Runner.app 文件夹，或内容直接在根目录
    app_dir = None
    for root, dirs, files in os.walk(tmp):
        for d in dirs:
            if d.endswith('.app'):
                app_dir = os.path.join(root, d)
                break
        if app_dir:
            break
    if app_dir is None:
        # 内容直接平铺在根目录（GitHub 产物常见）
        if os.path.exists(os.path.join(tmp, 'Info.plist')):
            app_dir = os.path.join(tmp, 'Runner.app')
            os.makedirs(app_dir, exist_ok=True)
            for item in os.listdir(tmp):
                src_item = os.path.join(tmp, item)
                if src_item != app_dir:
                    shutil.move(src_item, os.path.join(app_dir, item))
        else:
            print('未找到 .app 结构，请检查 zip 内容')
            sys.exit(2)
    print('App 目录:', app_dir)

    # 3. 移除小组件扩展（免费 Apple ID 不支持 App Group）
    plug = os.path.join(app_dir, 'PlugIns')
    if os.path.exists(plug):
        shutil.rmtree(plug)
        print('已移除 PlugIns（小组件）')

    # 4. 组装 Payload 结构
    payload_root = os.path.join(tmp, '_payload')
    payload = os.path.join(payload_root, 'Payload')
    os.makedirs(payload, exist_ok=True)
    shutil.move(app_dir, os.path.join(payload, 'Runner.app'))

    # 5. 打包（Unix 权限：Mach-O 置 +x）
    count = 0
    execs = 0
    with zipfile.ZipFile(out_ipa, 'w', zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(payload_root):
            for name in sorted(files):
                full = os.path.join(root, name)
                rel = os.path.relpath(full, payload_root).replace('\\', '/')
                if is_macho(full):
                    ext_attr = (stat.S_IFREG | 0o755) << 16
                    execs += 1
                else:
                    ext_attr = (stat.S_IFREG | 0o644) << 16
                zi = zipfile.ZipInfo(rel)
                zi.external_attr = ext_attr
                with open(full, 'rb') as f:
                    z.writestr(zi, f.read())
                count += 1
            for name in sorted(dirs):
                rel = os.path.relpath(os.path.join(root, name), payload_root).replace('\\', '/') + '/'
                zi = zipfile.ZipInfo(rel)
                zi.external_attr = (stat.S_IFDIR | 0o755) << 16
                z.writestr(zi, b'')
                count += 1

    shutil.rmtree(tmp, ignore_errors=True)
    print(f'完成: {out_ipa} (条目 {count}, 可执行 {execs}, {os.path.getsize(out_ipa)/1024/1024:.1f} MB)')


if __name__ == '__main__':
    main()
