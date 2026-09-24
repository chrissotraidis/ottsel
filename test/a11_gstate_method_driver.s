.section __GOAL,__text,regular,pure_instructions
.balign 8
.long 0x001bfec4
.globl _ottsel_gstate_method_driver
_ottsel_gstate_method_driver:
adrp x16,_ottsel_method_target@PAGE
ldr x16,[x16,_ottsel_method_target@PAGEOFF]
adrp x17,_ottsel_method_args@PAGE
add x17,x17,_ottsel_method_args@PAGEOFF
ldp x0,x1,[x17,#0]
ldp x2,x3,[x17,#16]
ldp x4,x5,[x17,#32]
ldp x6,x7,[x17,#48]
br x16
