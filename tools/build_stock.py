#!/usr/bin/env python3
"""Extract the user's assets and rebuild SMK in an isolated, disposable directory."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('rom', type=Path)
p.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
p.add_argument('--output', type=Path, default=Path('/workspace/build/stock-smk.sfc'))
p.add_argument('--asar', default='/workspace/toolchain/asar171-build/asar/asar-standalone')
a = p.parse_args()
a.repo = a.repo.resolve()
a.output = a.output.resolve()
a.asar = shutil.which(a.asar) or str(Path(a.asar).resolve())
rom = a.rom.read_bytes()
if len(rom) == 524800:
    rom = rom[512:]
if len(rom) != 524288 or hashlib.md5(rom).hexdigest() != '7f25ce5a283d902694c52fb1152fa61a':
    p.error('Expected the supported USA dump (MD5 7f25ce5a283d902694c52fb1152fa61a)')
a.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='smk-stock-', dir=a.output.parent) as tmp:
    root = Path(tmp)
    for name in ('Global', 'SMK', 'Firmware'):
        shutil.copytree(a.repo / name, root / name)
    smk = root / 'SMK'
    assets = smk / 'AsarScripts'
    def run(args, cwd):
        subprocess.run([a.asar, *args], cwd=cwd, check=True)
    table = root / 'asset-table.bin'
    run(['--fix-checksum=off', '--no-title-check', '-DROMVer=$0001',
         'AssetPointersAndFiles.asm', str(table)], assets)
    data = table.read_bytes()
    def u24(offset):
        return int.from_bytes(data[offset:offset+3], 'little')
    destinations = ['Graphics', 'Graphics/Compressed', 'SPC700/Music', 'SPC700/Samples']
    count = 0
    for group, destination in enumerate(destinations, 1):
        start, length = u24(group*6)-0xC00000, u24(group*6+3)
        for index in range(length):
            pos = start + index*12
            first, last, ns, ne = [u24(pos+i) - 0xC00000 for i in (0, 3, 6, 9)]
            name = data[ns:ne].decode('ascii').strip('\x00\r\n')
            if Path(name).name != name or not 0 <= first <= last <= len(rom):
                raise ValueError('Invalid asset table entry')
            target=smk / destination / name
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(rom[first:last])
            count += 1
    # The framework's extraction table omits its checked-in tilemaps, palettes
    # and tracks. Recreate these from verified ROM slices as well, so a source-
    # only Docker context does not need any commercial assets in image layers.
    for entry in json.loads((a.repo/'tools/stock_assets.json').read_text()):
        relative=Path(entry['path'])
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Invalid stock asset path')
        first=entry['offset']; last=first+entry['length']
        payload=rom[first:last]
        if not 0<=first<last<=len(rom) or hashlib.sha256(payload).hexdigest()!=entry['sha256']:
            raise ValueError('Stock asset slice mismatch: '+str(relative))
        target=smk/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(payload)
        count+=1
    samples = smk / 'SPC700/Samples'
    if (samples / '07_02.brr').exists():
        with (samples / '07.brr').open('ab') as f:
            f.write((samples / '07_02.brr').read_bytes())
        (samples / '07_02.brr').unlink()
    output = smk / 'stock.sfc'
    common = ['-DGameID=SMK', '-DROMID=SMK_U1']
    for flags, target in [(['--fix-checksum=on', '-DFileType=0'], output),
                          (['--no-title-check', '-DFileType=4', '-DPathToFile=SPC700/Engine.asm'], smk/'SPC700/Engine.bin'),
                          (['-DFileType=1'], output), (['-DFileType=2'], output),
                          (['--fix-checksum=off', '-DFileType=3'], output)]:
        run([*flags, *common, '../Global/AssembleFile.asm', str(target)], smk)
    built = output.read_bytes()
    if built != rom:
        mismatch = next((i for i, (x, y) in enumerate(zip(built, rom)) if x != y), min(len(built), len(rom)))
        raise RuntimeError(f'Stock rebuild differs at offset {mismatch:#x}; size {len(built)}')
    output.replace(a.output)
    print(f'PASS: {count} assets extracted; {len(built)} rebuilt bytes equal the supplied ROM')
    print(f'SHA256 {hashlib.sha256(built).hexdigest()}  {a.output}')
