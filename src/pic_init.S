.section .init, "ax"
.global __init
__init:
        bl      __entry
__pic_base:
__sdata_start:

.section .end, "ax"
.global __end
__end:
        nop