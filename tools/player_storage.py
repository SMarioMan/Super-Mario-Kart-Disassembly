"""Relocate explicitly sized original operands, checking each against the stock bytes.

The disassembly's CODE labels encode their original addresses. Only instruction
blocks with known lengths are walked; every replacement is checked against the
verified input ROM before it is written. Data tables are never searched as code.
"""
import re

RELOCATE={0x0e00:0x3440,0x0e02:0x3442,0x0d70:0x3500,0x0d72:0x3502,
          0x0d74:0x3520,0x0d76:0x3522,0x0d78:0x3540,0x0d7a:0x3542,
          0x0d7c:0x3560,0x0d7e:0x3562,0x0fc0:0x3580,0x0fc2:0x3582}
OPCODES={('STA',None):0x8d,('STA','x'):0x9d,('STA','y'):0x99,
         ('LDA','x'):0xbd,('LDA','y'):0xb9,('STZ',None):0x9c,
         ('BIT','x'):0x3c,('CMP','x'):0xdd,('INC','x'):0xfe,
         ('LDY','x'):0xbc,('ADC','x'):0x7d}


def relocate(data, source):
    result=bytearray(data)
    address=None
    changed=[]
    for raw in source.splitlines():
        line=raw.split(';',1)[0].strip()
        label=re.match(r'CODE_([0-9A-F]{6}):$',line)
        if label:
            address=int(label[1],16)
            continue
        if not line: continue
        if line.endswith(':') or line.startswith(('%','!','macro','endmacro')):
            address=None
            continue
        if address is None: continue
        instruction=re.fullmatch(r'([A-Z]{3})(?:\.([bwl]))?(?:\s+(.*))?',line)
        if not instruction:
            address=None
            continue
        mnemonic,size,operand=instruction.groups()
        length={'b':2,'w':3,'l':4}.get(size,1 if operand is None else 0)
        if not length:
            address=None
            continue
        literal=re.fullmatch(r'\$([0-9A-F]{4})(?:,([xy]))?',operand or '')
        if size=='w' and literal:
            old=int(literal[1],16)
            replacement=RELOCATE.get(old)
            # The inventory interpreter uses bit 7 of the pressed A byte.
            if old==0x0027 and 0x81b387<=address<0x81b426: replacement=0x371f
            if 0x80e88a<=address<0x80ea35:
                replacement={0x0020:0x3700,0x0021:0x3701,0x0028:0x3720}.get(old,replacement)
            if replacement is not None:
                offset=address&0x3fffff
                if data[offset]!=OPCODES.get((mnemonic,literal[2])):
                    raise ValueError(f'Original opcode verification failed at {address:06x}: {line}')
                if int.from_bytes(data[offset+1:offset+3],'little')!=old:
                    raise ValueError(f'Original operand verification failed at {address:06x}: {line}')
                result[offset+1:offset+3]=replacement.to_bytes(2,'little')
                changed.append((address,old,replacement))
        address+=length
    if len(changed)!=72:
        raise ValueError(f'Incomplete player storage relocation: {len(changed)} operands')
    return bytes(result),changed
