#!/usr/bin/env python3
"""Emit fixed signed bridges. Source census: 177 normal,3 pp,4 stack,93 Mips2C,2 leaves."""
import pathlib
import sys
kinds = [('arg',177),('process',3),('stack',4),('mips2c',93),('nothing',1),('zero',1)]
lines=['.globl _ottsel_export_bank_targets',
       '.zerofill __DATA,__bss,_ottsel_export_bank_targets,4464,3',
       '.section __GOAL,__text,regular,pure_instructions', '.balign 16',
       '.globl _ottsel_export_bank_begin', '_ottsel_export_bank_begin:']
slot=0
for kind,count in kinds:
    for _ in range(count):
        lines += [f'Lexport_tag_{slot}:', '.long 0x001bfec4']
        if kind in ('nothing','zero'):
            if kind=='zero':lines+=['mov w0,#0']
            lines+=['ret']
        else:
            lines+=['adrp x16,_ottsel_export_bank_targets@PAGE',
                    'add x16,x16,_ottsel_export_bank_targets@PAGEOFF',
                    f'ldr x17,[x16,#{slot*16}]', 'str x17,[sp,#-16]!']
            if kind=='process':lines+=['mov x3,x20']
            if kind=='mips2c':lines += [f'ldr x17,[x16,#{slot*16+8}]','str x17,[sp,#-16]!']
            helper='arg' if kind=='process' else kind
            lines += [f'adrp x17,_{helper}_call_arm64@PAGE',
                      f'add x17,x17,_{helper}_call_arm64@PAGEOFF','br x17']
        lines += [f'.space 64-(.-Lexport_tag_{slot}),0']
        slot+=1
lines += ['.globl _ottsel_export_bank_end','_ottsel_export_bank_end:']
assert slot==279
pathlib.Path(sys.argv[1]).write_text('\n'.join(lines)+'\n')
