#include <bit>
#include <cstdint>
#include <type_traits>

// Force absolute address references
#define GAME_FUNC   extern "C" [[gnu::longcall]]
#define GAME_GLOBAL extern "C" [[gnu::section(".game")]]
#define GAME_SDATA  extern "C"

// Store data at the start of .sdata for easy retrieval
#define SHARED_DATA [[gnu::section(".sdata.shared")]]

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

#define FP_EQUAL(x, c) (cpp2gecko_impl::fp_equal<(c)>((x)))

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

// Same as above but for a volatile PIC register
#define GECKO_INIT_PIC_VOLATILE(target, entry, pic_regname)                    \
	asm(".section .init, \"ax\"                                    \r\n"   \
	    ".global __init                                            \r\n"   \
	    "__init:                                                   \r\n"   \
	    "        bl      __init_pic                                \r\n"); \
	                                                                       \
	asm(".set gecko.pic_reg, " pic_regname);                               \
	[[gnu::section(".gecko.target"), gnu::used]]                           \
	const auto __gecko_target = target;                                    \
	extern "C" [[gnu::flatten]] void __init_pic()                          \
	{                                                                      \
		register void *__pic_register asm(pic_regname);                \
		asm volatile("mflr " pic_regname);                             \
		entry();                                                       \
		__end();                                                       \
	}                                                                      \
	                                                                       \
	asm(".section .end, \"ax\"                                     \r\n"   \
	    ".global __end                                             \r\n"   \
	    "__end:                                                    \r\n"   \
	    "        nop                                               \r\n")

#define GECKO_RETURN(value)                                                    \
	return (void)[&] {                                                     \
		register decltype(value) result asm("r3");                     \
		result = (value);                                              \
		FORCE_WRITE(result);                                           \
	}()

// Get a pointer to another injection's data
template<typename T>
inline T *get_shared_data(auto *injection)
{
	// Find the gecko code from the branch offset
	// This assumes the branch has the AA/LK bits unset
	const auto offset = *(int*)injection << 6 >> 6;
	return (T*)((char*)injection + offset + 4);
}

namespace cpp2gecko_impl {
template<std::size_t N>
consteval auto make_elf_note(const char (&name)[N], const auto &desc)
{
	struct elf_note {
		uint32_t n_namesz;
		uint32_t n_descsz;
		uint32_t n_type;
		// Wrap in struct to allow array copies
		struct { std::remove_cvref_t<decltype(name)> value; } n_name alignas(4);
		struct { std::remove_cvref_t<decltype(desc)> value; } n_desc alignas(4);
	};
	return elf_note {
		.n_namesz = sizeof(name),
		.n_descsz = sizeof(desc),
		.n_type = 'GECK',
		.n_name = std::bit_cast<decltype(elf_note::n_name)>(name),
		.n_desc = std::bit_cast<decltype(elf_note::n_desc)>(desc)
	};
}
}

#define GECKO_ELF_NOTE(name, value)                                            \
	namespace gecko_elf_notes {                                            \
	[[gnu::section(".note.gecko."#name), gnu::used]]                       \
	const auto name = cpp2gecko_impl::make_elf_note("gecko."#name, value); \
	}                                                                      \
	static_assert(true) // Force semicolon

#define GECKO_NAME(value) GECKO_ELF_NOTE(name, value)