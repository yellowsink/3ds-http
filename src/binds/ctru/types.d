extern(C):

/**
  * @file types.h
  * @brief Various system types.
  */

/// The maximum value of a u64.
alias Handle = uint; ///< Resource handle.
alias Result = int; ///< Function result.
alias ThreadFunc = void function(void*); ///< Thread entrypoint function.
alias voidfn = void function();

/// Creates a bitmask from a bit number.
enum BIT(alias n) = 1U << n;

/// Aligns a struct (and other types?) to m, making sure that the size of the struct is a multiple of m.
//#define CTR_ALIGN(m) __attribute__((aligned(m)))
/// Packs a struct (and other types?) so it won't include padding bytes.
//#define CTR_PACKED __attribute__((packed))

/// Structure representing CPU registers
struct CpuRegisters {
	uint[13] r; ///< r0-r12.
	uint sp; ///< sp.
	uint lr; ///< lr.
	uint pc; ///< pc. May need to be adjusted.
	uint cpsr; ///< cpsr.
}

/// Structure representing FPU registers
struct FpuRegisters {
	union {
		struct { align(1): double[16] d; }; ///< d0-d15.
		float[32] s; ///< s0-s31.
	}
	uint fpscr; ///< fpscr.
	uint fpexc; ///< fpexc.
}