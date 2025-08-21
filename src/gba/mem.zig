//! Module for memory related functions and accesses

const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Named definitions for all the system's hardware registers.
pub const io = @import("mem_io");

// Imports for DMA-related API.
pub const Dma = @import("mem_dma.zig").Dma;
pub const dma = @import("mem_dma.zig").dma;
pub const memcpyDma16 = @import("mem_dma.zig").memcpyDma16;
pub const memcpyDma32 = @import("mem_dma.zig").memcpyDma32;
pub const memsetDma16 = @import("mem_dma.zig").memsetDma16;
pub const memsetDma32 = @import("mem_dma.zig").memsetDma32;

// Allocator-related imports.
pub const getUnreservedEWRAM = @import("mem_alloc.zig").getUnreservedEWRAM;
pub const StackAllocator = @import("mem_alloc.zig").StackAllocator;

// TODO: Maybe make these volatile pointers to u8?
// Access to base addresses for memory regions. Intended mostly for internal use.
/// Base address for external work RAM
pub const ewram = 0x02000000;
/// Base address for internal work RAM
pub const iwram = 0x03000000;
/// Base address for MMIO registers
pub const io = 0x04000000;
/// Base address for palette data
pub const palette = 0x05000000;
/// Base address for video RAM
pub const vram = 0x06000000;
/// Base address for object attribute data
pub const oam = 0x07000000;
/// Base address for gamepak ROM
pub const rom = 0x08000000;
/// Base address for save RAM
pub const sram = 0x0E000000;
// Imports related to wait state control (memory access timings).
pub const wait_ctrl = @import("mem_wait.zig").wait_ctrl;
pub const WaitControl = @import("mem_wait.zig").WaitControl;

// These functions are implemented in assembly in `mem.s`.
extern fn memcpy_thumb(dst: [*]volatile u8, src: [*]const volatile u8, n: u32) callconv(.c) void;
extern fn memcpy16_thumb(dst: [*]volatile u16, src: [*]const volatile u16, n: u32) callconv(.c) void;
extern fn memcpy32_thumb(dst: [*]volatile u32, src: [*]const volatile u32, n: u32) callconv(.c) void;
extern fn memset_thumb(dst: [*]volatile u8, src: u8, n: u32) callconv(.c) void;
extern fn memset16_thumb(dst: [*]volatile u16, src: u16, n: u32) callconv(.c) void;
extern fn memset32_thumb(dst: [*]volatile u32, src: u32, n: u32) callconv(.c) void;

/// Base address for external work RAM (EWRAM).
pub const ewram_address = 0x02000000;

/// Base address for internal work RAM (IWRAM).
pub const iwram_address = 0x03000000;

/// Base address for memory-mapped input/output (MMIO) registers.
pub const io_address = 0x04000000;

/// Base address for palette data.
/// Note that this region of memory does not support 8-bit writes.
pub const palette_address = 0x05000000;

/// Base address for video RAM (VRAM).
/// Note that this region of memory does not support 8-bit writes.
pub const vram_address = 0x06000000;

/// Base address for object attribute data (OAM).
pub const oam_address = 0x07000000;

/// Base address for gamepak ROM.
pub const rom_address = 0x08000000;

/// Base address for wait state 1 gamepak ROM.
pub const rom_wait_1_address = 0x0a000000;

/// Base address for wait state 2 gamepak ROM.
pub const rom_wait_2_address = 0x0c000000;

/// Base address for save RAM (SRAM).
pub const sram_address = 0x0e000000;
/// Copy memory from a source to a destination pointer.
/// Use this function for pointers that aren't certain to be aligned on
/// either a word or half-word boundary.
/// May behave unpredictably if the source and destination buffers overlap.
///
/// Be careful of using this function when copying into VRAM.
/// If both pointers aren't half-word aligned, then copying will not happen
/// the way you probably expect.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memcpy(
    /// Write copied memory here.
    destination: *volatile anyopaque,
    /// Read memory from here.
    source: *const volatile anyopaque,
    /// Number of bytes to copy.
    count_bytes: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count_bytes], source[0..count_bytes]);
    }
    else {
        memcpy_thumb(@ptrCast(destination), @ptrCast(source), count_bytes);
    }
}

/// Copy memory from a source to a destination pointer, when both pointers
/// are aligned on a 16-bit half-word boundary.
/// May behave unpredictably if the source and destination buffers overlap.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memcpy16(
    /// Write copied memory here. Must be half-word-aligned.
    destination: *align(2) volatile anyopaque,
    /// Read memory from here. Must be half-word-aligned.
    source: *align(2) const volatile anyopaque,
    /// Number of 16-bit half words to copy.
    count_half_words: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count_half_words], source[0..count_half_words]);
    }
    else {
        memcpy16_thumb(@ptrCast(destination), @ptrCast(source), count_half_words);
    }
}

/// Copy memory from a source to a destination pointer, when both pointers
/// are aligned on a 32-bit word boundary.
/// May behave unpredictably if the source and destination buffers overlap.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memcpy32(
    /// Write copied memory here. Must be word-aligned.
    destination: *align(4) volatile anyopaque,
    /// Read memory from here. Must be word-aligned.
    source: *align(4) const volatile anyopaque,
    /// Number of 32-bit words to copy.
    count_words: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count_words], source[0..count_words]);
    }
    else {
        memcpy32_thumb(@ptrCast(destination), @ptrCast(source), count_words);
    }
}

/// Fill memory at a destination pointer with a given value.
/// Works for any alignment.
/// However, this function is not suitable for use with a destination in VRAM.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memset(
    /// Write here, filling memory with `value`.
    destination: *volatile anyopaque,
    /// Value to store in the destination buffer.
    value: u8,
    /// Number of bytes to copy.
    count_bytes: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count_bytes], value);
    }
    else {
        memset_thumb(@ptrCast(destination), value, count_bytes);
    }
}

/// Fill memory at a destination pointer with a given value, when the
/// destination is aligned on a 16-bit half-word boundary.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memset16(
    /// Write here, filling memory with `value`. Must be half-word-aligned.
    destination: *align(2) volatile anyopaque,
    /// Value to store in the destination buffer.
    value: u16,
    /// Number of 16-bit half words to copy.
    count_half_words: u32,
) void {
    assert((@intFromPtr(destination) & 1) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count_half_words], value);
    }
    else {
        memset16_thumb(@ptrCast(destination), value, count_half_words);
    }
}

/// Fill memory at a destination pointer with a given value, when the
/// destination is aligned on a 32-bit word boundary.
///
/// Normally uses a function stored in the GBA's IWRAM, but also implements
/// a fallback to run as you would expect in tests and at comptime where this
/// is not available.
pub fn memset32(
    /// Write here, filling memory with `value`. Must be word-aligned.
    destination: *align(4) volatile anyopaque,
    /// Value to store in the destination buffer.
    value: u32,
    /// Number of 32-bit words to copy.
    count_words: u32,
) void {
    assert((@intFromPtr(destination) & 3) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count_words], value);
    }
    else {
        memset32_thumb(@ptrCast(destination), value, count_words);
    }
}
