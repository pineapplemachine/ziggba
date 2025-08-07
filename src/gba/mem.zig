//! Module for memory related functions and accesses

const isAligned = @import("std").mem.isAligned;
const gba = @import("gba.zig");

// TODO: Maybe make these volatile pointers to u8?
// Access to base addresses for memory regions. Intended mostly for internal use.
//
// If you find yourself reaching for these often, consider filing an issue with your use case.
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

// TODO: maybe put this in IWRAM ?
pub fn memcpy32(noalias dest: anytype, noalias source: anytype, count: usize) void {
    if (count < 4) {
        genericMemcpy(@ptrCast(dest), @ptrCast(source), count);
    } else if (isAligned(@intFromPtr(dest), 4) and isAligned(@intFromPtr(source), 4)) {
        alignedMemcpy(u32, @ptrCast(@alignCast(dest)), @ptrCast(@alignCast(source)), count);
    } else if (isAligned(@intFromPtr(dest), 2) and isAligned(@intFromPtr(source), 2)) {
        alignedMemcpy(u16, @ptrCast(@alignCast(dest)), @ptrCast(@alignCast(source)), count);
    } else {
        genericMemcpy(@ptrCast(dest), @ptrCast(source), count);
    }
}

pub fn memcpy16(noalias dest: anytype, noalias source: anytype, count: usize) void {
    if (count < 2) {
        genericMemcpy(@ptrCast(dest), @ptrCast(source), count);
    } else if (isAligned(@intFromPtr(dest), 2) and isAligned(@intFromPtr(source), 2)) {
        alignedMemcpy(u16, @ptrCast(@alignCast(dest)), @ptrCast(@alignCast(source)), count);
    } else {
        genericMemcpy(@ptrCast(dest), @ptrCast(source), count);
    }
}

pub fn alignedMemcpy(
    comptime T: type,
    noalias dest: [*]align(@alignOf(T)) volatile u8,
    noalias source: [*]align(@alignOf(T)) const u8,
    bytes: usize,
) void {
    @setRuntimeSafety(false);
    const aligned_count = bytes / @sizeOf(T);
    const rem_bytes = bytes % @sizeOf(T);

    const aligned_dest: [*]volatile T = @ptrCast(dest);
    const aligned_source: [*]const T = @ptrCast(source);

    for (0..aligned_count) |index| {
        aligned_dest[index] = aligned_source[index];
    }

    for (bytes - rem_bytes..bytes) |index| {
        dest[index] = source[index];
    }
}

pub fn genericMemcpy(
    noalias dest: [*]volatile u8,
    noalias source: [*]const u8,
    bytes: usize,
) void {
    @setRuntimeSafety(false);
    for (0..bytes) |index| {
        dest[index] = source[index];
    }
}

// TODO: maybe put it in IWRAM ?
pub fn memset32(dest: anytype, value: u32, bytes: usize) void {
    if (isAligned(@intFromPtr(dest), 4)) {
        alignedMemset(u32, @ptrCast(@alignCast(dest)), value, bytes);
    } else {
        genericMemset(u32, @ptrCast(dest), value, bytes);
    }
}

pub fn memset16(dest: anytype, value: u16, count: usize) void {
    if (isAligned(@intFromPtr(dest), 2)) {
        alignedMemset(u16, @ptrCast(@alignCast(dest)), value, count);
    } else {
        genericMemset(u16, @ptrCast(dest), value, count);
    }
}

pub fn alignedMemset(comptime T: type, dest: [*]align(@alignOf(T)) volatile u8, value: T, count: usize) void {
    @setRuntimeSafety(false);
    const aligned_dest: [*]volatile T = @ptrCast(dest);
    for (0..count) |index| {
        aligned_dest[index] = value;
    }
}

pub fn genericMemset(comptime T: type, destination: [*]volatile u8, value: T, count: usize) void {
    @setRuntimeSafety(false);
    const value_bytes: [*]const u8 = @ptrCast(&value);
    for (0..count) |index| {
        inline for (0..@sizeOf(T)) |byte| {
            destination[(index * @sizeOf(T)) + byte] = value_bytes[byte];
        }
    }
}
