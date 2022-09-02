// Don't warn for gnu::longcall on variables from GAME_EXTERN
#pragma GCC diagnostic ignored "-Wattributes"

// Force absolute address references
#define GAME_EXTERN \
	extern "C" [[gnu::section(".game")]] [[gnu::longcall]]

// Clown ass gcc only puts constant operands in .sdata
// if they're integers, so floats have to be globals
namespace cpp2gecko_impl {
template<float value> inline auto fp_const = value;
}

// Wrap in IIFE to prevent writes
#define FP(x) \
	([] { return cpp2gecko_impl::fp_const<x>; }())
