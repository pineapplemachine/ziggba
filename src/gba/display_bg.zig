const gba = @import("gba.zig");

/// Background size, in 8x8 tiles.
pub const BackgroundSize = packed union {
    /// Represents possible sizes for normal (non-affine) backgrounds.
    pub const Normal = packed struct(u2) {
        /// 32 tiles wide and 32 tiles tall. Uses one screenblock.
        pub const size_32x32 = (
            BackgroundSize.Normal{ .x = .size_32, .y = .size_32 }
        );
        /// 64 tiles wide and 32 tiles tall. Uses two screenblocks.
        pub const size_64x32 = (
            BackgroundSize.Normal{ .x = .size_64, .y = .size_32 }
        );
        /// 32 tiles wide and 64 tiles tall. Uses two screenblocks.
        pub const size_32x64 = (
            BackgroundSize.Normal{ .x = .size_32, .y = .size_64 }
        );
        /// 64 tiles wide and 64 tiles tall. Uses four screenblocks.
        pub const size_64x64 = (
            BackgroundSize.Normal{ .x = .size_64, .y = .size_64 }
        );
        
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
        /// 16 tiles wide and tall.
        /// Uses 256 bytes of one screenblock.
        size_16 = 0,
        /// 32 tiles wide and tall.
        /// Uses 1024 bytes (i.e. half) of one screenblock.
        size_32 = 1,
        /// 64 tiles wide and tall.
        /// Uses two screenblocks.
        size_64 = 2,
        /// 128 tiles wide and tall.
        /// Uses eight screenblocks.
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
    
    /// Size option for normal (non-affine) backgrounds.
    /// 32 tiles wide and 32 tiles tall. Uses one screenblock.
    pub const normal_32x32: BackgroundSize = .{ .normal = Normal.size_32x32 };
    /// Size option for normal (non-affine) backgrounds.
    /// 64 tiles wide and 32 tiles tall. Uses two screenblocks.
    pub const normal_64x32: BackgroundSize = .{ .normal = Normal.size_64x32 };
    /// Size option for normal (non-affine) backgrounds.
    /// 32 tiles wide and 64 tiles tall. Uses two screenblocks.
    pub const normal_32x64: BackgroundSize = .{ .normal = Normal.size_32x64 };
    /// Size option for normal (non-affine) backgrounds.
    /// 64 tiles wide and 64 tiles tall. Uses four screenblocks.
    pub const normal_64x64: BackgroundSize = .{ .normal = Normal.size_64x64 };
    /// Size option for affine backgrounds.
    /// 16 tiles wide and tall. Uses 256 bytes of one screenblock.
    pub const affine_16: BackgroundSize = .{ .affine = .size_16 };
    /// Size option for affine backgrounds.
    /// 32 tiles wide and tall. Uses 1024 bytes (i.e. half) of one screenblock.
    pub const affine_32: BackgroundSize = .{ .affine = .size_32 };
    /// Size option for affine backgrounds.
    /// 64 tiles wide and tall. Uses two screenblocks.
    pub const affine_64: BackgroundSize = .{ .affine = .size_64 };
    /// Size option for affine backgrounds.
    /// 128 tiles wide and tall. Uses eight screenblocks.
    pub const affine_128: BackgroundSize = .{ .affine = .size_128 };

    /// Determines size for non-affine backgrounds.
    normal: Normal,
    /// Determines size for affine backgrounds.
    /// Affine backgrounds are always square.
    affine: Affine,
    
    /// Initialize for a normal (non-affine) background.
    pub fn init(size_normal: Normal) BackgroundSize {
        return .{ .normal = size_normal };
    }
    
    /// Initialize for an affine background.
    pub fn initAffine(size_affine: Affine) BackgroundSize {
        return .{ .affine = size_affine };
    }
};

/// Represents the structure of REG_BGxCNT background control registers.
///
/// Whether a background is normal or affine is determined by
/// `gba.display.ctrl.mode`.
///
/// Beware that screenblock memory is shared with charblock memory.
/// Screenblocks 0-7 occupy the same memory as charblock 0,
/// screenblocks 8-15 as charblock 1,
/// screenblocks 16-23 as charblock 2, and
/// screenblocks 24-31 as charblock 3.
pub const BackgroundControl = packed struct(u16) {
    /// Determines drawing order relative to objects/sprites and other
    /// backgrounds.
    ///
    /// Items with a greater priority value are drawn first, and items
    /// with a lower value are then drawn on top.
    /// When a background and an object have the same priority value,
    /// the background is drawn first and the object is drawn on top.
    /// When priority is equal, background 3 draws on top of background 2,
    /// which draws on top of background 1, which draws on top of background 0.
    priority: u2 = 0,
    /// Determines the charblock that serves as the base for tile indexing.
    /// Each charblock contains 512 4bpp tiles or 256 8bpp tiles.
    /// Beware that charblock memory is shared with screenblock memory.
    ///
    /// Only the first four of the system's six charblocks may be used for
    /// backgrounds in this way. The last two are reserved for objects/sprites.
    base_charblock: u2 = 0,
    /// Unused bits.
    _: u2 = undefined,
    /// Enables mosaic effect. (Makes things appear blocky.)
    mosaic: bool = false,
    /// Which format to expect charblock tile data to be in, whether
    /// 4bpp or 8bpp paletted.
    /// Affine backgrounds always use 8bpp.
    bpp: gba.display.TileBpp = .bpp_4,
    /// Index of the first screenblock containing tilemap data for a background.
    /// Each screenblock holds 1024 (32x32) tiles for a normal (non-affine) map
    /// or 2048 tiles for an affine map.
    /// Beware that screenblock memory is shared with charblock memory.
    base_screenblock: u5 = 0,
    /// Whether affine backgrounds should wrap.
    /// Has no effect on normal backgrounds.
    affine_wrap: bool = false,
    /// Determines the size of the background.
    /// Size values differ depending on whether the background is affine or not.
    /// Larger sizes use more screenblocks.
    size: BackgroundSize = .normal_32x32,
    
    /// Options relevant to initializing for a normal (non-affine) background.
    /// These options are accepted by the `init` function.
    pub const InitOptions = struct {
        /// Determines drawing order relative to objects/sprites and other
        /// backgrounds.
        priority: u2 = 0,
        /// Determines the charblock that serves as the base for tile indexing.
        base_charblock: u2 = 0,
        /// Enables mosaic effect. (Makes things appear blocky.)
        mosaic: bool = false,
        /// Which format to expect charblock tile data to be in, whether
        /// 4bpp or 8bpp paletted.
        bpp: gba.display.TileBpp = .bpp_4,
        /// Index of the first screenblock containing tilemap data for a background.
        base_screenblock: u5 = 0,
        /// Determines the size of the background.
        size: BackgroundSize.Normal = .size_32x32,
    };
    
    /// Options relevant to initializing for an affine background.
    /// These options are accepted by the `initAffine` function.
    pub const InitAffineOptions = struct {
        /// Determines drawing order relative to objects/sprites and other
        /// backgrounds.
        priority: u2 = 0,
        /// Determines the charblock that serves as the base for tile indexing.
        base_charblock: u2 = 0,
        /// Enables mosaic effect. (Makes things appear blocky.)
        mosaic: bool = false,
        /// Index of the first screenblock containing tilemap data for a background.
        base_screenblock: u5 = 0,
        /// Whether affine backgrounds should wrap.
        affine_wrap: bool = false,
        /// Determines the size of the background.
        size: BackgroundSize.Affine = .size_16,
    };
    
    /// Initialize for a normal (non-affine) background.
    pub fn init(options: InitOptions) BackgroundControl {
        return .{
            .priority = options.priority,
            .base_charblock = options.base_charblock,
            .mosaic = options.mosaic,
            .bpp = options.bpp,
            .base_screenblock = options.base_screenblock,
            .size = .init(options.size),
        };
    }
    
    /// Initialize for an affine background.
    pub fn initAffine(options: InitAffineOptions) BackgroundControl {
        return .{
            .priority = options.priority,
            .base_charblock = options.base_charblock,
            .mosaic = options.mosaic,
            .bpp = .bpp_8,
            .base_screenblock = options.base_screenblock,
            .affine_wrap = options.affine_wrap,
            .size = .initAffine(options.size),
        };
    }
};

/// Background control registers. Corresponds to REG_BGCNT.
pub const bg_ctrl: *volatile [4]BackgroundControl = @ptrCast(gba.mem.io.reg_bgcnt);

/// Controls scrolling for normal (non-affine) backgrounds. Write-only.
/// Corresponds to REG_BG_OFS.
///
/// GBATEK documents that only the low nine bits of X and Y are used.
/// However, since normal backgrounds wrap and their width and height are
/// always evenly divisible into 512 pixels, there is not really a distinction.
pub const bg_scroll: *volatile [4]gba.math.Vec2I16 = @ptrCast(gba.mem.io.reg_bg_ofs);

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
