// Implements math-related functions that cannot be implemented easily in Zig,
// or cannot be implemented performantly.

    .section .gba_math, "ax"
    .global umull_thumb
    .global smull_thumb
    .type umull_thumb, %function
    .type smull_thumb, %function
    .cpu arm7tdmi
    .thumb

umull_thumb:
    ldr     r3, _umull_arm_word
    bx      r3                  // Tail call into ARM code

smull_thumb:
    ldr     r3, _smull_arm_word
    bx      r3                  // Tail call into ARM code

.align 4
    _umull_arm_word: .word umull_arm
    _smull_arm_word: .word smull_arm

    .section .gba_math_iwram, "ax"
    .global umull_arm
    .global smull_arm
    .global FixedI32R8_mul_arm
    .global FixedI32R16_mul_arm
    .type umull_arm, %function
    .type smull_arm, %function
    .type FixedI32R8_mul_arm, %function
    .type FixedI32R16_mul_arm, %function
    .cpu arm7tdmi
    .arm

// Unsigned multiply long.
// Multiplies r0 * r1.
// Stores the low 32 bits of the product in r1 and the high 32 bits in r0.
// Clobbers r3.
umull_arm:
    mov     r3, r0
    umull   r0, r1, r3, r1
    bx      lr

// Signed multiply long.
// Multiplies r0 * r1.
// Stores the low 32 bits of the product in r1 and the high 32 bits in r0.
// Clobbers r3.
smull_arm:
    mov     r3, r0
    smull   r0, r1, r3, r1
    bx      lr

// Get the 32-bit product of two zig.math.FixedI32R8 values.
// Implemented with ARM asm in order to make use of `smull`.
// r0, r1: 32-bit operands.
// r0: 32-bit product.
// Clobbers r3.
FixedI32R8_mul_arm:
    mov     r3, r0
    smull   r0, r1, r3, r1      // lo, hi = r3 * r1
    mov     r0, r0, asr #8      // lo >>= 8
    mov     r1, r1, lsl #24     // hi <<= 24
    orr     r0, r0, r1          // lo |= hi
    bx      lr                  // return lo

// Get the 32-bit product of two zig.math.FixedI32R16 values.
// Implemented with ARM asm in order to make use of `smull`.
// r0, r1: 32-bit operands.
// r0: 32-bit product.
// Clobbers r3.
FixedI32R16_mul_arm:
    mov     r3, r0
    smull   r0, r1, r3, r1      // lo, hi = r3 * r1
    mov     r0, r0, asr #16     // lo >>= 16
    mov     r1, r1, lsl #16     // hi <<= 16
    orr     r0, r0, r1          // lo |= hi
    bx      lr                  // return lo
