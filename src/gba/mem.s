// Functions implemented in this file are in part adapted from here:
// https://github.com/devkitPro/libtonc/blob/master/asm/tonc_memcpy.s
// https://github.com/devkitPro/libtonc/blob/master/asm/tonc_memset.s

    .section .gba_mem, "ax"
    .global memcpy_thumb
    .global memcpy16_thumb
    .global memcpy32_thumb
    .global memset_thumb
    .global memset16_thumb
    .global memset32_thumb
    .type memcpy_thumb, %function
    .type memcpy16_thumb, %function
    .type memcpy32_thumb, %function
    .type memset_thumb, %function
    .type memset16_thumb, %function
    .type memset32_thumb, %function
    .cpu arm7tdmi
    .thumb

memcpy_thumb:
    ldr     r3, _memcpy_arm_word
    bx      r3                  // Tail call into ARM code

memcpy16_thumb:
    ldr     r3, _memcpy16_arm_word
    bx      r3                  // Tail call into ARM code

memcpy32_thumb:
    ldr     r3, _memcpy32_arm_word
    bx      r3                  // Tail call into ARM code

memset_thumb:
    ldr     r3, _memset_arm_word
    bx      r3                  // Tail call into ARM code

memset16_thumb:
    ldr     r3, _memset16_arm_word
    bx      r3                  // Tail call into ARM code

memset32_thumb:
    ldr     r3, _memset32_arm_word
    bx      r3                  // Tail call into ARM code

.align 4
    _memcpy_arm_word: .word memcpy_arm
    _memcpy16_arm_word: .word memcpy16_arm
    _memcpy32_arm_word: .word memcpy32_arm
    _memset_arm_word: .word memset_arm
    _memset16_arm_word: .word memset16_arm
    _memset32_arm_word: .word memset32_arm

    .section .gba_mem_iwram, "ax"
    .global memcpy_arm
    .global memcpy16_arm
    .global memcpy32_arm
    .global memset_arm
    .global memset16_arm
    .global memset32_arm
    .type memcpy_arm, %function
    .type memcpy16_arm, %function
    .type memcpy32_arm, %function
    .type memset_arm, %function
    .type memset16_arm, %function
    .type memset32_arm, %function
    .cpu arm7tdmi
    .arm

// Copy memory.
// For use with unaligned pointers, or pointers with uncertain alignment.
// r0: dst Destination pointer in, end of destination buffer out
// r1: src Source pointer in, end of source buffer out
// r2: n Count (bytes)
// Clobbers r3 and r12
memcpy_arm:
    cmp     r2, #1
    bxls    lr                  // return to thumb caller if n < 1
    and     r3, r0, #1          // var lsb = dst & 1
    beq     .memcpy_arm_dst_16_aligned // branch if lsb == 0
    and     r3, r1, #1          // lsb = src & 1
    bne     .memcpy_arm_both_16_unaligned // branch if lsb != 0
.memcpy_arm_loop_8:
    // Fallback loop for unreconcilable alignment
    subs    r2, r2, #1          // n -= 1
    ldrbcs  r3, [r1]!           // if n >= 0: load mem @ src to r3; src += 1
    strbcs  r3, [r0]!           // if n >= 0: store r3 mem @ dst; dst += 1
    bhi     .memcpy_arm_loop_8 // branch if n != 0
    bx      lr                  // return to thumb caller
.memcpy_arm_dst_16_aligned:
    and     r3, r1, #1          // lsb = src & 1
    beq     .memcpy_arm_cpy16_check_len // branch if lsb == 0
    b       .memcpy_arm_loop_8  // branch (unconditional)
.memcpy_arm_both_16_unaligned:
    subs    r2, r2, #1          // n -= 1
    ldrh    r3, [r1]!           // load mem @ src to r3; src += 2
    strh    r3, [r0]!           // store r3 mem @ dst; dst += 2
.memcpy_arm_cpy16_check_len:
    and     r3, r2, #1          // lsb = n & 1
    beq     .memcpy_arm_cpy16_fallthrough // branch if lsb == 0
    // Handle single extra byte
    add     r12, r1, r2         // r12 = src + n
    ldrh    r3, [r12, #-1]      // load mem @ r12 - 1 to r3
    add     r12, r0, r2         // r12 = dst + n
    strh    r3, [r12, #-1]      // store r3 to mem @ r12 - 1
.memcpy_arm_cpy16_fallthrough:
    movs    r2, r2, lsr #1      // n >>= 1
    // Falls through to memcpy16_arm like a tail call

// Copy half-word-aligned memory.
// r0: dst Destination pointer in, end of destination buffer out (half-word-aligned)
// r1: src Source pointer in, end of source buffer out (half-word-aligned)
// r2: n Count (half words)
// Clobbers r3 and r12
memcpy16_arm:
    cmp     r2, #1
    bxls    lr                  // return to thumb caller if n < 1
    and     r3, r0, #3          // var lsb = dst & 3
    beq     .memcpy16_arm_dst_32_aligned // branch if lsb == 0
    and     r3, r1, #3          // lsb = src & 3
    bne     .memcpy16_arm_both_32_unaligned // branch if lsb != 0
.memcpy16_arm_loop_16:
    // Fallback loop for unreconcilable alignment
    subs    r2, r2, #1          // n -= 1
    ldrhcs  r3, [r1]!           // if n >= 0: load mem @ src to r3; src += 2
    strhcs  r3, [r0]!           // if n >= 0: store r3 mem @ dst; dst += 2
    bhi     .memcpy16_arm_loop_16 // branch if n != 0
    bx      lr                  // return to thumb caller
.memcpy16_arm_dst_32_aligned:
    and     r3, r1, #1          // lsb = src & 1
    beq     .memcpy16_arm_cpy32_check_len // branch if lsb == 0
    b       .memcpy16_arm_loop_16 // branch (unconditional)
.memcpy16_arm_both_32_unaligned:
    subs    r2, r2, #1          // n -= 1
    ldrh    r3, [r1]!           // load mem @ src to r3; src += 2
    strh    r3, [r0]!           // store r3 mem @ dst; dst += 2
.memcpy16_arm_cpy32_check_len:
    and     r3, r2, #1          // lsb = n & 1
    beq     .memcpy16_arm_cpy32_fallthrough // branch if lsb == 0
    // Handle single extra byte
    add     r12, r1, r2         // r12 = src + n
    ldrb    r3, [r12, #-1]      // load mem @ r12 - 1 to r3
    add     r12, r0, r2         // r12 = dst + n
    strb    r3, [r12, #-1]      // store r3 to mem @ r12 - 1
.memcpy16_arm_cpy32_fallthrough:
    movs    r2, r2, lsr #1      // n >>= 1
    // Falls through to memcpy32_arm like a tail call

// Copy word-aligned memory.
// Performance running from IWRAM should be comparable to `gba.bios.cpuFastSet`,
// and unlike `cpuFastSet` this function can handle data lengths that are not
// a multiple of 8.
// r0: dst Destination pointer in, end of destination buffer out (word-aligned)
// r1: src Source pointer in, end of source buffer out (word-aligned)
// r2: n Count (words)
// Clobbers r3 and r12
memcpy32_arm:
    and     r12, r2, #7         // var n_words = n & 7
    movs    r2, r2, lsr #3      // n >>= 3
    beq     .memcpy32_arm_loop_words // branch if n == 0
    push    {r4-r10}            // save registers on stack
.memcpy32_arm_loop_32b_chunks:
    ldmia   r1!, {r3-r10}       // load mem @ src to r3..r10; src += 32
    stmia   r0!, {r3-r10}       // store r3..r10 to mem @ dst; dst += 32
    subs    r2, r2, #1          // n -= 1
    bhi     .memcpy32_arm_loop_32b_chunks // branch if n != 0
    pop     {r4-r10}            // restore registers from stack
.memcpy32_arm_loop_words:
    subs    r12, r12, #1        // n_words -= 1
    ldrcs   r3, [r1]!           // if n_words >= 0: load mem @ src to r3; src += 4
    strcs   r3, [r0]!           // if n_words >= 0: store r3 to mem @ dst; dst += 4
    bhi     .memcpy32_arm_loop_words // branch if n_words != 0
    bx      lr                  // return to thumb caller

// Set memory.
// r0: dst Destination pointer in, end of destination buffer out
// r1: src Value to write.
// r2: n Count (bytes)
memset_arm:
    and     r3, r0, #1          // var lsb = dst & 1
    beq     .memset_arm_dst_16_aligned // branch if lsb == 0
    strb    r1, [r0]!           // store r1 mem @ dst; dst += 1
.memset_arm_dst_16_aligned:
    movs    r3, r1, lsl #8      // r3 = r1 << 8
    orr     r1, r1, r3          // r1 = r1 | r3
    movs    r2, r2, lsr #1      // n >>= 1
    // Falls through to memset16_arm like a tail call

// Set half-word-aligned memory.
// r0: dst Destination pointer in, end of destination buffer out (half-word-aligned)
// r1: src Value to write.
// r2: n Count (half words)
memset16_arm:
    and     r3, r0, #1          // var lsb = dst & 1
    beq     .memset16_arm_dst_32_aligned // branch if lsb == 0
    strh    r1, [r0]!           // store r1 mem @ dst; dst += 2
.memset16_arm_dst_32_aligned:
    movs    r3, r1, lsl #16     // r3 = r1 << 16
    orr     r1, r1, r3          // r1 = r1 | r3
    movs    r2, r2, lsr #1      // n >>= 1
    // Falls through to memset32_arm like a tail call

// Set word-aligned memory.
// Performance running from IWRAM should be comparable to `gba.bios.cpuFastSet`,
// and unlike `cpuFastSet` this function can handle data lengths that are not
// a multiple of 8.
// r0: dst Destination pointer in, end of destination buffer out (word-aligned)
// r1: src Value to write.
// r2: n Count (words)
// Clobbers r3
memset32_arm:
    and     r3, r2, #7          // var n_words = n & 7
    movs    r2, r2, lsr #3      // n >>= 3
    beq     .memset32_arm_loop_words // branch if n == 0
    push    {r4-r9}             // save registers on stack
    // Initialize registers for use with stmia
    mov     r3, r0
    mov     r4, r0
    mov     r5, r0
    mov     r6, r0
    mov     r7, r0
    mov     r8, r0
    mov     r9, r0
.memset32_arm_loop_32b_chunks:
    stmia   r0!, {r1, r3-r9}    // store r1, r3..r9 to mem @ dst; dst += 32
    subs    r2, r2, #1          // n -= 1
    bhi     .memset32_arm_loop_32b_chunks // branch if n != 0
    pop     {r4-r9}             // restore registers from stack
.memset32_arm_loop_words:
    subs    r3, r3, #1          // n_words -= 1
    strcs   r1, [r0]!           // if n_words >= 0: store r1 to mem @ dst; dst += 4
    bhi     .memset32_arm_loop_words // branch if n_words != 0
    bx      lr                  // return to thumb caller
