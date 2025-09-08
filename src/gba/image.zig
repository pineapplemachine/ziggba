//! This module implements a generalized type for dealing with bitmaps.

const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Helper to call `gba.mem.memset` with a generic unit type,
/// at least 1 byte large.
fn pxmemset(
    /// Data type being written to the destination.
    comptime Pixel: type,
    /// Whether the destination disallows writes smaller than 16 bits.
    comptime vram: bool,
    /// Write pixels to this destination.
    destination: *align(@sizeOf(Pixel)) volatile anyopaque,
    /// Set pixels to this value.
    px: Pixel,
    /// Number of pixels to set.
    len: u32,
) void {
    if(comptime(@sizeOf(Pixel) == 1)) {
        if(comptime(vram)) {
            const destination_u8: [*]volatile u8 = @ptrCast(destination);
            if((@intFromPtr(destination_u8) & 1) == 0) {
                gba.mem.memset(destination_u8, @bitCast(px), len);
            }
            else if(len > 0) {
                gba.mem.setByteVram(destination_u8, @bitCast(px));
                gba.mem.memset(&destination_u8[1], @bitCast(px), len - 1);
            }
        }
        else {
            gba.mem.memset(destination, @bitCast(px), len);
        }
    }
    else if(comptime(@sizeOf(Pixel) == 2)) {
        gba.mem.memset16(destination, @bitCast(px), len);
    }
    else if(comptime(@sizeOf(Pixel) == 4)) {
        gba.mem.memset32(destination, @bitCast(px), len);
    }
    else if(comptime(!vram or (@sizeOf(Pixel) & 1) == 0)) {
        for(0..len) |i| {
            destination[i] = px;
        }
    }
    else {
        @compileError("Unsupported data type.");
    }
}

/// Generic helper for drawing to a surface.
pub fn SurfaceDraw(
    comptime SurfaceT: type,
    comptime PixelT: type,
) type {
    return struct {
        const Self = @This();
        
        pub const Surface = SurfaceT;
        pub const Pixel = PixelT;
        
        surface: SurfaceT,
        
        pub fn init(surface: SurfaceT) Self {
            return .{ .surface = surface };
        }
        
        /// Draw text to the bitmap.
        pub fn text(
            self: Self,
            string: []const u8,
            options: gba.text.DrawTextOptions(Pixel),
        ) void {
            gba.text.drawText(SurfaceT, Pixel, self.surface, string, options);
        }
        
        /// Draw a single pixel in the bitmap.
        pub fn pixel(self: Self, x: u32, y: u32, px: Pixel) void {
            self.surface.setPixel(x, y, px);
        }
        
        /// Fill the entire bitmap with a given pixel value.
        pub fn fill(
            self: Self,
            px: PixelT,
        ) void {
            self.surface.fill(px);
        }
        
        /// Fill a rectangular region of the bitmap with a given pixel value.
        pub fn fillRect(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: PixelT,
        ) void {
            self.surface.fillRect(x, y, width, height, px);
        }
        
        /// Draw a single-pixel-wide outline of a rectangle.
        pub fn rectOutline(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: PixelT,
        ) void {
            if(width == 0 or height == 0) {
                return;
            }
            else if(width == 1) {
                self.surface.drawLineVertical(x, y, height, px);
            }
            else {
                self.surface.drawLineHorizontal(x, y, width, px);
                if(height > 0) {
                    self.surface.drawLineHorizontal(x, y + height - 1, width, px);
                    if(height > 1) {
                        const y1 = y + 1;
                        const h2 = height - 2;
                        self.surface.drawLineVertical(x, y1, h2, px);
                        self.surface.drawLineVertical(x + width - 1, y1, h2, px);
                    }
                }
            }
        }
        
        /// Draw a strictly horizontal line, starting at the provided `x`, `y`
        /// coordinates and extending to the right for `len` pixels.
        pub fn lineHorizontal(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: PixelT,
        ) void {
            self.surface.drawLineHorizontal(x, y, len, px);
        }
        
        /// Draw a strictly vertical line, starting at the provided `x`, `y`
        /// coordinates and extending downward for `len` pixels.
        pub fn lineVertical(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: PixelT,
        ) void {
            self.surface.drawLineVertical(x, y, len, px);
        }
        
        /// Draw a line between two points.
        /// Uses Bresenham's line drawing algorithm.
        pub fn line(
            self: Self,
            x0: u32,
            y0: u32,
            x1: u32,
            y1: u32,
            px: PixelT,
        ) void {
            // Optimized special case for horizontal lines
            if(y0 == y1) {
                if(x0 == x1) {
                    self.surface.setPixel(x0, y0, px);
                }
                else if(x0 < x1) {
                    self.surface.drawLineHorizontal(x0, y0, x1 - x0 + 1, px);
                }
                else {
                    self.surface.drawLineHorizontal(x1, y0, x0 - x1 + 1, px);
                }
            }
            // Optimized special case for vertical lines
            else if(x0 == x1) {
                if(y0 < y1) {
                    self.surface.drawLineVertical(x0, y0, y1 - y0 + 1, px);
                }
                else {
                    self.surface.drawLineVertical(x0, y1, y0 - y1 + 1, px);
                }
            }
            // General case
            else {
                const x0i: i32 = @intCast(x0);
                const y0i: i32 = @intCast(y0);
                const x1i: i32 = @intCast(x1);
                const y1i: i32 = @intCast(y1);
                if(@abs(y1i - y0i) < @abs(x1i - x0i)) {
                    if(x0 > x1) {
                        self.lineLow(x1i, y1i, x0i, y0i, px);
                    }
                    else {
                        self.lineLow(x0i, y0i, x1i, y1i, px);
                    }
                }
                else {
                    if(y0 > y1) {
                        self.lineHigh(x1i, y1i, x0i, y0i, px);
                    }
                    else {
                        self.lineHigh(x0i, y0i, x1i, y1i, px);
                    }
                }
            }
        }

        /// Used internally by `drawLine` for a Y/X slope of less than 1.
        fn lineLow(
            self: Self,
            x0: i32,
            y0: i32,
            x1: i32,
            y1: i32,
            px: PixelT,
        ) void {
            assert(x0 <= x1);
            const dx = x1 - x0;
            var dy = y1 - y0;
            var yi: i32 = 1;
            if(dy < 0) {
                yi = -1;
                dy = -dy;
            }
            var diff = (dy << 1) - dx;
            var x = x0;
            var y = y0;
            while(x <= x1) : (x += 1) {
                @setRuntimeSafety(false);
                self.surface.setPixel(@intCast(x), @intCast(y), px);
                if(diff > 0) {
                    y += yi;
                    diff += ((dy - dx) << 1);
                }
                else {
                    diff += (dy << 1);
                }
            }
        }

        /// Used internally by `drawLine` for a Y/X slope of 1 or more.
        fn lineHigh(
            self: Self,
            x0: i32,
            y0: i32,
            x1: i32,
            y1: i32,
            px: PixelT,
        ) void {
            assert(y0 <= y1);
            const dy = y1 - y0;
            var dx = x1 - x0;
            var xi: i32 = 1;
            if(dx < 0) {
                xi = -1;
                dx = -dx;
            }
            var diff = (dx << 1) - dy;
            var x = x0;
            var y = y0;
            while(y <= y1) : (y += 1) {
                @setRuntimeSafety(false);
                self.surface.setPixel(@intCast(x), @intCast(y), px);
                if(diff > 0) {
                    x += xi;
                    diff += ((dx - dy) << 1);
                }
                else {
                    diff += (dx << 1);
                }
            }
        }
    };
}

/// Implements a generic helper for reading and drawing to a bitmap,
/// where each pixel uses at least 1 byte of memory.
pub fn Surface(
    /// Type used for each entry in the bitmap, e.g. `u8` for an 8bpp bitmap
    /// with palette indices for each pixel, or `gba.ColorRgb555` for a 16bpp
    /// bitmap with a 16-bit color for each pixel.
    comptime PixelT: type,
    /// All writes to the backing bitmap data must be at least 16-bit writes,
    /// and not 8-bit writes, if this flag is set.
    /// This is important if `PixelT` is less than 16 bits, and if the bitmap
    /// data resides in the system's VRAM.
    comptime vram: bool,
) type {
    return struct {
        const Self = @This();
        
        pub const Pixel = PixelT;
        pub const data_align = (
            if(vram) @max(2, @alignOf(Pixel)) else @alignOf(Pixel)
        );
        
        /// Width of the bitmap, in pixels.
        width: u32 = 0,
        /// Height of the bitmap, in pixels.
        height: u32 = 0,
        /// Number of entries in each row of bitmap data.
        /// This allows for the possibility of padding.
        pitch: u32 = 0,
        /// Memory containing pixel data for this bitmap.
        data: [*]align(data_align) volatile Pixel,
        
        pub fn init(
            width: u32,
            height: u32,
            data: [*]align(data_align) volatile Pixel,
        ) Self {
            return .initPitch(width, height, width, data);
        }
        
        pub fn initPitch(
            width: u32,
            height: u32,
            pitch: u32,
            data: [*]align(data_align) volatile Pixel,
        ) Self {
            assert(width <= pitch);
            return .{
                .width = width,
                .height = height,
                .pitch = pitch,
                .data = data,
            };
        }
        
        /// Initialize a bitmap with its pixel data allocated using a
        /// given allocator.
        pub fn create(
            allocator: std.mem.Allocator,
            width: u32,
            height: u32,
            pitch: u32,
        ) !Self {
            const data = try allocator.alloc(Pixel, height * pitch);
            return .init(width, height, pitch, data);
        }
        
        /// Free pixel data belonging to a given allocator.
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
        
        /// Get a surface referring to the same underlying bitmap data,
        /// ensuring no writes smaller than 16 bits.
        /// The `data` pointer must be at least 16-bit aligned.
        pub fn inVram(self: Self) Surface(Pixel, true) {
            return .init(
                self.width,
                self.height,
                self.pitch,
                @alignCast(self.data),
            );
        }
        
        /// Return a helper for drawing to this surface.
        pub fn draw(self: Self) SurfaceDraw(Self, Pixel) {
            return .init(self);
        }
        
        /// Get a `data` index corresponding to a given pixel coordinate
        /// within the bitmap.
        pub fn getPixelIndex(self: Self, x: u32, y: u32) u32 {
            return x + (y * self.pitch);
        }
        
        /// Get the expected length of the bitmap's `data` buffer.
        pub fn getDataLength(self: Self) u32 {
            return self.height * self.pitch;
        }
        
        /// Get width in pixels.
        pub fn getWidth(self: Self) u32 {
            return self.width;
        }
        
        /// Get height in pixels.
        pub fn getHeight(self: Self) u32 {
            return self.height;
        }
        
        /// Set the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn setPixel(self: Self, x: u32, y: u32, px: Pixel) void {
            assert(x < self.width and y < self.height);
            if(comptime(@sizeOf(Pixel) > 1 or !vram)) {
                self.data[self.getPixelIndex(x, y)] = px;
            }
            else {
                const i = self.getPixelIndex(x, y);
                gba.mem.setByteVram(&self.data[i], @bitCast(px));
            }
        }
        
        /// Retrieve the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn getPixel(self: Self, x: u32, y: u32) Pixel {
            assert(x < self.width and y < self.height);
            return self.data[self.getPixelIndex(x, y)];
        }
        
        /// Fill the entire bitmap with a given pixel value.
        pub fn fill(self: Self, px: Pixel) void {
            if(self.width == self.pitch) {
                pxmemset(Pixel, vram, self.data, px, self.pitch * self.height);
            }
            else {
                for(0..self.height) |y| {
                    self.drawLineHorizontal(0, y, self.width, px);
                }
            }
        }
        
        /// Fill a rectangular region of the bitmap with a given pixel value.
        pub fn fillRect(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: Pixel,
        ) void {
            assert(x + width <= self.width and y + height <= self.height);
            if(width <= 0) {
                return;
            }
            const y_max = y + height;
            for(y..y_max) |y_i| {
                self.drawLineHorizontal(x, @intCast(y_i), width, px);
            }
        }
        
        /// Draw a strictly horizontal line, starting at the provided `x`, `y`
        /// coordinates and extending to the right for `len` pixels.
        pub fn drawLineHorizontal(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: Pixel,
        ) void {
            assert(x + len <= self.width and y < self.height);
            const i = self.getPixelIndex(x, y);
            pxmemset(Pixel, vram, &self.data[i], px, len);
        }
        
        /// Draw a strictly vertical line, starting at the provided `x`, `y`
        /// coordinates and extending downward for `len` pixels.
        pub fn drawLineVertical(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: Pixel,
        ) void {
            assert(x < self.width and y + len <= self.height);
            for(0..len) |y_i| {
                self.setPixel(x, y + y_i, px);
            }
        }
    };
}

/// Parameterized type for interacting with VRAM tiles as a surface.
fn SurfaceTiles(
    bpp: gba.display.TileBpp,
    /// All writes to the backing bitmap data must be at least 16-bit writes,
    /// and not 8-bit writes, if this flag is set.
    /// This is important if the bitmap data resides in the system's VRAM.
    comptime vram: bool,
) type {
    return struct {
        const Self = @This();
        
        pub const Tile = switch(bpp) {
            .bpp_4 => gba.display.Tile4Bpp,
            .bpp_8 => gba.display.Tile8Bpp,
        };
        pub const Pixel = switch(bpp) {
            .bpp_4 => u4,
            .bpp_8 => u8,
        };
        pub const data_align = if(vram) @sizeOf(Tile) else @alignOf(Tile);
        
        /// Width of the bitmap, in tiles.
        width_tiles: u16 = 0,
        /// Height of the bitmap, in tiles.
        height_tiles: u16 = 0,
        /// Number of tiles in each row of bitmap data.
        /// This allows for the possibility of padding.
        pitch_tiles: u16 = 0,
        /// Memory containing pixel data for this bitmap.
        data: [*]align(data_align) volatile Tile,
        
        pub fn init(
            width_tiles: u16,
            height_tiles: u16,
            data: [*]align(data_align) volatile Tile,
        ) Self {
            return .initPitch(width_tiles, height_tiles, width_tiles, data);
        }
        
        pub fn initPitch(
            width_tiles: u16,
            height_tiles: u16,
            pitch_tiles: u16,
            data: [*]align(data_align) volatile Tile,
        ) Self {
            assert(width_tiles <= pitch_tiles);
            return .{
                .width_tiles = width_tiles,
                .height_tiles = height_tiles,
                .pitch_tiles = pitch_tiles,
                .data = data,
            };
        }
        
        /// Initialize a bitmap with its pixel data allocated using a
        /// given allocator.
        pub fn create(
            allocator: std.mem.Allocator,
            width_tiles: u16,
            height_tiles: u16,
            pitch_tiles: u16,
        ) !Self {
            const tiles = pitch_tiles * height_tiles;
            const data = try allocator.alloc(Tile, tiles);
            return .init(width_tiles, height_tiles, pitch_tiles, data);
        }
        
        /// Free pixel data belonging to a given allocator.
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }
        
        /// Get a surface referring to the same underlying bitmap data,
        /// ensuring no writes smaller than 16 bits.
        /// The `data` pointer must be appropriately aligned.
        pub fn inVram(self: Self) SurfaceTiles(bpp, true) {
            return .init(
                self.width_tiles,
                self.height_tiles,
                self.pitch_tiles,
                @alignCast(self.data),
            );
        }
        
        /// Return a helper for drawing to this surface.
        pub fn draw(self: Self) SurfaceDraw(Self, Pixel) {
            return .init(self);
        }
        
        /// Get the expected length of the bitmap's `data` buffer.
        pub fn getDataLength(self: Self) u32 {
            const tiles = self.pitch_tiles * self.height_tiles;
            return tiles * @sizeOf(Tile);
        }
        
        /// Get width in pixels.
        pub fn getWidth(self: Self) u32 {
            return @as(u32, self.width_tiles) << 3;
        }
        
        /// Get height in pixels.
        pub fn getHeight(self: Self) u32 {
            return @as(u32, self.height_tiles) << 3;
        }
        
        /// Get offset of a pixel within the bitmap data,
        /// counting in nibbles (4-bit units) for 4bpp tiles and
        /// counting in bytes for 8bpp tiles.
        fn getPixelOffset(self: Self, x: u32, y: u32) u32 {
            const tile_x: u16 = @intCast(x >> 3);
            const tile_y: u16 = @intCast(y >> 3);
            const tile_i = self.getTileIndex(tile_x, tile_y);
            const tile_offset = (tile_i << 1) * @sizeOf(Tile);
            const tile_px_x = x & 0x7;
            const tile_px_y = y & 0x7;
            const tile_px_offset = tile_px_x + (tile_px_y << 3);
            return tile_offset + tile_px_offset;
        }
        
        /// Get offset of a tile within the bitmap data,
        /// counting by tiles (32-byte units).
        pub fn getTileIndex(self: Self, tile_x: u16, tile_y: u16) u32 {
            return tile_x + (tile_y * self.pitch_tiles);
        }
        
        /// Set the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn setPixel(self: Self, x: u32, y: u32, px: Pixel) void {
            assert(x < self.getWidth() and y < self.getHeight());
            const i = self.getPixelOffset(x, y);
            switch(comptime(bpp)) {
                .bpp_4 => {
                    if(vram) {
                        gba.mem.setNibbleVram(self.data, i, px);
                    }
                    else {
                        gba.mem.setNibble(self.data, i, px);
                    }
                },
                .bpp_8 => {
                    const data_8: [*]volatile u8 = @ptrCast(self.data);
                    if(vram) {
                        gba.mem.setByteVram(data_8, i, px);
                    }
                    else {
                        data_8[i] = px;
                    }
                },
            }
        }
        
        /// Retrieve the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn getPixel(self: Self, x: u32, y: u32) Pixel {
            assert(x < self.getWidth() and y < self.getHeight());
            const i = self.getPixelOffset(x, y);
            switch(comptime(bpp)) {
                .bpp_4 => {
                    return gba.mem.getNibble(self.data, i);
                },
                .bpp_8 => {
                    const data_8: [*]volatile u8 = @ptrCast(self.data);
                    return data_8[i];
                },
            }
        }
        
        /// Fill the entire bitmap with a given pixel value.
        pub fn fill(self: Self, px: Pixel) void {
            if(self.width_tiles == self.pitch_tiles) {
                const tiles = self.pitch_tiles * self.height_tiles;
                const px_8: u8 = @as(u8, px) | (@as(u8, px) << 4);
                pxmemset(
                    u8,
                    vram,
                    self.data,
                    px_8,
                    tiles * @sizeOf(Tile),
                );
            }
            else {
                for(0..self.height_tiles) |y| {
                    self.fillTileRow(0, y, self.width_tiles, px);
                }
            }
        }
        
        /// Fill one tile with a given pixel value.
        pub fn fillTile(self: Self, tile_x: u16, tile_y: u16, px: Pixel) void {
            assert(tile_x < self.width_tiles and tile_y < self.height_tiles);
            const tile_i = self.getTileIndex(tile_x, tile_y);
            const px_8: u8 = @as(u8, px) | (@as(u8, px) << 4);
            pxmemset(
                u8,
                vram,
                &self.data[tile_i],
                px_8,
                @sizeOf(Tile),
            );
        }
        
        /// Fill a row of tiles with a given pixel value.
        pub fn fillTileRow(
            self: Self,
            tile_x: u16,
            tile_y: u16,
            len: u16,
            px: Pixel,
        ) void {
            assert(tile_x + len <= self.width_tiles);
            assert(tile_y < self.height_tiles);
            const tile_i = self.getTileIndex(tile_x, tile_y);
            const px_8: u8 = @as(u8, px) | (@as(u8, px) << 4);
            pxmemset(
                u8,
                vram,
                &self.data[tile_i],
                px_8,
                len * @sizeOf(Tile),
            );
        }
        
        /// Fill a column of tiles with a given pixel value.
        pub fn fillTileColumn(
            self: Self,
            tile_x: u16,
            tile_y: u16,
            len: u16,
            px: Pixel,
        ) void {
            assert(tile_x < self.width_tiles);
            assert(tile_y + len <= self.height_tiles);
            for(0..len) |y_i| {
                self.fillTile(tile_x, @intCast(tile_y + y_i), px);
            }
        }
        
        /// Fill a rectangular region of the bitmap with a given pixel value.
        pub fn fillTileRect(
            self: Self,
            tile_x: u16,
            tile_y: u16,
            width_tiles: u16,
            height_tiles: u16,
            px: Pixel,
        ) void {
            assert(tile_x + width_tiles <= self.width_tiles);
            assert(tile_y + height_tiles <= self.height_tiles);
            for(0..height_tiles) |y_i| {
                self.fillTileRow(
                    tile_x,
                    @intCast(tile_y + y_i),
                    width_tiles,
                    px,
                );
            }
        }
        
        /// Helper used by `fillRect`.
        fn fillRectMargin(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: Pixel,
        ) void {
            if(width <= 0) {
                return;
            }
            const y_max = y + height;
            for(y..y_max) |y_i| {
                self.drawLineHorizontal(x, @intCast(y_i), width, px);
            }
        }
        
        /// Fill a rectangular region of the bitmap with a given pixel value.
        pub fn fillRect(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: Pixel,
        ) void {
            assert(x + width <= self.getWidth());
            assert(y + height <= self.getHeight());
            const x_lo = x & 0x7;
            const y_lo = y & 0x7;
            const width_t = width - x_lo;
            const height_t = height - y_lo;
            const margin_left = (8 - x_lo) & 0x7;
            const margin_top = (8 - y_lo) & 0x7;
            const margin_right = width_t & 0x7;
            const margin_bottom = height_t & 0x7;
            // Interior tiles (fast)
            self.fillTileRect(
                (x + margin_left) >> 3,
                (y + margin_top) >> 3,
                width_t >> 3,
                height_t >> 3,
                px,
            );
            // Top margin
            self.fillRectMargin(
                x,
                y,
                width,
                margin_top,
                px,
            );
            // Bottom margin
            self.fillRectMargin(
                x,
                height - margin_bottom + y,
                width,
                margin_bottom,
                px,
            );
            // Left margin
            self.fillRectMargin(
                x,
                y + margin_top,
                margin_left,
                height_t - margin_bottom,
                px,
            );
            // Right margin
            self.fillRectMargin(
                width - margin_right + x,
                y + margin_top,
                margin_right,
                height_t - margin_bottom,
                px,
            );
        }
        
        /// Draw a strictly horizontal line, starting at the provided `x`, `y`
        /// coordinates and extending to the right for `len` pixels.
        pub fn drawLineHorizontal(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: Pixel,
        ) void {
            assert(x + len <= self.getWidth() and y < self.getHeight());
            const x_lo = x & 0x7;
            const width_t = len - x_lo;
            const margin_left = (8 - x_lo) & 0x7;
            const margin_right = width_t & 0x7;
            for(0..margin_left) |x_i| {
                self.setPixel(x + x_i, y, px);
            }
            for(0..margin_right) |x_i| {
                self.setPixel(len - margin_right + x + x_i, y, px);
            }
            const tile_row_i = y & 0x7;
            const tile_i = (
                ((x + margin_left) >> 3) +
                ((y >> 3) * self.pitch_tiles)
            );
            const row: Tile.Row = .initFill(px);
            for(0..(width_t >> 3)) |x_i| {
                self.data[tile_i + x_i].rows[tile_row_i] = row;
            }
        }
        
        /// Draw a strictly vertical line, starting at the provided `x`, `y`
        /// coordinates and extending downward for `len` pixels.
        pub fn drawLineVertical(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: Pixel,
        ) void {
            assert(x < self.getWidth() and y + len <= self.getHeight());
            for(0..len) |y_i| {
                self.setPixel(x, y + y_i, px);
            }
        }
    };
}

/// Represents a bitmap where each pixel is associated with a
/// `gba.ColorRgb555` 16-bit color value.
pub const Surface16Bpp = Surface(gba.ColorRgb555, true);

/// Represents a bitmap where each pixel is associated with an
/// 8-bit palette index.
/// Use `Surface8BppVram` instead for a bitmap located in VRAM,
/// which does not support 8-bit writes.
pub const Surface8Bpp = Surface(u8, false);

/// Represents a bitmap where each pixel is associated with an
/// 8-bit palette index.
/// Always writes 16 bits at a time, meaning it's safe to use
/// for a bitmap located in the GBA's VRAM.
pub const Surface8BppVram = Surface(u8, true);

/// Represents a bitmap where pixels are laid out in 4bpp tiles,
/// like for use with a background or object/sprite.
/// Use `SurfaceTiles4BppVram` instead for a bitmap located in VRAM,
/// which does not support 8-bit writes.
pub const SurfaceTiles4Bpp = SurfaceTiles(.bpp_4, false);

/// Represents a bitmap where pixels are laid out in 4bpp tiles,
/// like for use with a background or object/sprite.
/// Always writes 16 bits at a time, meaning it's safe to use
/// for a bitmap located in the GBA's VRAM.
pub const SurfaceTiles4BppVram = SurfaceTiles(.bpp_4, true);

/// Represents a bitmap where pixels are laid out in 8bpp tiles,
/// like for use with a background or object/sprite.
/// Use `SurfaceTiles4BppVram` instead for a bitmap located in VRAM,
/// which does not support 8-bit writes.
pub const SurfaceTiles8Bpp = SurfaceTiles(.bpp_8, false);

/// Represents a bitmap where pixels are laid out in 8bpp tiles,
/// like for use with a background or object/sprite.
/// Always writes 16 bits at a time, meaning it's safe to use
/// for a bitmap located in the GBA's VRAM.
pub const SurfaceTiles8BppVram = SurfaceTiles(.bpp_8, true);
