//! This module contains definitions related to tiles and charbanks.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Pointer to the system's VRAM.
pub const vram: [*]volatile align(2) u16 = @ptrFromInt(gba.mem.vram);

/// Holds data for 32x32 non-affine background tiles, or up to 2048 affine
/// tiles.
/// A background can use one or more screenblocks.
pub const Screenblock = extern union {
    /// Describes a tile within a normal (non-affine) background.
    pub const Entry = packed struct(u16) {
        /// Offset added to a background's `tile_base_block` to determine the
        /// tile that should be displayed.
        tile: u10 = 0,
        /// Display the tile flipped horizontally.
        flip_x: bool = false,
        /// Display the tile flipped vertically.
        flip_y: bool = false,
        /// Index of palette bank to use for the tile, when in 16-color mode.
        /// Has no effect for 256-color 8bpp backgrounds.
        palette: u4 = 0,
    };
    
    /// Represents a tile index within an affine background map.
    pub const AffineEntry = u8;
    
    /// Describes a pair of affine background entries.
    /// Each single entry is an 8-bit tile index, but these entries can only
    /// be written in 16-bit pairs, due to how the system's VRAM works.
    pub const AffinePair = packed struct(u16) {
        /// First tile index, stored in the low byte.
        lo: AffineEntry,
        /// Second tile index, stored in the high byte.
        hi: AffineEntry,
    };
    
    /// Array of normal (non-affine) entries.
    entries: [1024]Entry,
    /// Array of affine entry pairs.
    affine_pairs: [1024]AffinePair,
    /// Array of individual tile indices for an affine map.
    /// Don't write to this array with a screenblock in VRAM!
    /// It won't behave the way that you are probably expecting it to.
    affine_entries: [2048]AffineEntry,
    
    /// Get tile data at a given coordinate within the single screenblock,
    /// for a normal (non-affine) background.
    pub fn get(self: Screenblock, x: u6, y: u5) Entry {
        return self.entries[x + (@as(u16, y) << 5)];
    }
    
    /// Set tile data at a given coordinate within the single screenblock,
    /// for a normal (non-affine) background.
    pub fn set(
        self: *volatile Screenblock,
        x: u5,
        y: u5,
        entry: Entry,
    ) void {
        self.entries[x + (@as(u16, y) << 5)] = entry;
    }
    
    /// Get affine tile data at a given coordinate within the single
    /// screenblock.
    pub inline fn getAffine(self: Screenblock, index: u11) Entry {
        return self.affine_entries[index];
    }
    
    /// Set affine tile data at a given coordinate within the single
    /// screenblock.
    ///
    /// NOTE: Set affine entries in pairs if you can!
    /// Doing it individually like this incurs a performance cost.
    pub fn setAffine(
        self: *volatile Screenblock,
        index: u11,
        entry: AffineEntry,
    ) void {
        const pair_index = index >> 1;
        var pair: u16 = @bitCast(self.affine_pairs[pair_index]);
        const shift: u4 = @truncate((index & 1) << 3);
        pair &= ~(@as(u16, 0xff) << shift);
        pair |= @as(u16, entry) << shift;
        self.affine_pairs[pair_index] = @bitCast(pair);
    }
    
    /// Fill every tile in this screenblock with a given entry.
    pub fn fill(self: *volatile Screenblock, entry: Screenblock.Entry) void {
        for(0..self.entries.len) |i| {
            self.entries[i] = entry;
        }
    }
    
    /// Fill every tile within a rect in this screenblock with a given entry.
    pub fn fillRect(
        self: *volatile Screenblock,
        entry: Screenblock.Entry,
        rect_x: u5,
        rect_y: u5,
        rect_width: u6,
        rect_height: u6,
    ) void {
        assert((rect_x + rect_width) <= 32 and (rect_y + rect_height) <= 32);
        // TODO: Define a common Rect type and use it for params here
        for(0..rect_height) |i_y| {
            var i = rect_x + ((rect_y + i_y) << 5);
            for(0..rect_width) |_| {
                self.entries[i] = entry;
                i += 1;
            }
        }
    }
    
    /// Fill every tile in this screenblock with a given entry,
    /// but add each tile's index within the screenblock to the that entry's
    /// `Screenblock.Entry.tile` value.
    ///
    /// This may be helpful to initialize a screenblock where every tile is
    /// unique.
    pub fn fillLinear(self: *volatile Screenblock, base_entry: Screenblock.Entry) void {
        var entry = base_entry;
        for(0..self.entries.len) |i| {
            self.entries[i] = entry;
            entry.tile += 1;
        }
    }
    
    /// Fill every tile within a rect in this screenblock with a given entry,
    /// but add each tile's index within the rectangle to the that entry's
    /// `Screenblock.Entry.tile` value. (Indices are column-major.)
    ///
    /// This may be helpful to initialize a portion of a screenblock where
    /// every tile is unique.
    pub fn fillRectLinear(
        self: *volatile Screenblock,
        base_entry: Screenblock.Entry,
        rect_x: u5,
        rect_y: u5,
        rect_width: u6,
        rect_height: u6,
    ) void {
        assert((rect_x + rect_width) <= 32 and (rect_y + rect_height) <= 32);
        // TODO: Define a common Rect type and use it for params here
        var entry = base_entry;
        for(0..rect_height) |i_y| {
            var i = rect_x + ((rect_y + i_y) << 5);
            for(0..rect_width) |_| {
                self.entries[i] = entry;
                entry.tile += 1;
                i += 1;
            }
        }
    }
};

/// Helper for managing one or more screenblocks used to contain the tilemap
/// data for a normal (non-affine) background.
pub const BackgroundMap = struct {
    /// Index of the first screenblock containing tilemap data for a background.
    /// Corresponds to `screen_base_block` in a REG_BGxCNT background control
    /// register.
    screenblock_index: u5,
    /// Size of the background map.
    size: gba.bg.Size.Normal,
    
    /// Initialize a `BackgroundMap` object from the information in a
    /// REG_BGxCNT background control register.
    /// This function assumes that the background is normal (non-affine).
    pub fn initCtrl(ctrl: gba.bg.Control) BackgroundMap {
        return .{
            .screenblock_index = ctrl.screen_base_block,
            .size = ctrl.tile_map_size.normal,
        };
    }
    
    /// Return the width of the map, in tiles. Returns either 32 or 64.
    pub inline fn width(self: BackgroundMap) u7 {
        return @as(u7, 0x20) << @intFromEnum(self.size.x);
    }
    
    /// Return the height of the map, in tiles. Returns either 32 or 64.
    pub inline fn height(self: BackgroundMap) u7 {
        return @as(u7, 0x20) << @intFromEnum(self.size.y);
    }
    
    /// Get tile data at a given coordinate.
    pub fn get(self: BackgroundMap, x: u6, y: u6) Screenblock.Entry {
        const screenblock_index = self.getScreenblockIndex(x, y);
        assert(screenblock_index < self.getScreenblockCount());
        const screenblock = &screenblocks[screenblock_index];
        return screenblock.get(@truncate(x), @truncate(y));
    }
    
    /// Set tile data at a given coordinate.
    /// It is not safe to try to set a tile outside tilemap bounds.
    pub fn set(
        self: BackgroundMap,
        x: u6,
        y: u6,
        entry: Screenblock.Entry,
    ) void {
        const screenblock_index = self.getScreenblockIndex(x, y);
        assert(screenblock_index < self.getScreenblockCount());
        const screenblock = &screenblocks[screenblock_index];
        screenblock.set(@truncate(x), @truncate(y), entry);
    }
    
    pub fn getScreenblock(self: BackgroundMap, i: u2) *volatile Screenblock {
        assert(i < self.getScreenblockCount());
        return &screenblocks[self.screenblock_index + i];
    }
    
    pub fn getBaseScreenblock(self: BackgroundMap) *volatile Screenblock {
        return &screenblocks[self.screenblock_index];
    }
    
    /// Given a tile coordinate, get the index of the screenblock which it
    /// belongs to.
    pub inline fn getScreenblockIndex(self: BackgroundMap, x: u6, y: u6) u5 {
        return @intCast(
            self.screenblock_index +
            (x >> 5) +
            ((y >> 5) << @intFromEnum(self.size.x))
        );
    }
    
    /// Get the number of screenblocks used by this background map,
    /// as an integer.
    /// Returns 1 for 32x32, 2 for 64x32 or 32x64, or 4 for 64x64.
    pub inline fn getScreenblockCount(self: BackgroundMap) u3 {
        return @as(u3, 1) << @intFromEnum(self.size.x) << @intFromEnum(self.size.y);
    }
    
    /// Fill every tile in this map with a given entry.
    pub fn fill(self: BackgroundMap, entry: Screenblock.Entry) void {
        const screenblock_count = self.size.getScreenblockCount();
        const entry_count: u32 = @as(u32, screenblock_count) << 10;
        const entries: [*]Screenblock.Entry = (
            @ptrCast(&screenblocks[self.screenblock_index].entries)
        );
        for(0..entry_count) |i| {
            entries[i] = entry;
        }
    }
    
    /// Fill every tile within a rect in this background with a given entry.
    pub fn fillRect(
        self: BackgroundMap,
        entry: Screenblock.Entry,
        rect_x: u6,
        rect_y: u6,
        rect_width: u7,
        rect_height: u7,
    ) void {
        assert((rect_x + rect_width) <= 32 and (rect_y + rect_height) <= 32);
        switch(self.size) {
            .size_32x32 => {
                screenblocks[self.screenblock_index].fillRect(
                    entry,
                    @intCast(rect_x),
                    @intCast(rect_y),
                    @intCast(rect_width),
                    @intCast(rect_height),
                );
            },
            .size_64x32 => {
                if(rect_x > 32) {
                    screenblocks[self.screenblock_index + 1].fillRect(
                        entry,
                        @intCast(rect_x - 32),
                        @intCast(rect_y),
                        @intCast(rect_width),
                        @intCast(rect_height),
                    );
                }
                else if(rect_x + rect_width > 32) {
                    const lo_x = 32 - rect_x;
                    screenblocks[self.screenblock_index].fillRect(
                        entry,
                        @intCast(rect_x),
                        @intCast(rect_y),
                        @intCast(lo_x),
                        @intCast(rect_height),
                    );
                    screenblocks[self.screenblock_index + 1].fillRect(
                        entry,
                        0,
                        @intCast(rect_y),
                        @intCast(rect_width - lo_x),
                        @intCast(rect_height),
                    );
                }
                else {
                    screenblocks[self.screenblock_index].fillRect(
                        entry,
                        @intCast(rect_x),
                        @intCast(rect_y),
                        @intCast(rect_width),
                        @intCast(rect_height),
                    );
                }
            },
            .size_32x64 => {
                if(rect_y > 32) {
                    screenblocks[self.screenblock_index + 1].fillRect(
                        entry,
                        @intCast(rect_x),
                        @intCast(rect_y - 32),
                        @intCast(rect_width),
                        @intCast(rect_height),
                    );
                }
                else if(rect_y + rect_height > 32) {
                    const lo_y = 32 - rect_y;
                    screenblocks[self.screenblock_index].fillRect(
                        entry,
                        @intCast(rect_x),
                        @intCast(rect_y),
                        @intCast(rect_width),
                        @intCast(lo_y),
                    );
                    screenblocks[self.screenblock_index + 1].fillRect(
                        entry,
                        @intCast(rect_x),
                        0,
                        @intCast(rect_width),
                        @intCast(rect_height - lo_y),
                    );
                }
                else {
                    screenblocks[self.screenblock_index].fillRect(
                        entry,
                        @intCast(rect_x),
                        @intCast(rect_y),
                        @intCast(rect_width),
                        @intCast(rect_height),
                    );
                }
            },
            .size_64x64 => {
                if(rect_x > 32) {
                    if(rect_y > 32) {
                        screenblocks[self.screenblock_index + 3].fillRect(
                            entry,
                            @intCast(rect_x - 32),
                            @intCast(rect_y - 32),
                            @intCast(rect_width),
                            @intCast(rect_height),
                        );
                    }
                    else if(rect_y + rect_height > 32) {
                        const lo_y = 32 - rect_y;
                        screenblocks[self.screenblock_index + 1].fillRect(
                            entry,
                            @intCast(rect_x - 32),
                            @intCast(rect_y),
                            @intCast(rect_width),
                            @intCast(lo_y),
                        );
                        screenblocks[self.screenblock_index + 3].fillRect(
                            entry,
                            @intCast(rect_x - 32),
                            0,
                            @intCast(rect_width),
                            @intCast(rect_height - lo_y),
                        );
                    }
                    else {
                        screenblocks[self.screenblock_index + 1].fillRect(
                            entry,
                            @intCast(rect_x - 32),
                            @intCast(rect_y),
                            @intCast(rect_width),
                            @intCast(rect_height),
                        );
                    }
                }
                else if(rect_x + rect_width > 32) {
                    const lo_x = 32 - rect_x;
                    if(rect_y > 32) {
                        screenblocks[self.screenblock_index + 2].fillRect(
                            entry,
                            @intCast(rect_x),
                            @intCast(rect_y - 32),
                            @intCast(lo_x),
                            @intCast(rect_height),
                        );
                        screenblocks[self.screenblock_index + 3].fillRect(
                            entry,
                            0,
                            @intCast(rect_y - 32),
                            @intCast(rect_width - lo_x),
                            @intCast(rect_height),
                        );
                    }
                    else if(rect_y + rect_height > 32) {
                        const lo_y = 32 - rect_y;
                        screenblocks[self.screenblock_index].fillRect(
                            entry,
                            @intCast(rect_x),
                            @intCast(rect_y),
                            @intCast(lo_x),
                            @intCast(lo_y),
                        );
                        screenblocks[self.screenblock_index + 1].fillRect(
                            entry,
                            0,
                            @intCast(rect_y),
                            @intCast(rect_width - lo_x),
                            @intCast(lo_y),
                        );
                        screenblocks[self.screenblock_index + 2].fillRect(
                            entry,
                            @intCast(rect_x),
                            0,
                            @intCast(lo_x),
                            @intCast(rect_height - lo_y),
                        );
                        screenblocks[self.screenblock_index + 3].fillRect(
                            entry,
                            0,
                            0,
                            @intCast(rect_width - lo_x),
                            @intCast(rect_height - lo_y),
                        );
                    }
                    else {
                        screenblocks[self.screenblock_index].fillRect(
                            entry,
                            @intCast(rect_x),
                            @intCast(rect_y),
                            @intCast(lo_x),
                            @intCast(rect_height),
                        );
                        screenblocks[self.screenblock_index + 1].fillRect(
                            entry,
                            0,
                            @intCast(rect_y),
                            @intCast(rect_width - lo_x),
                            @intCast(rect_height),
                        );
                    }
                }
            },
            else => unreachable,
        }
    }
};

/// Helper for managing one or more screenblocks used to contain the tilemap
/// data for an affine background.
pub const AffineBackgroundMap = struct {
    /// Index of the first screenblock containing tilemap data for a background.
    /// Corresponds to `screen_base_block` in a REG_BGxCNT background control
    /// register.
    screenblock_index: u5,
    /// Size of the background map.
    size: gba.bg.Size.Affine,
    
    /// Initialize an `AffineBackgroundMap` object from the information in a
    /// REG_BGxCNT background control register.
    /// This function assumes that the background is an affine background.
    pub fn initCtrl(ctrl: gba.bg.Control) AffineBackgroundMap {
        return .{
            .screenblock_index = ctrl.screen_base_block,
            .size = ctrl.tile_map_size.affine,
        };
    }
    
    /// Return the size of the map on either axis, in tiles.
    /// Unlike normal (non-affine) background maps, width and height are
    /// always the same for affine backgrounds.
    ///
    /// Returns 16, 32, 64, or 128.
    pub inline fn dimension(self: AffineBackgroundMap) u8 {
        return @as(u7, 0x10) << @intFromEnum(self.size);
    }
    
    /// Returns the same thing as `AffineBackgroundMap.dimension`.
    pub inline fn width(self: AffineBackgroundMap) u8 {
        return self.dimension();
    }
    
    /// Returns the same thing as `AffineBackgroundMap.dimension`.
    pub inline fn height(self: AffineBackgroundMap) u8 {
        return self.dimension();
    }
    
    /// Get tile data at a given coordinate.
    pub fn get(self: AffineBackgroundMap, x: u7, y: u7) Screenblock.AffineEntry {
        const tile_index = self.getTileIndex(x, y);
        const screenblock_index = self.screenblock_index + (tile_index >> 11);
        const screenblock = &screenblocks[screenblock_index];
        return screenblock.getAffine(@truncate(tile_index));
    }
    
    /// Set tile data at a given coordinate.
    ///
    /// NOTE: Set affine entries in pairs if you can!
    /// Doing it individually like this incurs a performance cost.
    pub fn set(
        self: AffineBackgroundMap,
        x: u7,
        y: u7,
        entry: Screenblock.AffineEntry,
    ) void {
        const tile_index = self.getTileIndex(x, y);
        const screenblock_index = self.screenblock_index + (tile_index >> 11);
        const screenblock = &screenblocks[screenblock_index];
        screenblock.setAffine(@truncate(tile_index), entry);
    }
    
    /// Given a tile coordinate, get the index of the corresponding entry
    /// within the affine tile data.
    pub inline fn getTileIndex(self: AffineBackgroundMap, x: u7, y: u7) u14 {
        const pitch: u4 = @as(u4, 4) + @intFromEnum(self.size);
        return x + (@as(u14, y) << pitch);
    }
    
    /// Given a tile coordinate, get the index of the screenblock which it
    /// belongs to.
    pub inline fn getScreenblockIndex(self: AffineBackgroundMap, x: u7, y: u7) u5 {
        return self.screenblock_index + (
            @as(u5, @intCast(self.getTileIndex(x, y) >> 11))
        );
    }
    
    /// Get the number of screenblocks used by this background map,
    /// as an integer.
    /// Returns 1 for 16x16 or 32x32, 2 for 64x64, or 8 for 128x128.
    pub inline fn getScreenblockCount(self: AffineBackgroundMap) u4 {
        return switch(self.size) {
            .size_16 => 1,
            .size_32 => 1,
            .size_64 => 2,
            .size_128 => 8,
        };
    }
};

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
    /// Provides access to charblock data as 16-color 4bpp tiles.
    bpp_4: [1024]Tile4Bpp,
    /// Provides access to charblock data as 256-color 8bpp tiles.
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
pub const Tile4Bpp = extern union {
    pixels: [32]u8,
    data_16: [16]u16,
    data_32: [8]u32,
    
    pub fn init(pixels: [32]u8) Tile4Bpp {
        return Tile4Bpp{ .pixels = pixels };
    }
    
    /// Fill all pixels in the tile with a given color.
    pub fn fill(self: *volatile Tile4Bpp, color: u4) void {
        @setRuntimeSafety(false);
        var color_data: u32 = @as(u32, color);
        color_data |= color_data << 8;
        color_data |= color_data << 16;
        for(0..8) |i| {
            self.data_32[i] = color_data;
        }
    }
    
    /// Fill all pixels in a consecutive run of tiles with a given color.
    /// This should be more performant than calling `Tile4Bpp.fill` repeatedly
    /// for each tile.
    pub fn fillLine(tiles: []volatile Tile4Bpp, color: u4) void {
        @setRuntimeSafety(false);
        var color_data: u32 = @as(u32, color);
        color_data |= color_data << 8;
        color_data |= color_data << 16;
        var data: [*]volatile u32 = @ptrCast(&tiles[0].data_32);
        const data_len = tiles.len << 3;
        for(0..data_len) |i| {
            data[i] = color_data;
        }
    }
    
    /// Get the color of a pixel at a given coordinate.
    /// Colors are indices into a palette bank.
    pub fn getPixel(self: Tile4Bpp, x: u3, y: u3) u4 {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_half = i >> 1;
        return switch(x & 1) {
            0 => @truncate(self.pixels[i_half]),
            1 => @truncate(self.pixels[i_half] >> 4),
            else => unreachable,
        };
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette bank.
    ///
    /// This function can be safely used if the tile is in VRAM,
    /// but it comes with a performance cost.
    pub fn setPixel16(self: *volatile Tile4Bpp, x: u3, y: u3, color: u4) void {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_quarter = i >> 2;
        self.data_16[i_quarter] = switch(x & 3) {
            0 => (self.data_16[i_quarter] & 0xfff0) | color,
            1 => (self.data_16[i_quarter] & 0xff0f) | (@as(u16, color) << 4),
            2 => (self.data_16[i_quarter] & 0xf0ff) | (@as(u16, color) << 8),
            3 => (self.data_16[i_quarter] & 0x0fff) | (@as(u16, color) << 12),
            else => unreachable,
        };
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette bank.
    ///
    /// This function is not safe to use if the tile is located in VRAM.
    pub fn setPixel8(self: *volatile Tile4Bpp, x: u3, y: u3, color: u4) void {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_half = i >> 1;
        self.pixels[i_half] = switch(x & 1) {
            0 => (self.pixels[i_half] & 0xf0) | color,
            1 => (self.pixels[i_half] & 0x0f) | (@as(u8, color) << 4),
            else => unreachable,
        };
        
        if((x & 1) != 0) {
            self.pixels[i_half] = (self.pixels[i_half] & 0x0f) | (@as(u8, color) << 4);
        }
        else {
            self.pixels[i_half] = (self.pixels[i_half] & 0xf0) | color;
        }
    }
};

/// Represents a 256-color 8x8 pixel tile, 8 bits per pixel.
/// Also called a "d-tile", or double-size tile.
pub const Tile8Bpp = extern union {
    pixels: [64]u8,
    data_16: [32]u16,
    data_32: [16]u32,
    
    pub fn init(pixels: [64]u8) Tile4Bpp {
        return Tile4Bpp{ .pixels = pixels };
    }
    
    /// Get the color of a pixel at a given coordinate.
    /// Colors are indices into a palette.
    pub fn getPixel(self: Tile4Bpp, x: u3, y: u3) u8 {
        const i: u8 = x + (@as(u8, y) << 3);
        return self.pixels[i];
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette.
    ///
    /// This function can be safely used if the tile is in VRAM,
    /// but it comes with a performance cost.
    pub fn setPixel16(self: *volatile Tile4Bpp, x: u3, y: u3, value: u8) void {
        const i: u8 = x + (@as(u8, y) << 3);
        const i_half = i >> 1;
        self.data_16[i_half] = switch(x & 1) {
            0 => (self.data_16[i_half] & 0xff00) | value,
            1 => (self.data_16[i_half] & 0x00ff) | (@as(u16, value) << 8),
            else => unreachable,
        };
    }
    
    /// Set the color of a pixel at a given coordinate.
    /// Colors are indices into a palette.
    ///
    /// This function is not safe to use if the tile is located in VRAM.
    pub fn setPixel8(self: *volatile Tile4Bpp, x: u3, y: u3, value: u8) void {
        const i: u8 = x + (@as(u8, y) << 3);
        self.pixels[i] = value;
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
