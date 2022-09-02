import argparse
from elftools.elf.elffile import ELFFile
import struct
import sys

R_PPC_ADDR16_LO = 4
R_PPC_ADDR16_HI = 5
R_PPC_ADDR16_HA = 6
R_PPC_REL24     = 10
R_PPC_SDAREL16  = 32
R_PPC_EMB_SDA21 = 109

ALLOWED_RELOCS = [
    R_PPC_ADDR16_LO,
    R_PPC_ADDR16_HI,
    R_PPC_ADDR16_HA,
    R_PPC_REL24,
    R_PPC_EMB_SDA21
]

PPC_RA_SHIFT = 16
PPC_RA_MASK  = 31 << PPC_RA_SHIFT

def fix_reloc(data, reloc, inst_offset, rela_offset, pic_offset, pic_register):
    # Set RA to PIC register
    instruction = struct.unpack_from(">I", data, inst_offset)[0]
    instruction = (instruction & ~PPC_RA_MASK) | (pic_register << PPC_RA_SHIFT)
    struct.pack_into(">I", data, inst_offset, instruction)

    # Set 16 bit offset into data section
    r_offset = reloc['r_offset'] + 2
    r_info   = (reloc['r_info_sym'] << 8) | R_PPC_SDAREL16
    r_addend = reloc['r_addend'] + pic_offset + 0x8000
    struct.pack_into(">III", data, rela_offset, r_offset, r_info, r_addend)

def fix_up_elf(in_elf, out_elf):
    data_count = 0

    data   = bytearray(in_elf.read())
    elf    = ELFFile(in_elf)
    text   = elf.get_section_by_name(".text")
    relocs = elf.get_section_by_name(".rela.text")
    symtab = elf.get_section_by_name(".symtab")

    if relocs is None:
        print("No .text relocations found")
        return

    # Find desired PIC register
    pic_register = None

    for symbol in symtab.iter_symbols():
        prefix = "__pic_use_r"
        if symbol.name.startswith(prefix):
            pic_register = int(symbol.name[len(prefix):])
            print(f"PIC register set to r{pic_register}")
            break

    if pic_register is None:
        print("No PIC register set")
        return

    # Account for offset between saved LR and .sdata start
    pic_base    = symtab.get_symbol_by_name("__pic_base")[0]
    sdata_start = symtab.get_symbol_by_name("__sdata_start")[0]
    pic_offset  = sdata_start['st_value'] - pic_base['st_value']

    for i, reloc in enumerate(relocs.iter_relocations()):
        r_type = reloc['r_info_type']

        if r_type not in ALLOWED_RELOCS:
            print(f"Unsupported relocation type {r_type}", file=sys.stderr)
            sys.exit(1)

        if r_type == R_PPC_EMB_SDA21:
            inst_offset = text['sh_offset'] + reloc['r_offset']
            rela_offset = relocs['sh_offset'] + i * relocs.entry_size
            fix_reloc(data, reloc, inst_offset, rela_offset,
                      pic_offset, pic_register)
            data_count += 1

    out_elf.write(data)

    print(f"Fixed up {data_count} data references")

def main():
    parser = argparse.ArgumentParser(description=
        "Fix relocations in a cpp2gecko intermediate relocatable .elf")

    parser.add_argument("in_elf",  help="Input relocatable ELF path")
    parser.add_argument("out_elf", help="Output relocatable ELF path")
    args = parser.parse_args()

    with (open(args.in_elf,  "rb") as in_elf,
          open(args.out_elf, "wb") as out_elf):
        fix_up_elf(in_elf, out_elf)

if __name__ == "__main__":
    main()