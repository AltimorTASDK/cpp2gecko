.section .init, "ax"
.global __init
__init:
        bl      __entry

.section .end, "ax"
.global __end
__end:
        nop