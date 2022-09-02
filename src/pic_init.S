.section .init, "ax"
.global __init
__init:
        bl      __call_entry
__pic_base:
        b       __end
__sdata_start:

.section .end, "ax"
__end:
        nop