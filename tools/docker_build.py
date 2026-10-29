"""Container entry point: validate the supplied USA ROM and export both cartridges."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom',type=Path,default=Path('/input/game.sfc'))
    parser.add_argument('--output',type=Path,default=Path('/output'))
    args=parser.parse_args()
    if not args.rom.is_file(): parser.error('Mount the commercial USA ROM read-only at /input/game.sfc, or use --rom')
    if not args.output.is_dir(): parser.error('Mount a writable output directory at /output, or use --output')
    tools=Path(__file__).resolve().parent
    for script,source,output in (
        ('build_stock.py',args.rom,args.output/'stock-smk.sfc'),
        ('build_linked.py',args.output/'stock-smk.sfc',args.output/'linked-smk.sfc')):
        subprocess.run([sys.executable,str(tools/script),str(source),'--asar','/usr/local/bin/asar','--output',str(output)],check=True)
    manifest={name:hashlib.sha256((args.output/name).read_bytes()).hexdigest()
              for name in ('stock-smk.sfc','linked-smk.sfc')}
    (args.output/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Exported byte-verified stock ROM and linked ROM to '+str(args.output))


if __name__=='__main__': main()
