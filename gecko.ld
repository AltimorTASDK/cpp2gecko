OUTPUT_FORMAT(elf32-powerpc);
OUTPUT_ARCH(powerpc:common);
EXTERN(__init);
ENTRY(__init);

SECTIONS
{
    /DISCARD/ : { *crtbegin.o(*) *crtend.o(*) }

    .init   : { *(.init) }
    /* .sdata must be after __init to get address from LR */
    .sdata  : { *(  .sdata   .sdata.*)
                *(   .sbss    .sbss.*)
                *( .rodata  .rodata.*) }
    .text   : { *(   .text    .text.*) }

    /DISCARD/ : { *(*) }
}