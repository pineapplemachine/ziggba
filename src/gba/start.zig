//! This module implements a Zig entry point for a GBA ROM.

const gba = @import("gba.zig");

/// This function is called after boot and initialization.
/// It must be defined in user code.
extern fn main() void;

extern var __data_lma: u8;
extern var __data_start__: u8;
extern var __data_end__: u8;
extern var __iwram_lma: u8;
extern var __iwram_start__: u8;
extern var __iwram_end__: u8;

export fn _start_zig() noreturn {
    // Initialize REG_WAITCNT.
    // TODO: Provide a build option to more easily customize this behavior
    gba.mem.wait_ctrl.* = .default;
    // Use BIOS function to clear data.
    // Don't clear EWRAM or IWRAM: Anything not overwritten later in this
    // startup routine can safely be garbage bytes.
    // TODO: Provide a build option to more easily customize this behavior
    gba.bios.registerRamReset(.{
        .palette = true,
        .vram = true,
        .oam = true,
        .sio_registers = true,
        .sound_registers = true,
        .other_registers = true,
    });
    // Copy .iwram section to IWRAM.
    gba.bios.cpuSetCopy32(
        @alignCast(@ptrCast(&__iwram_lma)),
        @alignCast(@ptrCast(&__iwram_start__)),
        @truncate(@intFromPtr(&__iwram_end__) - @intFromPtr(&__iwram_start__)),
    );
    // Copy .data section to EWRAM.
    gba.bios.cpuSetCopy32(
        @alignCast(@ptrCast(&__data_lma)),
        @alignCast(@ptrCast(&__data_start__)),
        @truncate(@intFromPtr(&__data_end__) - @intFromPtr(&__data_start__)),
    );
    // Initialize default ISR.
    // TODO: Consider putting isr_default in IWRAM?
    gba.interrupt.isr_default_redirect = gba.interrupt.isr_default_redirect_null;
    gba.interrupt.isr_ptr.* = &gba.interrupt.isr_default;
    // Call user's main.
    main();
    // If user's main ends, hang here.
    while (true) {}
}
