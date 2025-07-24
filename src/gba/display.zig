const std = @import("std");
const gba = @import("gba.zig");
const Color = gba.Color;
const display = @This();

pub const window = @import("display_window.zig");

pub const vram = @import("display_vram.zig").vram;
pub const ScreenblockEntry = @import("display_vram.zig").ScreenblockEntry;
pub const Screenblock = @import("display_vram.zig").Screenblock;
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
pub const Tile4Bpp = @import("display_vram.zig").Tile4Bpp;
pub const Tile8Bpp = @import("display_vram.zig").Tile8Bpp;
pub const memcpyTiles4Bpp = @import("display_vram.zig").memcpyTiles4Bpp;
pub const memcpyTiles8Bpp = @import("display_vram.zig").memcpyTiles8Bpp;
pub const memcpyBackgroundTiles4Bpp = @import("display_vram.zig").memcpyBackgroundTiles4Bpp;
pub const memcpyBackgroundTiles8Bpp = @import("display_vram.zig").memcpyBackgroundTiles8Bpp;
pub const memcpyObjectTiles4Bpp = @import("display_vram.zig").memcpyObjectTiles4Bpp;
pub const memcpyObjectTiles8Bpp = @import("display_vram.zig").memcpyObjectTiles8Bpp;

pub const Palette = @import("display_palette.zig").Palette;
pub const bg_palette = @import("display_palette.zig").bg_palette;
pub const obj_palette = @import("display_palette.zig").obj_palette;
pub const memcpyBackgroundPalette = @import("display_palette.zig").memcpyBackgroundPalette;
pub const memcpyBackgroundPaletteBank = @import("display_palette.zig").memcpyBackgroundPaletteBank;
pub const memcpyObjectPalette = @import("display_palette.zig").memcpyObjectPalette;
pub const memcpyObjectPaletteBank = @import("display_palette.zig").memcpyObjectPaletteBank;

var current_page_addr: u32 = gba.mem.vram;

pub const back_page: [*]volatile u16 = @ptrFromInt(gba.mem.vram + 0xA000);

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

pub const ObjMapping = enum(u1) {
    /// Tiles are stored in rows of 32 * 64 bytes
    two_dimensions,
    /// Tiles are stored sequentially
    one_dimension,
};

pub const Priority = enum(u2) {
    highest,
    high,
    low,
    lowest,
};

pub const Control = packed struct(u16) {
    /// Controls the capabilities of background layers
    ///
    /// Modes 0-2 are tile modes, modes 3-5 are bitmap modes
    pub const Mode = enum(u3) {
        /// Tiled mode
        ///
        /// Provides 4 normal background layers (0-3)
        mode0,
        /// Tiled mode
        ///
        /// Provides 2 normal (0, 1) and one affine (2) background layer
        mode1,
        /// Tiled mode
        ///
        /// Provides 2 affine (2, 3) background layers
        mode2,
        /// Bitmap mode
        ///
        /// Provides a 16bpp full screen bitmap frame
        mode3,
        /// Bitmap mode
        ///
        /// Provides two 8bpp (256 color palette) frames
        mode4,
        /// Bitmap mode
        ///
        /// Provides two 16bpp 160x128 pixel frames
        mode5,
    };
    
    mode: Mode = .mode0,
    /// Read only, should stay false
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

/// Display Control Register
///
/// (`REG_DISPCNT`)
pub const ctrl: *volatile display.Control = @ptrFromInt(gba.mem.io);

pub const RefreshState = enum(u1) {
    draw,
    blank,
};

pub const Status = packed struct(u16) {
    /// Read only
    v_refresh: RefreshState,
    /// Read only
    h_refresh: RefreshState,
    /// Read only
    vcount_triggered: bool,
    vblank_irq: bool = false,
    hblank_irq: bool = false,
    vcount_trigger: bool = false,
    _: u2 = 0,
    vcount_trigger_at: u8 = 0,
};

/// Display Status Register
///
/// (`REG_DISPSTAT`)
pub const status: *volatile display.Status = @ptrFromInt(gba.mem.io + 0x04);

/// Current y location of the LCD hardware
///
/// (`REG_VCOUNT`)
pub const vcount: *align(2) const volatile u8 = @ptrFromInt(gba.mem.io + 0x06);

/// Wait until VBlank.
/// You probably want to use `gba.bios.waitVBlank` instead of this.
pub fn naiveVSync() void {
    while (vcount.* >= 160) {} // wait till VDraw
    while (vcount.* < 160) {} // wait till VBlank
}

/// Describes a mosaic effect
pub const Mosaic = packed struct(u16) {
    pub const Size = packed struct(u8) {
        x: u4 = 0,
        y: u4 = 0,
    };

    bg: Mosaic.Size = .{},
    sprite: Mosaic.Size = .{},
};

/// Controls size of mosaic effects for backgrounds and sprites where it is active
///
/// (`REG_MOSAIC`)
pub const mosaic: *volatile Mosaic = @ptrFromInt(gba.mem.io + 0x4C);

// TODO: One struct per hardware register
/// Represents the contents of REG_BLDCNT, REG_BLDALPHA, and REG_BLDY.
pub const Blend = packed struct(u48) {
    pub const Layers = packed struct(u6) {
        bg0: bool = false,
        bg1: bool = false,
        bg2: bool = false,
        bg3: bool = false,
        obj: bool = false,
        backdrop: bool = false,
    };

    /// Enumeration of blending modes.
    pub const Mode = enum(u2) {
        /// No blending. Blending effects are disabled.
        none,
        /// Blend A and B layers.
        blend,
        /// Blend A with white.
        white,
        /// Blend A with black.
        black,
    };

    /// Select target layers for blend A.
    a: Blend.Layers,
    /// Determines blending behavior.
    mode: Blend.Mode,
    /// Select target layers for blend B.
    b: Blend.Layers,
    /// Blend weight for blend A. Clamped to a maximum of 16.
    ev_a: u5,
    /// Unused bits.
    _0: u3,
    /// Blend weight for blend B. Clamped to a maximum of 16.
    /// Used as a ratio with `ev_a` when `mode` is `Mode.blend`.
    ev_b: u5,
    /// Unused bits.
    _1: u3,
    /// Blend weight for white or black. Clamped to a maximum of 16.
    /// Used as a ratio with `ev_a` when `mode` is `Mode.white` or
    /// `Mode.black`.
    ///
    /// Write-only.
    ev_y: u5,
    /// Unused bits.
    _2: u27,
};

/// Controls for alpha blending.
/// Corresponds to REG_BLDCNT, REG_BLDALPHA, and REG_BLDY.
pub const blend: *volatile Blend = @ptrFromInt(gba.mem.io + 0x50);
