"""Apply the link gameplay patch only to a byte-verified stock USA ROM."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile
from player_storage import relocate

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('stock', type=Path)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--asar', default='/workspace/toolchain/asar171-build/asar/asar-standalone')
a = p.parse_args()
data = a.stock.read_bytes()
if hashlib.sha256(data).hexdigest() != '2ada8919688087be60a6a48cace8f877add60c45d2e5d09e2442faa55be62a49':
    p.error('The input must be the validated, headerless stock USA ROM')
a.output = a.output.resolve()
a.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(dir=a.output.parent, prefix='smk-linked-') as directory:
    output = Path(directory) / 'linked.sfc'
    relocated,changes=relocate(data,(Path(__file__).resolve().parents[1]/'SMK/Routine_Macros_SMK.asm').read_text())
    output.write_bytes(relocated)
    subprocess.run([a.asar, '--fix-checksum=on', str(Path(__file__).with_name('linked_patch.asm')), str(output)], check=True)
    output.replace(a.output)
print(a.output)
print(f'Relocated {len(changes)} verified per-player storage operands')
