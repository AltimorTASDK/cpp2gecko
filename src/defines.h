// Force absolute address references
#define GAME_FUNC   extern "C" [[gnu::longcall]]
#define GAME_GLOBAL extern "C" [[gnu::section(".game")]]

// Clown ass gcc only puts constant operands in .sdata
// if they're integers, so floats have to be globals
namespace cpp2gecko_impl {
template<float value> inline auto fp_const = value;
}

// Wrap in IIFE to prevent writes
#define FP(x) ([] { return cpp2gecko_impl::fp_const<x>; }())

#define GECKO_INIT(target, entry, pic_regname)                                 \
	[[gnu::section(".gecko.target")]] const auto __target = target;        \
	register void *pic_register asm(pic_regname);                          \
	extern "C" [[gnu::flatten]] void __call_entry()                        \
	{                                                                      \
		/* Add a symbol to indicate the PIC register */                \
		asm("__pic_use_" pic_regname ":");                             \
		const auto reg_save = pic_register;                            \
		pic_register = __builtin_return_address(0);                    \
		entry();                                                       \
		pic_register = reg_save;                                       \
	}