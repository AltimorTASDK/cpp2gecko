// Force absolute address references
#define GAME_FUNC   extern "C" [[gnu::longcall]]
#define GAME_GLOBAL extern "C" [[gnu::section(".game")]]
#define GAME_SDATA  extern "C"

// Clown ass gcc only puts constant operands in .sdata
// if they're integers, so floats have to be globals
namespace cpp2gecko_impl {
template<float value> inline auto fp_const = value;
}

// Wrap in IIFE to prevent writes
#define FP(x) ([] { return cpp2gecko_impl::fp_const<x>; }())

extern "C" void __end();

#define GECKO_INIT(target, entry, pic_regname)                                 \
	asm(".set gecko.pic_reg, " pic_regname);                               \
	[[gnu::section(".gecko.target"), gnu::used]]                           \
	const auto __gecko_target = target;                                    \
	register void *pic_register asm(pic_regname);                          \
	extern "C" [[gnu::flatten]] void __entry()                             \
	{                                                                      \
		const auto reg_save = pic_register;                            \
		pic_register = __builtin_return_address(0);                    \
		entry();                                                       \
		pic_register = reg_save;                                       \
		__end();                                                       \
	}
