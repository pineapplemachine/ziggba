//! Module for memory related functions and accesses

const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

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

// These functions are implemented in assembly in `mem.s`.
extern fn memcpy_thumb(dst: [*]volatile u8, src: [*]const volatile u8, n: u32) callconv(.c) void;
extern fn memcpy16_thumb(dst: [*]volatile u16, src: [*]const volatile u16, n: u32) callconv(.c) void;
extern fn memcpy32_thumb(dst: [*]volatile u32, src: [*]const volatile u32, n: u32) callconv(.c) void;
extern fn memset_thumb(dst: [*]volatile u8, src: u8, n: u32) callconv(.c) void;
extern fn memset16_thumb(dst: [*]volatile u16, src: u16, n: u32) callconv(.c) void;
extern fn memset32_thumb(dst: [*]volatile u32, src: u32, n: u32) callconv(.c) void;

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
    destination: [*]volatile u8,
    /// Read memory from here.
    source: [*]const volatile u8,
    /// Number of bytes to copy.
    count: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count], source[0..count]);
    }
    else {
        memcpy_thumb(destination, source, count);
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
    destination: [*]volatile u16,
    /// Read memory from here. Must be half-word-aligned.
    source: [*]const volatile u16,
    /// Number of 16-bit half words to copy.
    count: u32,
) void {
    assert((@intFromPtr(source) & 1) == 0); // Check alignment
    assert((@intFromPtr(destination) & 1) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count], source[0..count]);
    }
    else {
        memcpy16_thumb(destination, source, count);
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
    destination: [*]volatile u32,
    /// Read memory from here. Must be word-aligned.
    source: [*]const volatile u32,
    /// Number of 32-bit words to copy.
    count: u32,
) void {
    assert((@intFromPtr(source) & 3) == 0); // Check alignment
    assert((@intFromPtr(destination) & 3) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memcpy(destination[0..count], source[0..count]);
    }
    else {
        memcpy32_thumb(destination, source, count);
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
    destination: [*]volatile u8,
    /// Value to store in the destination buffer.
    value: u8,
    /// Number of bytes to copy.
    count: u32,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count], value);
    }
    else {
        memset_thumb(destination, value, count);
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
    destination: [*]volatile u16,
    /// Value to store in the destination buffer.
    value: u16,
    /// Number of 16-bit half words to copy.
    count: u32,
) void {
    assert((@intFromPtr(destination) & 1) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count], value);
    }
    else {
        memset16_thumb(destination, value, count);
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
    destination: [*]volatile u32,
    /// Value to store in the destination buffer.
    value: u32,
    /// Number of 32-bit words to copy.
    count: u32,
) void {
    assert((@intFromPtr(destination) & 3) == 0); // Check alignment
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        @memset(destination[0..count], value);
    }
    else {
        memset32_thumb(destination, value, count);
    }
}
