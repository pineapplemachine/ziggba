const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Options accepted by `cpuSet`, pertaining to the `CpuSet` BIOS call.
pub const CpuSetOptions = packed struct(u32) {
    pub const Size = enum(u1) {
        /// Operate on 16-bit half-words.
        bits_16 = 0,
        /// Operate on 32-bit words.
        bits_32 = 1,
    };
    
    /// The number of words or half-words to write, depending on `size`.
    count: u21,
    /// Unused bits.
    _1: u3 = 0,
    /// Whether the write pointer should move with the read pointer,
    /// or whether the destination space should be filled with the value
    /// at `source[0]`.
    fixed: bool,
    /// Indicates whether to operate on 16-bit or 32-bit units.
    size: Size,
    /// Unused bits.
    _2: u6 = 0,
};

/// Options accepted by `cpuFastSet`, pertaining to the `CpuFastSet` BIOS call.
pub const CpuFastSetOptions = packed struct(u32) {
    /// The number of words to write.
    count: u21,
    /// Unused bits.
    _1: u3 = 0,
    /// Whether the write pointer should move with the read pointer,
    /// or whether the destination space should be filled with the value
    /// at `source[0]`.
    fixed: bool,
    /// Unused bits.
    _2: u7 = 0,
};

/// Wraps the system's `CpuSet` BIOS call.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn cpuSet(
    source: *align(2) const volatile anyopaque,
    destination: *align(2) volatile anyopaque,
    options: CpuSetOptions,
) void {
    assert(options.size == .bits_16 or (@intFromPtr(source) & 0x3 == 0));
    assert(options.size == .bits_16 or (@intFromPtr(destination) & 0x3 == 0));
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        const count = options.count << @intFromEnum(options.size);
        if(options.fixed) {
            @memset(destination[0..count], source[0]);
        }
        else {
            @memcpy(destination[0..count], source[0..count]);
        }
    }
    else {
        asm volatile (
            "swi 0x0b"
            :
            : [source] "{r0}" (source),
              [destination] "{r1}" (destination),
              [options] "{r2}" (options),
            : "r0", "r1", "r2", "cc", "memory"
        );
    }
}

/// Wraps the system's `CpuFastSet` BIOS call.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn cpuFastSet(
    source: *align(4) const volatile anyopaque,
    destination: *align(4) volatile anyopaque,
    options: CpuFastSetOptions,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        // CpuFastSet rounds up to a multiple of 8 words.
        const count_lsb = options.count & 0x7;
        const count = (options.count & 0x1ffff8) + @intFromBool(count_lsb != 0);
        if(options.fixed) {
            @memset(destination[0..count], source[0]);
        }
        else {
            @memcpy(destination[0..count], source[0..count]);
        }
    }
    else {
        asm volatile (
            "swi 0x0c"
            :
            : [source] "{r0}" (source),
              [destination] "{r1}" (destination),
              [options] "{r2}" (options),
            : "r0", "r1", "r2", "cc", "memory"
        );
    }
}

/// Copies 16-bit half-words from `source` to `destination`,
/// using the system's `CpuSet` BIOS call.
/// You can expect this to normally be slower than `gba.mem.memcpy16`.
pub inline fn cpuSetCopy16(
    source: *align(2) const volatile anyopaque,
    destination: *align(2) volatile anyopaque,
    count: u21,
) void {
    cpuSet(source, destination, .{
        .count = count,
        .size = .bits_16,
        .fixed = false,
    });
}

/// Copies 32-bit words from `source` to `destination`,
/// using the system's `CpuSet` BIOS call.
/// You can expect this to normally be slower than `gba.mem.memcpy32`.
pub inline fn cpuSetCopy32(
    source: *align(4) const volatile anyopaque,
    destination: *align(4) volatile anyopaque,
    count: u21,
) void {
    cpuSet(@ptrCast(source), @ptrCast(destination), .{
        .count = count,
        .size = .bits_32,
        .fixed = false,
    });
}

/// Fills half-words at `destination` with the value at `source`,
/// using the system's `CpuSet` BIOS call.
/// You can expect this to normally be slower than `gba.mem.memset16`.
pub inline fn cpuSetFill16(
    source: *align(2) const volatile anyopaque,
    destination: *align(2) volatile anyopaque,
    count: u21,
) void {
    cpuSet(source, destination, .{
        .count = count,
        .size = .bits_16,
        .fixed = true,
    });
}

/// Fills words at `destination` with the value at `source`,
/// using the system's `CpuSet` BIOS call.
/// You can expect this to normally be slower than `gba.mem.memset32`.
pub inline fn cpuSetFill32(
    source: *align(4) const volatile anyopaque,
    destination: *align(4) volatile anyopaque,
    count: u21,
) void {
    cpuSet(@ptrCast(source), @ptrCast(destination), .{
        .count = count,
        .size = .bits_32,
        .fixed = true,
    });
}

/// Copies data in chunks of 8 words/32 bytes from `source` into `destination`,
/// using the system's `CpuFastSet` BIOS call.
/// You can expect this to have very similar performance as `gba.mem.memcpy32`,
/// but this function is more limited in that it can only operate on word
/// counts that are multiples of 8.
pub inline fn cpuFastCopy32(
    source: *align(4) const volatile anyopaque,
    destination: *align(4) volatile anyopaque,
    count: u21,
) void {
    // If you really want to use `CpuFastSet` with its rounding-up behavior,
    // then call `gba.bios.cpuFastCopy` instead to bypass this check.
    assert((count & 0x7) == 0);
    cpuFastSet(source, destination, CpuFastSetOptions{
        .count = count,
        .fixed = false,
    });
}

/// Copies the value at `source` into `destination` in chunks of
/// 8 words/32 bytes, using the system's `CpuFastSet` BIOS call.
/// You can expect this to have very similar performance as `gba.mem.memset32`,
/// but this function is more limited in that it can only operate on word
/// counts that are multiples of 8.
pub inline fn cpuFastSet32(
    source: *align(4) const volatile anyopaque,
    destination: *align(4) volatile anyopaque,
    count: u21,
) void {
    // If you really want to use `CpuFastSet` with its rounding-up behavior,
    // then call `gba.bios.cpuFastCopy` instead to bypass this check.
    assert((count & 0x7) == 0);
    cpuFastSet(source, destination, CpuFastSetOptions{
        .count = count,
        .fixed = true,
    });
}
