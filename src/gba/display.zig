const std = @import("std");
const gba = @import("gba.zig");
const display = @This();

// Window-related imports.
pub const Window = @import("display_window.zig").Window;
pub const window = @import("display_window.zig").window;

// Blending-related imports.
pub const Blend = @import("display_blend.zig").Blend;
pub const blend = @import("display_blend.zig").blend;

// Imports for types and definitions related to VRAM.
pub const vram = @import("display_vram.zig").vram;
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

// Palette-related imports.
pub const Palette = @import("display_palette.zig").Palette;
pub const bg_palette = @import("display_palette.zig").bg_palette;
pub const obj_palette = @import("display_palette.zig").obj_palette;
pub const memcpyBackgroundPalette = @import("display_palette.zig").memcpyBackgroundPalette;
pub const memcpyBackgroundPaletteBank = @import("display_palette.zig").memcpyBackgroundPaletteBank;
pub const memcpyObjectPalette = @import("display_palette.zig").memcpyObjectPalette;
pub const memcpyObjectPaletteBank = @import("display_palette.zig").memcpyObjectPaletteBank;

var current_page_addr: u32 = gba.mem.vram;

pub const back_page: [*]volatile u16 = @ptrFromInt(gba.mem.vram + 0xA000);

// TODO: Remove this (only `TextScreenBlock` is using this currently)
pub const Flip = packed struct(u2) {
    h: bool = false,
    v: bool = false,
};

fn pageSize() u17 {
    return switch (ctrl.mode) {
        .mode3 => gba.bitmap.Mode3.page_size,
        .mode4 => gba.bitmap.Mode4.page_size,
        .mode5 => gba.bitmap.Mode5.page_size,
        else => 0,
    };
}

// TODO: This might make more sense elsewhere
pub fn currentPage() []volatile u16 {
    return @as([*]u16, @ptrFromInt(current_page_addr))[0..pageSize()];
}

// TODO: This might make more sense elsewhere
pub fn pageFlip() void {
    switch (ctrl.mode) {
        .mode4, .mode5 => {
            current_page_addr ^= 0xA000;
            ctrl.page_select ^= 1;
        },
        else => {},
    }
}

pub const Priority = enum(u2) {
    highest = 0,
    high = 1,
    low = 2,
    lowest = 3,
};

/// Represents the contents of the display control register REG_DISPCNT.
pub const Control = packed struct(u16) {
    /// Controls the capabilities of background layers.
    /// Modes 0, 1, and 2 are tile modes.
    /// Modes 3, 4, and 5 are bitmap modes.
    pub const Mode = enum(u3) {
        /// Tiled mode.
        /// Provides four normal background layers (0-3)
        /// and no affine layers.
        mode0,
        /// Tiled mode.
        /// Provides two normal (0, 1) and one affine (2) background layer.
        mode1,
        /// Tiled mode.
        /// Provides two affine (2, 3) background layers
        /// and no normal non-affine layers.
        mode2,
        /// Bitmap mode.
        /// Provides a 16bpp full screen bitmap frame.
        mode3,
        /// Bitmap mode.
        /// Provides two 8bpp (256 color) frames.
        mode4,
        /// Bitmap mode.
        /// Provides two 16bpp 160x128 pixel frames.
        mode5,
    };
    
    pub const ObjMapping = enum(u1) {
        /// Tiles are stored in rows of 32 * 64 bytes.
        two_dimensions,
        /// Tiles are stored sequentially.
        one_dimension,
    };
    
    // TODO: Documentation
    
    mode: Mode = .mode0,
    /// Read only. Should stay false.
    gbc_mode: bool = false,
    page_select: u1 = 0,
    oam_access_in_hblank: bool = false,
    obj_mapping: ObjMapping = .two_dimensions,
    force_blank: bool = false,
    bg0: bool = false,
    bg1: bool = false,
    bg2: bool = false,
    bg3: bool = false,
    obj: bool = false,
    window_0: bool = false,
    window_1: bool = false,
    window_obj: bool = false,
};

/// Display control register. Corresponds to REG_DISPCNT.
pub const ctrl: *volatile display.Control = @ptrCast(gba.mem.io.reg_dispcnt);

/// Represents the contents of the display status register REG_DISPSTAT.
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
pub const status: *volatile display.Status = @ptrCast(gba.mem.io.reg_dispstat);

/// Indicates the currently drawn scanline. Read-only.
/// Corresponds to REG_VCOUNT.
/// Values range from 0 through 227. Values 160 through 227 indicate hidden
/// scanlines within the VBlank area.
pub const vcount: *align(2) const volatile u8 = @ptrCast(gba.mem.io.reg_vcount);

/// Wait until VBlank.
/// You probably want to enable interrupts and use
/// `gba.bios.vblankIntrWait` instead of this.
pub fn naiveVSync() void {
    while (vcount.* >= 160) {} // wait for VDraw
    while (vcount.* < 160) {} // wait for VBlank
}

/// Describes a mosaic effect.
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
