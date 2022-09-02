import argparse
import os.path
import re
import sys

def error(name, line, message):
    print(f"*** {name}:{line+1}: error: {message}", file=sys.stderr)
    sys.exit(1)

def asm_generator(asm, name, symbols):
    sym_name = None
    sym_type = None

    lr_save    = False
    lr_restore = False
    lr_offset  = None

    settings = {
        'pic_reg': None
    }

    r13_base = symbols.get("R13_BASE")
    r2_base  = symbols.get("R2_BASE")

    if r13_base is not None:
        r13_range = range(r13_base - 0x8000, r13_base + 0x8000)
    if r2_base is not None:
        r2_range = range(r2_base - 0x8000, r2_base + 0x8000)

    for n, raw_line in enumerate(asm):
        if raw_line.find("#") != -1:
            line = raw_line[:raw_line.find("#")].strip()
        else:
            line = raw_line.strip()

        line = line.replace("\t", " ")

        match = re.match(r"\.type (.+), @(.+)", line)
        if match is not None:
            sym_name, sym_type = match.groups()

        # Remove unnecessary prologue/epilogue instructions
        if sym_name == "__entry" and sym_type == "function":
            if line == "bl __end":
                error(name, n, "No tail call optimization on __end()")
            elif line == "mflr 0":
                lr_save = True
                continue
            elif lr_save:
                match = re.match(r"stw 0,(.*)\(1\)", line)
                if match is not None:
                    lr_save = False
                    lr_offset = match.group(1)
                    continue
            elif lr_restore:
                if line == "mtlr 0":
                    lr_restore = False
                    continue
            elif lr_offset is not None:
                if line == f"lwz 0,{lr_offset}(1)":
                    lr_restore = True
                    continue

        match = re.match(r"\.set gecko\.(.+), (.+)", line)
        if match is not None:
            key, value = match.groups()
            if key not in settings:
                error(name, n, f"Unrecognized .set directive for gecko.{key}")
            settings[key] = value

        # Make relocations against PIC base
        match = re.match(r".*,(\w+)([+-]\d+)?@sda21\(0\)", line)
        if match is not None:
            sym, offset = match.groups("+0")

            address = symbols.get(sym)
            if address is not None:
                # Game .sdata reference
                address += int(offset)
                if r13_base is not None and address in r13_range:
                    base, reg = r13_base, 13
                elif r2_base is not None and address in r2_range:
                    base, reg =  r2_base,  2
                else:
                    error(name, n, f"Couldn't resolve GAME_SDATA relocation")

                yield raw_line.replace("@sda21(0)", f"-0x{base:08X}@l({reg})")
                continue

            # PIC reference
            reg = settings['pic_reg']
            if reg is None:
                error(name, n, "Encountered @sda21 before .set gecko.pic_reg")

            yield raw_line.replace("@sda21(0)", f"+0x8004@sdarel({reg})")
            continue

        yield raw_line

def read_symbols(ldscript, name):
    symbols = {}
    for n, line in enumerate(ldscript):
        match = re.match(r"(\w+)\s*=\s*0x([0-9a-fA-F]{8});", line)
        if not match:
            error(name, n, "Line not in expected format")

        sym, address = match.groups()
        symbols[sym] = int(address, 16)

    return symbols

def main():
    parser = argparse.ArgumentParser(description=
        "Prepare generated assembly to be compiled into a gecko code")

    parser.add_argument("in_asm",   help="Input GNU assembler source")
    parser.add_argument("out_asm",  help="Output GNU assembler source")
    parser.add_argument("ldscript", help="game.ld linker script")
    args = parser.parse_args()

    with open(args.ldscript, "r") as ldscript:
        symbols = read_symbols(ldscript, os.path.basename(args.ldscript))

    with (open(args.in_asm,  "r") as in_asm,
          open(args.out_asm, "w") as out_asm):
        out_asm.writelines(asm_generator(in_asm, os.path.basename(args.in_asm),
                                         symbols))

if __name__ == "__main__":
    main()