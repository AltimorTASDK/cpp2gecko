#pragma GCC diagnostic ignored "-Wattributes"

#define GAME_EXTERN extern "C" [[gnu::section(".game")]] [[gnu::longcall]]