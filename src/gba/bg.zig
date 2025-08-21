const gba = @import("gba.zig");

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
        x: Value = .size_32,
        /// When 0, the background is 32 tiles tall. When 1, 64 tiles tall.
        y: Value = .size_32,
        
        /// Get the number of screenblocks used by a background of this size.
        pub fn getScreenblockCount(self: Normal) u3 {
            return (@as(u3, @intFromEnum(self.x)) + 1) << @intFromEnum(self.y);
        }
    };

    /// Enumeration of possible sizes for affine backgrounds.
    /// Affine backgrounds are always square.
    pub const Affine = enum(u2) {
        /// 16 tiles wide and tall. Uses 256 bytes of one screenblock.
        size_16 = 0,
        /// 32 tiles wide and tall. Uses 1024 bytes (i.e. half) of one screenblock.
        size_32 = 1,
        /// 64 tiles wide and tall. Uses two screenblocks.
        size_64 = 2,
        /// 128 tiles wide and tall. Uses eight screenblocks.
        size_128 = 3,
        
        /// Get the number of screenblocks used by a background of this size.
        /// Note that `size_16` and `size_32` use only a part of one
        /// screenblock.
        pub fn getScreenblockCount(self: Normal) u4 {
            return switch(self) {
                .size_16 => 1,
                .size_32 => 1,
                .size_64 => 2,
                .size_128 => 8,
            };
        }
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
    priority: gba.display.Priority = .highest,
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
    bpp: gba.display.TileBpp = .bpp_4,
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
pub const ctrl: *volatile [4]Control = @ptrCast(gba.mem.io.reg_bgcnt);

/// Controls scrolling for normal (non-affine) backgrounds. Write-only.
/// Corresponds to REG_BG_OFS.
///
/// GBATEK documents that only the low nine bits of X and Y are used.
/// However, since normal backgrounds wrap and their width and height are
/// always evenly divisible into 512 pixels, there is not really a distinction.
pub const scroll: *[4]gba.math.Vec2I16 = @ptrCast(gba.mem.io.reg_bg_ofs);

// TODO: Cleanup TextScreenEntry etc.

pub const TextScreenEntry = packed struct(u16) {
    tile_index: u10 = 0,
    flip: gba.display.Flip = .{},
    palette_index: u4 = 0,
};

pub const TextScreenBlock = [1024]TextScreenEntry;
pub const screen_block_ram: [*]volatile TextScreenBlock = @ptrCast(gba.display.vram);

pub inline fn screenBlockMap(block: u5) [*]volatile TextScreenEntry {
    return @ptrCast(&screen_block_ram[block]);
}

/// Corresponds to REG_BG_AFFINE.
/// See `bg_2_affine` and `bg_3_affine`.
pub const bg_affine: *volatile [2]gba.math.Affine3x2 = (
    @ptrCast(gba.mem.io.reg_bg_affine)
);

/// Holds an affine transformation matrix with a displacement/translation
/// vector for background 2, when in affine mode. (Mode 1 or Mode 2.)
///
/// The `abcd` property corresponds to REG_BG2PA, REG_BG2PB, REG_BG2PC,
/// and REG_BG2PD.
/// The `disp` property corresponds to REG_BG2X and REG_BG2Y.
pub const bg_2_affine: *volatile gba.math.Affine3x2 = &bg_affine[0];

/// Holds an affine transformation matrix with a displacement/translation
/// vector for background 3, when in affine mode. (Mode 2.)
///
/// The `abcd` property corresponds to REG_BG3PA, REG_BG3PB, REG_BG3PC,
/// and REG_BG3PD.
/// The `disp` property corresponds to REG_BG3X and REG_BG3Y.
pub const bg_3_affine: *volatile gba.math.Affine3x2 = &bg_affine[1];
