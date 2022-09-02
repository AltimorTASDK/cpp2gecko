from elftools.elf.elffile import ELFFile
import struct
import sys

R_PPC_REL24     = 10
R_PPC_SDAREL16  = 32
R_PPC_EMB_SDA21 = 109

PPC_RA_SHIFT = 16
PPC_RA_MASK  = 31 << PPC_RA_SHIFT

def fix_reloc(data, reloc, inst_offset, rela_offset):
    # Set RA to r31
    instruction = struct.unpack_from(">I", data, inst_offset)[0]
    instruction = (instruction & ~PPC_RA_MASK) | (31 << PPC_RA_SHIFT)
    struct.pack_into(">I", data, inst_offset, instruction)

    # Set 16 bit offset into data section
    r_offset = reloc['r_offset'] + 2
    r_info   = (reloc['r_info_sym'] << 8) | R_PPC_SDAREL16
    r_addend = reloc['r_addend'] + 0x8000
    struct.pack_into(">III", data, rela_offset, r_offset, r_info, r_addend)

def main():
    if len(sys.argv) < 2:
        print("Usage: fix_data_references.py <gecko.elf>", file=sys.stderr)
        sys.exit(1)

    count = 0

    with open(sys.argv[1], "rb") as f:
        data = bytearray(f.read())
        elf = ELFFile(f)

        text   = elf.get_section_by_name(".text")
        relocs = elf.get_section_by_name(".rela.text")

        if relocs is None:
            print("No .text relocations found")
            return

        for i, reloc in enumerate(relocs.iter_relocations()):
            r_type = reloc['r_info_type']

            if r_type == R_PPC_REL24:
                continue

            if r_type != R_PPC_EMB_SDA21:
                print(f"Unsupported relocation type {r_type}")
                #sys.exit(1)

            inst_offset = text['sh_offset'] + reloc['r_offset']
            rela_offset = relocs['sh_offset'] + i * relocs.entry_size
            fix_reloc(data, reloc, inst_offset, rela_offset)
            count += 1

    with open(sys.argv[1], "wb") as f:
        f.write(data)

    print(f"Fixed up {count} data references")

if __name__ == "__main__":
    main()