//! Implements an API for dealing with background and object palettes.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Represents a 256-color palette, to be used with either backgrounds or
/// objects/sprites.
///
/// Depending on the settings for a background or object, it may either use
/// the corresponding palette as a single 256-color palette (8 bits per pixel)
/// or it may select a 16-color subset, called a "bank" (4 bits per pixel).
pub const Palette = extern union {
    /// A palette of 16 colors.
    /// The color at `bank[0]` is always transparent.
    pub const Bank = [16]gba.Color;

    /// Array of palette banks. Relevant for 4bpp graphics.
    /// The first color of each bank is always treated as transparent.
    banks: [16]Bank,
    /// Full palette of 256 colors. Relevant for 8bpp graphics.
    /// The first color, `colors[0]`, is treated as transparent.
    /// It is also used as the backdrop color, when no opaque pixels are
    /// drawn at a screen position.
    colors: [256]gba.Color,
};

/// Palette used for backgrounds.
pub const bg_palette: *volatile Palette = @ptrFromInt(gba.mem.palette);

/// Palette used for objects/sprites.
pub const obj_palette: *volatile Palette = @ptrFromInt(gba.mem.palette + 0x200);

/// Copy memory into the background palette.
pub fn memcpyBackgroundPalette(
    /// Offset, in colors. (Each palette color uses 16 bytes.)
    color_offset: u8,
    /// Pointer to color data that should be copied into palette memory.
    data: []align(2) const gba.Color,
) void {
    assert(color_offset + data.len <= bg_palette.colors.len);
    gba.mem.memcpy16(&bg_palette.colors[color_offset], data.ptr, data.len);
}

/// Copy memory into the background palette.
pub inline fn memcpyBackgroundPaletteBank(
    /// Copy color data into this bank, 0-15.
    bank: u4,
    /// Offset, in colors. (Each palette color uses 16 bytes.)
    color_offset: u8,
    /// Pointer to color data that should be copied into palette memory.
    data: []align(2) const gba.Color,
) void {
    const offset = color_offset + (@as(u8, bank) << 5);
    assert(offset + data.len <= bg_palette.colors.len);
    memcpyBackgroundPalette(offset, data);
}

/// Copy memory into the object palette.
pub fn memcpyObjectPalette(
    /// Offset, in colors. (Each palette color uses 16 bytes.)
    color_offset: u8,
    /// Pointer to color data that should be copied into palette memory.
    data: []align(2) const gba.Color,
) void {
    assert(color_offset + data.len <= obj_palette.colors.len);
    gba.mem.memcpy16(&obj_palette.colors[color_offset], data.ptr, data.len);
}

/// Copy memory into the object palette.
pub inline fn memcpyObjectPaletteBank(
    /// Copy color data into this bank, 0-15.
    bank: u4,
    /// Offset, in colors. (Each palette color uses 16 bytes.)
    color_offset: u8,
    /// Pointer to color data that should be copied into palette memory.
    data: []align(2) const gba.Color,
) void {
    const offset = color_offset + (@as(u8, bank) << 5);
    assert(offset + data.len <= obj_palette.colors.len);
    memcpyObjectPalette(offset, data);
}
