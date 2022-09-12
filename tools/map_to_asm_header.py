import sys

def is_char_allowed(c):
    return 'a' <= c <= 'z' or 'A' <= c <= 'Z' or '0' <= c <= '9' or c == '_'

def main():
    if len(sys.argv) < 3:
        print("Usage: map_to_asm_header.py <in.map> <out.h>",
              file=sys.stderr)
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2]

    header = ""
    with open(in_path) as f:
        for line in f:
            if line.startswith("."):
                continue

            address, _, _, _, name, *_ = line.split()
            if name.startswith("zz_"):
                continue

            name = "".join(c for c in name if is_char_allowed(c))
            header += f".set {name:60s}, 0x{address}\n"

    with open(out_path, "w") as f:
        f.write(header)

if __name__ == "__main__":
    main()