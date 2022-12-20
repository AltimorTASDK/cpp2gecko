OUTPUT_FORMAT(elf32-powerpc);
OUTPUT_ARCH(powerpc:common);
EXTERN(__init);
ENTRY(__init);

SECTIONS
{
    .gecko.target : { KEEP(*(.gecko.target)) }
    .gecko.lines  : { LONG(__gecko_lines);   }

    .init  : { KEEP(*(.init)) }
    /* .sdata must be after __init to get address from LR */
    .sdata : { *(.sdata.shared)
               *(.sdata .sdata.*)
               *( .sbss  .sbss.*) }
    .text  : { *( .text  .text.*) }

    .end   : { KEEP(*(.end)) }

    . = ALIGN(8);

    /* provide explicit base for sdarel relocations */
    _SDA_BASE_ = ADDR(.sdata);

    __gecko_lines = (. - ADDR(.init)) / 8;

    .note.gecko : { *(.note.gecko.*) }

    /DISCARD/ : { *(.data .data.* .rodata .rodata.* .bss .bss.* .note .note.*) }

}