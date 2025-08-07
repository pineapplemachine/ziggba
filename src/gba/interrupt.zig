//! This module provides an API for interacting with the GBA's hardware
//! interrupts.

const gba = @import("gba.zig");

/// Location in EWRAM where the system expects to find an interrupt service
/// routine (ISR) ARM function pointer.
/// ZigGBA initializes this to point to `isr_default`.
/// Don't change this unless you're sure you know what you're doing!
pub const isr_ptr: *volatile *const fn() callconv(.c) void = (
    @ptrFromInt(gba.mem.iwram + 0x7ffc)
);

/// Default interrupt service routine, implemented in assembly.
/// By default, this function is called by hardware in ARM mode to handle
/// interrupts, and then this function wraps a call to `isr_default_redirect`
/// within some important ISR bookkeeping.
///
/// See `src/gba/isr.s`.
pub extern fn isr_default() callconv(.c) void;

/// Default stub function which `isr_default_redirect` is initialized to
/// point to during the startup routine. Does nothing.
/// Set `isr_default_redirect` to something else to implement your own
/// interrupt handler.
pub fn isr_default_redirect_null(_: InterruptFlags) callconv(.c) void {}

/// Pointer to an interrupt handler function called by `isr_default_redirect`.
/// Set this to something other than `isr_default_redirect_null` to implement
/// your own interrupt handler.
pub extern var isr_default_redirect: *const fn(InterruptFlags) callconv(.c) void;

/// Enumeration of hardware interrupts.
/// See also `InterruptFlags`.
pub const Interrupt = enum(u4) {
    vblank = 0x0,
    hblank = 0x1,
    vcount = 0x2,
    timer_0 = 0x3,
    timer_1 = 0x4,
    timer_2 = 0x5,
    timer_3 = 0x6,
    serial = 0x7,
    dma_0 = 0x8,
    dma_1 = 0x9,
    dma_2 = 0xa,
    dma_3 = 0xb,
    keypad = 0xc,
    gamepak = 0xd,
};

pub const InterruptFlags = packed struct(u16) {
    /// LCD VBlank interrupt.
    /// Interrupts occur according to settings specified in REG_DISPSTAT.
    /// See `gba.display.status.vblank_interrupt`.
    vblank: bool = false,
    /// LCD HBlank interrupt.
    /// Interrupts occur after the HDraw, so that anything executed in an
    /// HBlank interrupt takes effect in the next line.
    /// Interrupts occur according to settings specified in REG_DISPSTAT.
    /// See `gba.display.status.hblank_interrupt`.
    hblank: bool = false,
    /// LCD VCounter match interrupt.
    /// Interrupts occur at the beginning of a scanline.
    /// Interrupts occur according to settings specified in REG_DISPSTAT.
    /// See `gba.display.status.vcount_interrupt`.
    vcount: bool = false,
    /// Timer 0 counter overflow interrupt.
    /// Interrupts only occur according to a flag in REG_TM0CNT.
    /// See `gba.timer[0].ctrl.interrupt`.
    timer_0: bool = false,
    /// Timer 1 counter overflow interrupt.
    /// Interrupts only occur according to a flag in REG_TM1CNT.
    /// See `gba.timer[1].ctrl.interrupt`.
    timer_1: bool = false,
    /// Timer 2 counter overflow interrupt.
    /// Interrupts only occur according to a flag in REG_TM2CNT.
    /// See `gba.timer[2].ctrl.interrupt`.
    timer_2: bool = false,
    /// Timer 3 counter overflow interrupt.
    /// Interrupts only occur according to a flag in REG_TM3CNT.
    /// See `gba.timer[3].ctrl.interrupt`.
    timer_3: bool = false,
    /// Serial communication interrupt.
    /// May require REG_SCCNT.
    serial: bool = false,
    /// DMA 0 interrupt.
    /// Interrupt is raised upon a full transfer being complete.
    /// Also requires REG_DMA0CNT.
    /// See `gba.dma[0].ctrl.irq_at_end`.
    dma_0: bool = false,
    /// DMA 1 interrupt.
    /// Interrupt is raised upon a full transfer being complete.
    /// Also requires REG_DMA1CNT.
    /// See `gba.dma[0].ctrl.irq_at_end`.
    dma_1: bool = false,
    /// DMA 2 interrupt.
    /// Interrupt is raised upon a full transfer being complete.
    /// Also requires REG_DMA2CNT.
    /// See `gba.dma[0].ctrl.irq_at_end`.
    dma_2: bool = false,
    /// DMA 3 interrupt.
    /// Interrupt is raised upon a full transfer being complete.
    /// Also requires REG_DMA3CNT.
    /// See `gba.dma[0].ctrl.irq_at_end`.
    dma_3: bool = false,
    /// Keypad interrupt.
    /// Interrupt is raised according to options specified via the REG_KEYCNT
    /// register. See `gba.input.interrupt` for an API for interfacing with
    /// this register.
    keypad: bool = false,
    /// Game pak (external IRQ source) interrupt.
    /// Interrupt is raised when the cartridge is removed from the GBA. 
    gamepak: bool = false,
    /// Unused bits.
    _: u2 = 0,
    
    /// Get the bit associated with a given interrupt.
    pub fn get(self: InterruptFlags, interrupt: Interrupt) bool {
        const bits: u16 = @bitCast(self);
        return ((bits >> @intFromEnum(interrupt)) & 1) != 0;
    }
    
    /// Assign the bit associated with a given interrupt to 1.
    pub fn set(self: *InterruptFlags, interrupt: Interrupt) void {
        const bits: u16 = @bitCast(self);
        self.* = @bitCast(bits | (1 << @intFromEnum(interrupt)));
    }
    
    /// Assign the bit associated with a given interrupt to 0.
    pub fn unset(self: *InterruptFlags, interrupt: Interrupt) void {
        const bits: u16 = @bitCast(self);
        self.* = @bitCast(bits & ~(1 << @intFromEnum(interrupt)));
    }
    
    /// Assign the bit associated with a given interrupt to a given value.
    pub inline fn assign(self: *InterruptFlags, interrupt: Interrupt, value: bool) void {
        if(value) {
            self.set(interrupt);
        }
        else {
            self.unset(interrupt);
        }
    }
    
    pub inline fn and_flags(a: InterruptFlags, b: InterruptFlags) InterruptFlags {
        const bits_a: u16 = @bitCast(a);
        const bits_b: u16 = @bitCast(b);
        return @bitCast(bits_a & bits_b);
    }
    
    pub inline fn or_flags(a: InterruptFlags, b: InterruptFlags) InterruptFlags {
        const bits_a: u16 = @bitCast(a);
        const bits_b: u16 = @bitCast(b);
        return @bitCast(bits_a | bits_b);
    }
    
    pub inline fn xor_flags(a: InterruptFlags, b: InterruptFlags) InterruptFlags {
        const bits_a: u16 = @bitCast(a);
        const bits_b: u16 = @bitCast(b);
        return @bitCast(bits_a ^ bits_b);
    }
};

/// Represents the content of REG_IME.
pub const Master = packed struct(u32) {
    /// Master interrupt enable flag.
    ///
    /// If this flag is false, then no interrupts will occur, regardless
    /// of individual per-interrupt enable flags.
    enable: bool = false,
    /// Unused bits.
    _: u31 = 0,
};

/// Acknowledge an interrupt, by setting the appropriate interrupt flag
/// in `irq_ack`.
/// This is the same as calling `irq_ack.set(interrupt)`.
pub fn acknowledge(interrupt: Interrupt) void {
    irq_ack.set(interrupt);
}

/// Interrupt enable flags.
/// When `master.enable` is set, the events specified by these
/// flags will trigger an interrupt.
///
/// Since interrupts can trigger at any point, `master.enable`
/// should be unset while clearing flags from this register,
/// to avoid spurious interrupts.
///
/// Corresponds to REG_IE.
pub const enable: *volatile InterruptFlags = @ptrFromInt(gba.mem.io + 0x200);

/// Interrupt request and IRQ acknowledge flags.
/// Active interrupt requests can be read from this register.
///
/// Interrupts must be manually acknowledged by setting one of the
/// IRQ bits. (The IRQ bit will then be cleared.)
/// To clear an interrupt, write ONLY that flag to this register.
/// The `acknowledge` function can help with this.
///
/// Corresponds to REG_IF.
pub const irq_ack: *volatile InterruptFlags = @ptrFromInt(gba.mem.io + 0x202);

/// Additional IRQ acknowledge flags, to be used with BIOS calls which
/// require interrupts.
///
/// Corresponds to REG_IFBIOS.
pub const irq_ack_bios: *volatile InterruptFlags = @ptrFromInt(gba.mem.iwram + 0x7ff8);

/// Corresponds to REG_IME.
pub const master: *volatile Master = @ptrFromInt(gba.mem.io + 0x208);
