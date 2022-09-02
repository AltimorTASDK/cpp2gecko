.section .init, "ax"
.global __init
__init:
        mflr    r0
        stw     r0, 4(r1)
        stwu    r1, -12(r1)
        stw     r31, 8(r1)
        bl      _entry

.section .text
_entry:
        mflr    r31
        bl      entry
        lwz     r31, 8(r1)
        lwz     r0, 12+4(r1)
        addi    r1, r1, 12
        mtlr    r0
        blr
