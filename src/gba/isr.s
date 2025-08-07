// Credit to @braheezy on GitHub, whose implementation this one is based on,
// which was itself based on libtonc's default master ISR.
// https://github.com/braheezy/ZigGBA/pull/2
// https://github.com/devkitPro/libtonc/blob/master/asm/tonc_isr_master.s

    .section .gba_isr_data, "aw", %nobits
    .align 4
    .global isr_default_redirect

isr_default_redirect:
    .word   0

    .section .gba_isr, "ax"
    .global isr_default
    .type isr_default, %function
    .cpu arm7tdmi
    .extern isr_default_redirect
    .arm

isr_default:

    // Load REG_IE & REG_IF to determine what interrupt is being handled.
    mov     r0, #0x04000000
    ldr     ip, [r0, #0x200]!    // Load REG_IE
    ldr     r3, [r0, #2]         // Load REG_IF
    and     r1, ip, r3           // irq = REG_IE & REG_IF
    
    // Acknowledge IRQ for hardware and BIOS.
    strh    r1, [r0, #2]         // REG_IF = irq
    ldr     r3, [r0, #-0x208]    // Load REG_IFBIOS
    orr     r3, r3, r1           // REG_IFBIOS |= irq
    str     r3, [r0, #-0x208]    // Store modified REG_IFBIOS
    
    // Disable IME and clear the current IRQ in REG_IE.
    ldr     r3, [r0, #8]         // Read IME
    strb    r0, [r0, #8]         // Clear IME
    bic     r2, ip, r1           // Clear current irq in REG_IE
    strh    r2, [r0]             // Store modified REG_IE
    
    // Store values on the stack.
    mrs     r2, spsr
    stmfd   sp!, {r2-r3, ip, lr} // sprs, IME, (IE,IF), lr_irq
    
    // Set CPU mode to usr.
    mrs     r3, cpsr
    bic     r3, r3, #0xdf
    orr     r3, r3, #0x1f
    msr     cpsr, r3
    
    // Call the `isr_default_redirect` handler, implemented in Zig.
    // r0 contains REG_IE & REG_IF, as a function argument.
    stmfd   sp!, {r0,lr}         // &REG_IE, lr_sys
    mov     r0, r1
    ldr     r1, _isr_default_redirect_word
    ldr     r1, [r1]
    mov     lr, pc
    bx      r1
    ldmfd   sp!, {r0,lr}         // &REG_IE, lr_sys
    
    // Begin unwinding.
    strb    r0, [r0, #8]         // Clear IME again (safety)
    
    // Reset CPU mode to irq.
    mrs     r3, cpsr
    bic     r3, r3, #0xdf
    orr     r3, r3, #0x92
    msr     cpsr, r3
    
    // Restore state from stack.
    ldmfd   sp!, {r2-r3, ip, lr} // sprs, IME, (IE,IF), lr_irq
    msr     spsr, r2             // Restore spsr
    strh    ip, [r0]             // Restore IE
    str     r3, [r0, #8]         // Restore IME

    // Return from ISR.
    bx      lr

    // Ensure the interrupt handler function pointer constant is defined
    // near enough to this function to be referenced with `ldr` above.
    .align 4
    _isr_default_redirect_word: .word isr_default_redirect

.size isr_default, .-isr_default
