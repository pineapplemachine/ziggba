const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");

/// Data header preceding any compressed or encoded data which should be
/// handled by a BIOS UnComp function.
pub const UnCompHeader = packed struct(u32) {
    pub const Type = enum(u4) {
        /// Data is compressed using LZ77 encoding.
        /// Indicates that data should be decompressed using `lz77UnCompWRAM` or
        /// `lz77UnCompVRAM`, depending on the destination in memory.
        lz77 = 1,
        /// Data is compressed using Huffman encoding.
        /// Indicates that data should be decompressed using `huffUnComp`.
        huff = 2,
        /// Data is compressed using run-length encoding.
        /// Indicates that data should be decompressed using `rlUnCompWRAM` or
        /// `rlUnCompVRAM`, depending on the destination in memory.
        rl = 3,
        /// Data is encoded as filtered deltas.
        /// Indicates that data should be handled using `diff8bitUnFilterWRAM`,
        /// `diff8bitUnFilterVRAM`, or `diff16bitUnFilter`.
        diff = 8,
    };
    
    /// The `diff8bitUnFilterWRAM` and `diff8bitUnFilterVRAM` functions
    /// expect this `size` value.
    pub const size_diff_bits_8: u4 = 1;
    /// The `diff16bitUnFilter` function expects this `size` value.
    pub const size_diff_bits_16: u4 = 2;
    
    /// Data size.
    /// Acceptable values vary depending on `type`.
    ///
    /// - `Type.lz77`: Unused.
    /// - `Type.huff`: Normally 4 or 8.
    /// - `Type.rl`: Unused.
    /// - `Type.diff`: Either `size_diff_bits_8` or `size_diff_bits_16`.
    size: u4 = 0,
    /// Indicates how the data should be decompressed.
    type: Type,
    /// Size of decompressed data, in bytes.
    len: u24,
};

/// Options recognized by the `bitUnPack` function.
pub const BitUnPackOptions = extern struct {
    /// Width in bits of values to be read from the source data.
    pub const SourceWidth = enum(u8) {
        bits_1 = 0,
        bits_2 = 2,
        bits_4 = 4,
        bits_8 = 8,
    };
    
    /// Width in bits of values to be written to the destination.
    pub const DestinationWidth = enum(u8) {
        bits_1 = 0,
        bits_2 = 2,
        bits_4 = 4,
        bits_8 = 8,
        bits_16 = 16,
        bits_32 = 32,
    };
    
    /// Length of source data, in bytes.
    src_len: u16,
    /// Width of values to read from source data, in bits.
    src_width: SourceWidth,
    /// Width of values to write to the destination, in bits.
    dest_width: DestinationWidth,
    /// An offset added to unpacked values.
    /// If `offset_zero` is set, then this offset is added to all source values.
    /// Otherwise, it's added only to non-zero values.
    offset: u31,
    /// Whether `offset` should be added to zero values.
    offset_zero: bool,
};

/// Copy data while changing bit depth.
/// Wraps a `BitUnPack` BIOS call.
pub fn bitUnPack(
    source: []const u8,
    destination: *align(4) const anyopaque,
    options: *const BitUnPackOptions,
) void {
    asm volatile (
        "swi 0x10"
        :
        : [source] "{r0}" (source),
          [destination] "{r1}" (destination),
          [options] "{r2}" (options),
        : "r0", "r1", "r2", "r3", "cc", "memory"
    );
}

/// Common helper for implementing UnComp BIOS calls.
inline fn unComp(
    comptime assembly: []const u8,
    source: [*]const volatile anyopaque,
    destination: [*]volatile anyopaque,
) void {
    asm volatile (
        assembly
        :
        : [source] "{r0}" (source),
          [destination] "{r1}" (destination),
        : "r0", "r1", "r3", "cc", "memory"
    );
}

/// Inflate LZ77 compressed data.
/// Writes one byte at a time to the destination.
/// Faster than `lz77UnCompVRAM`, but not suitable for writing into VRAM.
/// Wraps a `LZ77UnCompWRAM` BIOS call.
pub fn lz77UnCompWRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *anyopaque,
) void {
    unComp("swi 0x11", source, destination);
}

/// Inflate LZ77 compressed data.
/// Writes two bytes at a time to the destination.
/// Slower than `lz77UnCompWRAM`.
/// Wraps a `LZ77UnCompWRAM` BIOS call.
pub fn lz77UnCompVRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *align(2) anyopaque,
) void {
    unComp("swi 0x12", source, destination);
}

/// Inflate Huffman compressed data.
/// Wraps a `HuffUnComp` BIOS call.
pub fn huffUnComp(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *anyopaque,
) void {
    unComp("swi 0x13", source, destination);
}

/// Inflate run-length compressed data.
/// Writes one byte at a time to the destination.
/// Faster than `rlUnCompVRAM`, but not suitable for writing into VRAM.
/// Wraps a `RLUnCompWRAM` BIOS call.
pub fn rlUnCompWRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *anyopaque,
) void {
    unComp("swi 0x14", source, destination);
}

/// Inflate run-length compressed data.
/// Writes two bytes at a time to the destination.
/// Slower than `rlUnCompWRAM`.
/// Wraps a `RLUnCompVRAM` BIOS call.
pub fn rlUnCompVRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *align(2) anyopaque,
) void {
    unComp("swi 0x15", source, destination);
}

/// Writes one byte at a time to the destination.
/// Faster than `diff8bitUnFilterVRAM`, but not suitable for writing into VRAM.
/// Wraps a `Diff8bitUnFilterWRAM` BIOS call.
pub fn diff8bitUnFilterWRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *anyopaque,
) void {
    unComp("swi 0x16", source, destination);
}

/// Writes two bytes at a time to the destination.
/// Slower than `diff8bitUnFilterWRAM`.
/// Wraps a `Diff8bitUnFilterVRAM` BIOS call.
pub fn diff8bitUnFilterVRAM(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *anyopaque,
) void {
    unComp("swi 0x17", source, destination);
}

/// Wraps a `Diff16bitUnFilter` BIOS call.
pub fn diff16bitUnFilter(
    /// Pointer to source data, which must begin with an `UnCompHeader`.
    source: *const UnCompHeader,
    /// Write decompressed output here.
    destination: *align(2) anyopaque,
) void {
    unComp("swi 0x18", source, destination);
}
