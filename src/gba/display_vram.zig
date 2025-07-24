//! This module contains definitions related to tiles and charbanks.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Pointer to the system's VRAM.
pub const vram: [*]volatile align(2) u16 = @ptrFromInt(gba.mem.vram);

/// Describes a tile within a background.
pub const ScreenblockEntry = packed struct(u16) {
    /// Offset added to a background's `tile_base_block` to determine the
    /// tile that should be displayed.
    tile_index: u10 = 0,
    /// Display the tile flipped horizontally.
    flip_x: bool = false,
    /// Display the tile flipped vertically.
    flip_y: bool = false,
    /// Palette bank to use for the tile, when in 16-color mode.
    /// Has no effect for 256-color 8bpp backgrounds.
    palette_index: u4 = 0,
};

/// Holds data for 32x32 background tiles.
/// A background can use one or more screenblocks.
pub const Screenblock = extern struct {
    entries: [1024]ScreenblockEntry,
    
    /// Get tile data at a given coordinate within the single screenblock.
    pub fn getEntry(self: Screenblock, x: u5, y: u5) ScreenblockEntry {
        return self.entries[x + (@as(u16, y) << 5)];
    }
    
    /// Set tile data at a given coordinate within the single screenblock.
    pub fn setEntry(self: *Screenblock, x: u5, y: u5, entry: ScreenblockEntry) void {
        self.entries[x + (@as(u16, y) << 5)] = entry;
    }
};

// TODO: Types to access entries in backgrounds made of multiple screenblocks

/// The GBA's background and object tiles are found in "charblocks" in VRAM,
/// which are blocks of either 512 16-color tiles or 256 256-color tiles each.
///
/// The system has six charblocks total. The first four are used for
/// backgrounds, and the final two are used for objects/sprites.
pub const Charblock = extern union {
    /// Provides access to charblock data as 16-color 4bpp tiles.
    bpp_4: [512]Tile4Bpp,
    /// Provides access to charblock data as 256-color 8bpp tiles.
    bpp_8: [256]Tile8Bpp,
    /// Background charblocks and screenblocks share the same VRAM.
    screenblocks: [8]Screenblock,
};

pub const CharblockTiles = extern union {
    /// Provides access to charblock data as 16-color 4bpp tiles.
    bpp_4: [3072]Tile4Bpp,
    /// Provides access to charblock data as 256-color 8bpp tiles.
    bpp_8: [1536]Tile8Bpp,
    /// Background charblocks and screenblocks share the same VRAM.
    screenblocks: [32]Screenblock,
};

pub const BackgroundCharblockTiles = extern union {
    /// Provides access to charblock data as 16-color 4bpp tiles.
    bpp_4: [2048]Tile4Bpp,
    /// Provides access to charblock data as 256-color 8bpp tiles.
    bpp_8: [1024]Tile8Bpp,
    /// Background charblocks and screenblocks share the same VRAM.
    screenblocks: [32]Screenblock,
};

pub const ObjectCharblockTiles = extern union {
    bpp_4: [1024]Tile4Bpp,
    bpp_8: [512]Tile8Bpp,
};

/// Represents all 32 screenblocks in VRAM.
pub const screenblocks: *volatile [32]Screenblock = @ptrFromInt(gba.mem.vram);

/// Represents all six charblocks in VRAM.
pub const charblocks: *volatile [6]Charblock = @ptrFromInt(gba.mem.vram);

/// Represents the tiles of all six charblocks in VRAM as one flat array.
pub const charblock_tiles: *volatile CharblockTiles(6) = @ptrFromInt(gba.mem.vram);

/// Represents the four charblocks in VRAM that can be used in backgrounds.
pub const bg_charblocks: *volatile [4]Charblock = @ptrFromInt(gba.mem.vram);

/// Represents the tiles of the charblocks usable with backgrounds.
pub const bg_charblock_tiles: *volatile BackgroundCharblockTiles = @ptrFromInt(gba.mem.vram);

/// Represents the two charblocks in VRAM that can be used in objects.
pub const obj_charblocks: *volatile [2]Charblock = @ptrFromInt(gba.mem.vram + 0x10000);

/// Represents the tiles of the charblocks usable with objects.
pub const obj_charblock_tiles: *volatile ObjectCharblockTiles = @ptrFromInt(gba.mem.vram + 0x10000);

/// Represents a 16-color 8x8 pixel tile, 4 bits per pixel.
/// Also called an "s-tile", or single-size tile.
pub const Tile4Bpp = extern struct {
    data: [32]u8,
    
    pub fn init(data: [32]u8) Tile4Bpp {
        return Tile4Bpp{ .data = data };
    }
    
    /// Get the color of a pixel at a given coordinate.
    /// Colors are indices into a palette bank.
    pub fn getPixel(self: Tile4Bpp, x: u3, y: u3) u4 {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_half = i >> 1;
        if((x & 1) != 0) {
            return @truncate(self.data[i_half] >> 4);
        }
        else {
            return @truncate(self.data[i_half]);
        }
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette bank.
    pub fn setPixel(self: *Tile4Bpp, x: u3, y: u3, value: u4) void {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_half = i >> 1;
        if((x & 1) != 0) {
            self.data[i_half] = (self.data[i_half] & 0x0f) | (@as(u8, value) << 4);
        }
        else {
            self.data[i_half] = (self.data[i_half] & 0xf0) | value;
        }
    }
};

/// Represents a 256-color 8x8 pixel tile, 8 bits per pixel.
/// Also called a "d-tile", or double-size tile.
pub const Tile8Bpp = extern struct {
    data: [64]u8,
    
    pub fn init(data: [64]u8) Tile4Bpp {
        return Tile4Bpp{ .data = data };
    }
    
    /// Get the color of a pixel at a given coordinate.
    /// Colors are indices into a palette.
    pub fn getPixel(self: Tile4Bpp, x: u4, y: u4) u8 {
        const i: u8 = x + (@as(u8, y) << 3);
        return self.data[i];
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette.
    pub fn setPixel(self: *Tile4Bpp, x: u4, y: u4, value: u8) void {
        const i: u8 = x + (@as(u8, y) << 3);
        self.data[i] = value;
    }
};

/// Copy memory for 16-color tiles into a charblock.
///
/// Does not enforce the validity of `block` and `offset`, nor data length.
/// Expect strange behavior if passing invalid values.
///
/// Because of how the GBA handles writes to VRAM, always writing 16 bits at
/// a time, the source memory must be 16-bit aligned, and its length must be
/// a multiple of 2 bytes.
pub fn memcpyTiles4Bpp(
    /// Copy tile data into this charblock, 0-6.
    block: u3,
    /// Offset in tiles. (Each 16-color tile is 32 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile4Bpp,
) void {
    const offset = tile_offset + (@as(u16, block) << 9);
    assert(offset + data.len <= 0xc00); // 6 banks * 0x200 tiles/bank
    gba.mem.memcpy32(
        vram + (offset << 4),
        @as([*]align(2) const u8, @ptrCast(@alignCast(data))),
        data.len << 5,
    );
}

/// Copy memory for 256-color tiles into a charblock.
///
/// Because of how the GBA handles writes to VRAM, always writing 16 bits at
/// a time, the source memory must be 16-bit aligned, and its length must be
/// a multiple of 2 bytes.
pub fn memcpyTiles8Bpp(
    /// Copy tile data into this charblock, 0-6.
    block: u3,
    /// Offset in tiles. (Each 256-color tile is 64 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile8Bpp,
) void {
    const offset = tile_offset + (@as(u16, block) << 8);
    assert(offset + data.len <= 0x600); // 6 banks * 0x100 tiles/bank
    gba.mem.memcpy32(
        vram + (offset << 5),
        @as([*]align(2) const u8, @ptrCast(@alignCast(data))),
        data.len << 6,
    );
}

/// Copy memory for 16-color tiles into background charblock VRAM.
/// Wraps `memcpyTiles4Bpp` to always start in charblock 0.
pub inline fn memcpyBackgroundTiles4Bpp(
    /// Offset in tiles. (Each 16-color tile is 32 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile4Bpp,
) void {
    assert(tile_offset + data.len <= 0x800); // 4 banks * 0x200 tiles/bank
    memcpyTiles4Bpp(0, tile_offset, data);
}

/// Copy memory for 16-color tiles into background charblock VRAM.
/// Wraps `memcpyTiles8Bpp` to always start in charblock 0.
pub inline fn memcpyBackgroundTiles8Bpp(
    /// Offset in tiles. (Each 256-color tile is 64 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile8Bpp,
) void {
    assert(tile_offset + data.len <= 0x400); // 4 banks * 0x100 tiles/bank
    memcpyTiles8Bpp(0, tile_offset, data);
}

/// Copy memory for 16-color tiles into object charblock VRAM.
/// Wraps `memcpyTiles4Bpp` to always start in charblock 4.
pub inline fn memcpyObjectTiles4Bpp(
    /// Offset in tiles. (Each 16-color tile is 32 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile4Bpp,
) void {
    assert(tile_offset + data.len <= 0x400); // 2 banks * 0x200 tiles/bank
    memcpyTiles4Bpp(4, tile_offset, data);
}

/// Copy memory for 16-color tiles into object charblock VRAM.
/// Wraps `memcpyTiles8Bpp` to always start in charblock 4.
pub inline fn memcpyObjectTiles8Bpp(
    /// Offset in tiles. (Each 256-color tile is 64 bytes.)
    tile_offset: u16,
    /// Pointer to image data that should be copied into charblock VRAM.
    data: []align(2) const Tile8Bpp,
) void {
    assert(tile_offset + data.len <= 0x200); // 2 banks * 0x100 tiles/bank
    memcpyTiles8Bpp(4, tile_offset, data);
}
