#include <bit>
#include <cstdint>

// Force absolute address references
#define GAME_FUNC   extern "C" [[gnu::longcall]]
#define GAME_GLOBAL extern "C" [[gnu::section(".game")]]
#define GAME_SDATA  extern "C"

// Clown ass gcc only puts constant operands in .sdata
// if they're integers, so floats have to be globals
namespace cpp2gecko_impl {
template<float value> inline auto fp_const = value;
}

// Prevent assignment
#define FP(x) (auto(cpp2gecko_impl::fp_const<(x)>))

// Compare a float to a constant using binary representation to avoid an .sdata entry
namespace cpp2gecko_impl {
template<float constant>
constexpr bool fp_equal(float value)
{
	// Mask sign bit off for zero compare due to negative zero
	constexpr auto mask = (1u << 31) - 1;
	if constexpr (constant == 0.f)
		return (std::bit_cast<int>(value) & mask) == (std::bit_cast<int>(constant) & mask);
	else
		return std::bit_cast<int>(value) == std::bit_cast<int>(constant);
}
}

#define FP_EQUAL(x, c) (cpp2gecko_impl::fp_equal<c>(x))

// Prevent the compiler from optimizing register writes away
#define FORCE_WRITE(x) asm volatile(""::"r"(x))

// Symbol supplied by asm finesser
extern "C" [[gnu::section(".sdata")]] void *__target_stack[];

#define __target_lr ((void(*&)())__target_stack[1])

extern "C" void __end();

// Force elision of stwu r1, -8(r1)
#define GECKO_NO_STACK_FRAME() asm(".set gecko.no_frame, 1")

#define GECKO_INIT(target, entry)                                              \
	[[gnu::section(".gecko.target"), gnu::used]]                           \
	const auto __gecko_target = target;                                    \
	extern "C" [[gnu::flatten, gnu::section(".init")]] void __init()       \
	{                                                                      \
		entry();                                                       \
		__end();                                                       \
	}                                                                      \
	                                                                       \
	asm(".section .end, \"ax\"                                     \r\n"   \
	    ".global __end                                             \r\n"   \
	    "__end:                                                    \r\n"   \
	    "        nop                                               \r\n")

#define GECKO_INIT_PIC(target, entry, pic_regname)                             \
	asm(".section .init, \"ax\"                                    \r\n"   \
	    ".global __init                                            \r\n"   \
	    "__init:                                                   \r\n"   \
	    "        bl      __init_pic                                \r\n"); \
	                                                                       \
	asm(".set gecko.pic_reg, " pic_regname);                               \
	[[gnu::section(".gecko.target"), gnu::used]]                           \
	const auto __gecko_target = target;                                    \
	register void *__pic_register asm(pic_regname);                        \
	extern "C" [[gnu::flatten]] void __init_pic()                          \
	{                                                                      \
		/* use volatile to force stack allocation */                   \
		volatile const auto reg_save = __pic_register;                 \
		asm volatile("mflr %0" : "=r"(__pic_register));                \
		entry();                                                       \
		__pic_register = reg_save;                                     \
		__end();                                                       \
	}                                                                      \
	                                                                       \
	asm(".section .end, \"ax\"                                     \r\n"   \
	    ".global __end                                             \r\n"   \
	    "__end:                                                    \r\n"   \
	    "        nop                                               \r\n")
