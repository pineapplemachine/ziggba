const gba = @import("gba.zig");
const Color = gba.Color;
const display = gba.display;
const Priority = display.Priority;

const bg = @This();

/// Background size, in 8x8 tiles.
pub const Size = packed union {
    /// Represents possible sizes for normal (non-affine) backgrounds.
    pub const Normal = packed struct(u2) {
        /// 32 tiles wide and 32 tiles tall. Uses one screenblock.
        pub const size_32x32 = Size.Normal{ .x = .size_32, .y = .size_32 };
        /// 64 tiles wide and 32 tiles tall. Uses two screenblocks.
        pub const size_64x32 = Size.Normal{ .x = .size_64, .y = .size_32 };
        /// 32 tiles wide and 64 tiles tall. Uses two screenblocks.
        pub const size_32x64 = Size.Normal{ .x = .size_32, .y = .size_64 };
        /// 64 tiles wide and 64 tiles tall. Uses four screenblocks.
        pub const size_64x64 = Size.Normal{ .x = .size_64, .y = .size_64 };
        
        pub const Value = enum(u1) {
            size_32 = 0,
            size_64 = 1,
        };
        
        /// When 0, the background is 32 tiles wide. When 1, 64 tiles wide.
        x: Value,
        /// When 0, the background is 32 tiles tall. When 1, 64 tiles tall.
        y: Value,
    };

    /// Enumeration of possible sizes for affine backgrounds.
    /// Affine backgrounds are always square.
    pub const Affine = enum(u2) {
        /// 16 tiles wide and tall. Uses 256 bytes of one screenblock.
        size_16,
        /// 32 tiles wide and tall. Uses 1024 bytes (i.e. half) of one screenblock.
        size_32,
        /// 64 tiles wide and tall. Uses two screenblocks.
        size_64,
        /// 128 tiles wide and tall. Uses eight screenblocks.
        size_128,
    };

    /// Determines size for non-affine backgrounds.
    normal: Size.Normal,
    /// Determines size for affine backgrounds.
    /// Affine backgrounds are always square.
    affine: Size.Affine,
};

/// Represents the contents of REG_BGxCNT background control registers.
pub const Control = packed struct(u16) {
    /// Determines drawing order of the four backgrounds.
    priority: Priority = .highest,
    /// Sets the charblock that serves as the base for tile indexing.
    /// Only the first four of six charblocks may be used for backgrounds
    /// in this way.
    /// Actual address = VRAM_BASE_ADDR + (tile_addr * 0x4000)
    tile_base_block: u2 = 0,
    /// Unused bits.
    _: u2 = undefined,
    /// Enables mosaic effect. (Makes things appear blocky.)
    mosaic: bool = false,
    /// Which format to expect charblock tile data to be in, whether
    /// 4bpp or 8bpp paletted.
    /// Affine backgrounds always use 8bpp.
    palette_mode: Color.Bpp = .bpp_4,
    /// The screenblock that serves as the base for screen-entry/map indexing.
    /// Beware that screenblock memory is shared with charblock memory.
    /// Screenblocks 0-7 occupy the same memory as charblock 0,
    /// screenblocks 8-15 as charblock 1,
    /// screenblocks 16-23 as charblock 2, and
    /// screenblocks 24-31 as charblock 3.
    /// Each screenblock holds 1024 (32x32) tiles.
    /// Actual address = VRAM_BASE_ADDR + (obj_addr * 0x800)
    screen_base_block: u5 = 0,
    /// Whether affine backgrounds should wrap.
    /// Has no effect on normal backgrounds.
    affine_wrap: bool = false,
    /// Sizes differ depending on whether the background is affine.
    /// Larger sizes use more screenblocks.
    tile_map_size: Size = .{ .normal = .size_32x32 },
};

/// Background control registers for tile modes.
/// Corresponds to REG_BGxCNT.
///
/// Mode 0 - Normal: 0, 1, 2, 3
///
/// Mode 1 - Normal: 0, 1; Affine: 2
///
/// Mode 2 - Affine: 2, 3
pub const ctrl: *volatile [4]bg.Control = @ptrFromInt(gba.mem.io + 0x08);

/// Only the lowest 10 bits are used
pub const Scroll = packed struct {
    x: i16 = 0,
    y: i16 = 0,

    pub fn set(self: *volatile Scroll, x: i10, y: i10) void {
        self.* = .{ .x = x, .y = y };
    }
};

/// Controls background scroll. Values are modulo map size (wrapping is automatic)
///
/// These registers are write only.
pub const scroll: *[4]bg.Scroll = @ptrFromInt(gba.mem.io + 0x10);

pub const TextScreenEntry = packed struct(u16) {
    tile_index: u10 = 0,
    flip: display.Flip = .{},
    palette_index: u4 = 0,
};

// TODO: This is currently only used by the BIOS API
pub const Affine = extern struct {
    pa: gba.FixedI16R8 align(2) = gba.FixedI16R8.initInt(1),
    pb: gba.FixedI16R8 align(2) = .{},
    pc: gba.FixedI16R8 align(2) = .{},
    pd: gba.FixedI16R8 align(2) = gba.FixedI16R8.initInt(1),
    dx: gba.FixedI32R8 align(4) = .{},
    dy: gba.FixedI32R8 align(4) = .{},
};

/// An index to a color tile
pub const AffineScreenEntry = u8;

pub const TextScreenBlock = [1024]TextScreenEntry;
pub const screen_block_ram: [*]volatile TextScreenBlock = @ptrCast(display.vram);

pub inline fn screenBlockMap(block: u5) [*]volatile bg.TextScreenEntry {
    return @ptrCast(&screen_block_ram[block]);
}

/// Represents a displacement vector (also called a translation vector)
/// for use with affine backgrounds.
///
/// Note that the highest 4 bits of each component are not used.
pub const AffineDisplacement = extern struct {
    /// X displacement of an affine background.
    /// The highest 4 bits are ignored, meaning this behaves like a
    /// `FixedI28R8` in practice.
    x: gba.FixedI32R8 align(4) = .{},
    /// Y displacement of an affine background.
    /// The highest 4 bits are ignored, meaning this behaves like a
    /// `FixedI28R8` in practice.
    y: gba.FixedI32R8 align(4) = .{},
};

/// Holds an affine transformation matrix for background 2,
/// when in affine mode. (Mode 1 or Mode 2.)
/// Corresponds to REG_BG2PA, REG_BG2PB, REG_BG2PC, and REG_BG2PD.
pub const bg_2_affine: *volatile gba.obj.AffineTransform = @ptrFromInt(gba.mem.io + 0x20);

/// Holds a displacement/translation vector for background 2,
/// when in affine mode. (Mode 1 or Mode 2.)
/// Corresponds to REG_BG2X and REG_BG2Y.
pub const bg_2_affine_xy: *volatile AffineDisplacement = @ptrFromInt(gba.mem.io + 0x28);

/// Holds an affine transformation matrix for background 3,
/// when in affine mode. (Mode 2.)
/// Corresponds to REG_BG3PA, REG_BG3PB, REG_BG3PC, and REG_BG3PD.
pub const bg_3_affine: *volatile gba.obj.AffineTransform = @ptrFromInt(gba.mem.io + 0x20);

/// Holds a displacement/translation vector for background 3,
/// when in affine mode. (Mode 2.)
/// Corresponds to REG_BG3X and REG_BG3Y.
pub const bg_3_affine_xy: *volatile AffineDisplacement = @ptrFromInt(gba.mem.io + 0x38);
