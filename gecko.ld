OUTPUT_FORMAT(elf32-powerpc);
OUTPUT_ARCH(powerpc:common);
EXTERN(__init);
ENTRY(__init);

SECTIONS
{
    .init  : { *(.init) }
    /* .sdata must be after __init to get address from LR */
    .sdata : { *( .sdata  .sdata.*)
               *(  .sbss   .sbss.*) }
    .text  : { *(  .text   .text.*) }

    /DISCARD/ : { *(.data .data.* .rodata .rodata.*) }

}