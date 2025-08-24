//! This module defines an interface for dealing with the system's VRAM, OAM,
//! palette memory, and graphics-related hardware registers.
//! These various things are used to control what should be displaying on
//! the GBA's screen.

const gba = @import("gba.zig");

// Background-related imports.
pub const BackgroundSize = @import("display_bg.zig").BackgroundSize;
pub const BackgroundControl = @import("display_bg.zig").BackgroundControl;
pub const bg_ctrl = @import("display_bg.zig").bg_ctrl;
pub const bg_scroll = @import("display_bg.zig").bg_scroll;
pub const bg_affine = @import("display_bg.zig").bg_affine;
pub const bg_2_affine = @import("display_bg.zig").bg_2_affine;
pub const bg_3_affine = @import("display_bg.zig").bg_3_affine;

// Imports related to bitmap graphics modes 3, 4, and 5.
pub const bitmap_buffers = @import("display_bitmap.zig").bitmap_buffers;
pub const mode3_width = @import("display_bitmap.zig").mode3_width;
pub const mode3_height = @import("display_bitmap.zig").mode3_height;
pub const mode3_size = @import("display_bitmap.zig").mode3_size;
pub const mode4_width = @import("display_bitmap.zig").mode4_width;
pub const mode4_height = @import("display_bitmap.zig").mode4_height;
pub const mode4_size = @import("display_bitmap.zig").mode4_size;
pub const mode5_width = @import("display_bitmap.zig").mode5_width;
pub const mode5_height = @import("display_bitmap.zig").mode5_height;
pub const mode5_size = @import("display_bitmap.zig").mode5_size;
pub const BitmapPair = @import("display_bitmap.zig").BitmapPair;
pub const Mode3Bitmap = @import("display_bitmap.zig").Mode3Bitmap;
pub const Mode4Bitmap = @import("display_bitmap.zig").Mode4Bitmap;
pub const Mode5Bitmap = @import("display_bitmap.zig").Mode5Bitmap;
pub const getMode3Bitmap = @import("display_bitmap.zig").getMode3Bitmap;
pub const getMode4Bitmap = @import("display_bitmap.zig").getMode4Bitmap;
pub const getMode5Bitmap = @import("display_bitmap.zig").getMode5Bitmap;
pub const getMode4Bitmaps = @import("display_bitmap.zig").getMode4Bitmaps;
pub const getMode5Bitmaps = @import("display_bitmap.zig").getMode5Bitmaps;

// Blending-related imports.
pub const Blend = @import("display_blend.zig").Blend;
pub const blend = @import("display_blend.zig").blend;

// Imports related to REG_DISPCNT.
pub const Mode = @import("display_ctrl.zig").Mode;
pub const Control = @import("display_ctrl.zig").Control;
pub const ctrl = @import("display_ctrl.zig").ctrl;

// Imports related to objects/sprites and OAM.
pub const objects = @import("display_object.zig").objects;
pub const hideAllObjects = @import("display_object.zig").hideAllObjects;
pub const oam_affine_values = @import("display_object.zig").oam_affine_values;
pub const setObjectTransform = @import("display_object.zig").setObjectTransform;
pub const Object = @import("display_object.zig").Object;

// Palette-related imports.
pub const Palette = @import("display_palette.zig").Palette;
pub const bg_palette = @import("display_palette.zig").bg_palette;
pub const obj_palette = @import("display_palette.zig").obj_palette;
pub const memcpyBackgroundPalette = @import("display_palette.zig").memcpyBackgroundPalette;
pub const memcpyBackgroundPaletteBank = @import("display_palette.zig").memcpyBackgroundPaletteBank;
pub const memcpyObjectPalette = @import("display_palette.zig").memcpyObjectPalette;
pub const memcpyObjectPaletteBank = @import("display_palette.zig").memcpyObjectPaletteBank;

// Imports for types and definitions related to VRAM.
pub const Screenblock = @import("display_vram.zig").Screenblock;
pub const BackgroundMap = @import("display_vram.zig").BackgroundMap;
pub const AffineBackgroundMap = @import("display_vram.zig").AffineBackgroundMap;
pub const Charblock = @import("display_vram.zig").Charblock;
pub const CharblockTiles = @import("display_vram.zig").CharblockTiles;
pub const BackgroundCharblockTiles = @import("display_vram.zig").BackgroundCharblockTiles;
pub const ObjectCharblockTiles = @import("display_vram.zig").ObjectCharblockTiles;
pub const screenblocks = @import("display_vram.zig").screenblocks;
pub const charblocks = @import("display_vram.zig").charblocks;
pub const charblock_tiles = @import("display_vram.zig").charblock_tiles;
pub const bg_charblocks = @import("display_vram.zig").bg_charblocks;
pub const bg_charblock_tiles = @import("display_vram.zig").bg_charblock_tiles;
pub const obj_charblocks = @import("display_vram.zig").obj_charblocks;
pub const obj_charblock_tiles = @import("display_vram.zig").obj_charblock_tiles;
pub const TileBpp = @import("display_vram.zig").TileBpp;
pub const Tile4Bpp = @import("display_vram.zig").Tile4Bpp;
pub const Tile8Bpp = @import("display_vram.zig").Tile8Bpp;
pub const memcpyTiles4Bpp = @import("display_vram.zig").memcpyTiles4Bpp;
pub const memcpyTiles8Bpp = @import("display_vram.zig").memcpyTiles8Bpp;
pub const memcpyBackgroundTiles4Bpp = @import("display_vram.zig").memcpyBackgroundTiles4Bpp;
pub const memcpyBackgroundTiles8Bpp = @import("display_vram.zig").memcpyBackgroundTiles8Bpp;
pub const memcpyObjectTiles4Bpp = @import("display_vram.zig").memcpyObjectTiles4Bpp;
pub const memcpyObjectTiles8Bpp = @import("display_vram.zig").memcpyObjectTiles8Bpp;

// Window-related imports.
pub const Window = @import("display_window.zig").Window;
pub const window = @import("display_window.zig").window;

/// Width of GBA video output, in pixels.
pub const screen_width = 240;

/// Height of GBA video output, in pixels.
pub const screen_height = 160;

/// Size of GBA video output in pixels, represented as a vector.
pub const screen_size: gba.math.Vec2U8 = (
    .init(screen_width, screen_height)
);

/// Width of GBA video output, in 8x8 pixel tiles.
pub const screen_width_tiles = 30;

/// Height of GBA video output, in 8x8 pixel tiles.
pub const screen_height_tiles = 20;

/// Size of GBA video output in tiles, represented as a vector.
pub const screen_size_tiles: gba.math.Vec2U8 = (
    .init(screen_width_tiles, screen_height_tiles)
);

/// Represents the structure of the display status register REG_DISPSTAT.
pub const Status = packed struct(u16) {
    /// Enumeration of possible states for VBlank and HBlank, per the
    /// `vblank` and `hblank` status flags.
    pub const Refresh = enum(u1) {
        draw = 0,
        blank = 1,
    };

    /// VBlank flag. Set inside VBlank, clear in VDraw.
    /// Set in line 160 to 226. Not set for line 227.
    /// Read-only.
    vblank: Refresh = .draw,
    /// HBlank flag. Set inside HBlank.
    /// Toggled in all lines, 0 to 227.
    /// Read-only.
    hblank: Refresh = .draw,
    /// VCount flag. Set when the current scanline matches the scanline
    /// trigger, i.e. REG_VCOUNT is equal to `vcount_select`.
    /// Read-only.
    vcount: bool = false,
    /// Enable VBlank interrupts.
    vblank_interrupt: bool = false,
    /// Enable HBlank interrupts.
    hblank_interrupt: bool = false,
    /// Enable VCount interrupts.
    /// An interrupt is triggered when REG_VCOUNT is equal to `vcount_select`.
    vcount_interrupt: bool = false,
    /// Unused bits.
    _: u2 = 0,
    /// VCount trigger value. If the current scanline matches this value,
    /// then `vcount` is set. If `vcount_interrupt` is true, then an interrupt
    /// is triggered as well.
    vcount_select: u8 = 0,
};

/// Display status register. Corresponds to REG_DISPSTAT.
pub const status: *volatile Status = @ptrCast(gba.mem.io.reg_dispstat);

/// Indicates the currently drawn scanline. Read-only.
/// Corresponds to REG_VCOUNT.
/// Values range from 0 through 227. Values 160 through 227 indicate hidden
/// scanlines within the VBlank area.
pub const vcount: *align(2) const volatile u8 = @ptrCast(gba.mem.io.reg_vcount);

/// This function runs in a loop until the next VBlank starts.
/// You probably want to enable interrupts and use
/// `gba.bios.vblankIntrWait` instead of this.
pub fn naiveVSync() void {
    while(vcount.* >= 160) {} // wait for VDraw
    while(vcount.* < 160) {} // wait for VBlank
}

/// Describes a mosaic effect.
/// Represents the structure of REG_MOSAIC.
pub const Mosaic = packed struct(u16) {
    /// Mosaic pixel size for backgrounds.
    /// The actual size in pixels will be `bg_size + 1`.
    bg_size: gba.math.Vec2(u4) = .zero,
    /// Mosaic pixel size for objects/sprites.
    /// The actual size in pixels will be `obj_size + 1`.
    obj_size: gba.math.Vec2(u4) = .zero,
};

/// Controls size of mosaic effects for backgrounds and sprites,
/// where they are active. Write-only.
/// Corresponds to REG_MOSAIC.
pub const mosaic: *volatile Mosaic = @ptrCast(gba.mem.io.reg_mosaic);
