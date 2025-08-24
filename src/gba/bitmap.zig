const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Implements a generic helper for reading and drawing to a bitmap.
pub fn Bitmap(
    /// Type used for each entry in the bitmap, e.g. `u8` for an 8bpp bitmap
    /// with palette indices for each pixel, or `gba.ColorRgb555` for a 16bpp
    /// bitmap with a 16-bit color for each pixel.
    comptime PixelT: type,
    /// Expected byte alignment of bitmap data in memory.
    comptime data_align: comptime_int,
    /// All writes to the backing bitmap data must be at least 16-bit writes,
    /// and not 8-bit writes. This is important if `PixelT` is less than
    /// 16 bits, and if the bitmap data resides in the system's VRAM.
    comptime vram: bool,
) type {
    if(vram and ((data_align & 1) != 0)) {
        @compileError(
            "If vram is true, then data_align must be a multiple of 2."
        );
    }
    return struct {
        const Self = @This();
        
        /// Width of the bitmap, in pixels.
        width: u32 = 0,
        /// Height of the bitmap, in pixels.
        height: u32 = 0,
        /// Number of color entries in each row bitmap data.
        /// This allows for the possibility of padding.
        pitch: u32 = 0,
        /// Memory containing pixel data for this bitmap.
        data: [*]align(data_align) volatile PixelT,
        
        pub fn init(
            width: u32,
            height: u32,
            pitch: u32,
            data: [*]align(data_align) volatile PixelT,
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
            const data = try allocator.alloc(PixelT, height * pitch);
            return .init(width, height, pitch, data);
        }
        
        /// Free pixel data belonging to a given allocator.
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
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
        
        /// Set the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn setPixel(self: Self, x: u32, y: u32, px: PixelT) void {
            assert(x < self.width and y < self.height);
            if(comptime(@sizeOf(PixelT) > 1 or !vram)) {
                self.data[self.getPixelIndex(x, y)] = px;
            }
            else {
                const data_16: [*]volatile u16 = @ptrCast(self.data);
                const index_8 = self.getPixelIndex(x, y);
                const index_16 = index_8 >> 1;
                var px_16 = data_16[index_16];
                if((index_8 & 1) == 0) {
                    px_16 = (px_16 & 0xff00) | @as(u16, px);
                }
                else {
                    px_16 = (px_16 & 0x00ff) | (@as(u16, px) << 8);
                }
                data_16[index_16] = px_16;
            }
        }
        
        /// Retrieve the value associated with a pixel at a given coordinate
        /// within the bitmap.
        pub fn getPixel(self: Self, x: u32, y: u32) PixelT {
            assert(x < self.width and y < self.height);
            return self.data[self.getPixelIndex(x, y)];
        }
        
        /// Fill the entire bitmap with a given pixel value.
        pub fn fill(self: Self, px: PixelT) void {
            for(0..self.height) |y| {
                self.drawLineHorizontal(0, y, self.width, px);
            }
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
            assert(x + width <= self.width and y + height <= self.height);
            const y_max = y + height;
            for(y..y_max) |y_i| {
                self.drawLineHorizontal(x, @intCast(y_i), width, px);
            }
        }
        
        /// Draw a single-pixel-wide outline of a rectangle.
        pub fn drawRectOutline(
            self: Self,
            x: u32,
            y: u32,
            width: u32,
            height: u32,
            px: PixelT,
        ) void {
            assert(x + width <= self.width and y + height <= self.height);
            if(width == 0) {
                if(height == 0) {
                    self.setPixel(x, y, px);
                }
                else {
                    self.drawLineVertical(x, y, height, px);
                }
            }
            else {
                self.drawLineHorizontal(x, y, width, px);
                if(height > 0) {
                    self.drawLineHorizontal(x, y + height - 1, width, px);
                    if(height > 1) {
                        const y1 = y + 1;
                        const h2 = height - 2;
                        self.drawLineVertical(x, y1, h2, px);
                        self.drawLineVertical(x + width - 1, y1, h2, px);
                    }
                }
            }
        }
        
        /// Draw a strictly horizontal line, starting at the provided `x`, `y`
        /// coordinates and extending to the right for `len` pixels.
        pub fn drawLineHorizontal(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: PixelT,
        ) void {
            assert(x + len <= self.width and y < self.height);
            const i = self.getPixelIndex(x, y);
            if(comptime(@sizeOf(PixelT) == 1)) {
                if(comptime(vram)) {
                    if((i & 1) == 0) {
                        gba.mem.memset(&self.data[i], @bitCast(px), len);
                    }
                    else if(len > 0) {
                        self.setPixel(x, y, px);
                        gba.mem.memset(&self.data[i + 1], @bitCast(px), len - 1);
                    }
                }
                else {
                    gba.mem.memset(&self.data[i], @bitCast(px), len);
                }
            }
            else if(comptime(@sizeOf(PixelT) == 2)) {
                gba.mem.memset16(&self.data[i], @bitCast(px), len);
            }
            else if(comptime(@sizeOf(PixelT) == 4)) {
                gba.mem.memset32(&self.data[i], @bitCast(px), len);
            }
            else {
                const x_max = i + len;
                var x_i = i;
                while(x_i < x_max) : (x_i += 1) {
                    self.data[x_i] = px;
                }
            }
        }
        
        /// Draw a strictly vertical line, starting at the provided `x`, `y`
        /// coordinates and extending downward for `len` pixels.
        pub fn drawLineVertical(
            self: Self,
            x: u32,
            y: u32,
            len: u32,
            px: PixelT,
        ) void {
            assert(x < self.width and y + len <= self.height);
            const y_max = y + len;
            var y_i: u32 = y;
            while(y_i < y_max) : (y_i += 1) {
                self.setPixel(x, y_i, px);
            }
        }
        
        /// Draw a line between two points.
        /// Uses Bresenham's line drawing algorithm.
        pub fn drawLine(
            self: Self,
            x0: u32,
            y0: u32,
            x1: u32,
            y1: u32,
            px: PixelT,
        ) void {
            assert(x0 < self.width and y0 < self.height);
            assert(x1 < self.width and y1 < self.height);
            // Optimized special case for horizontal lines
            if(y0 == y1) {
                if(x0 == x1) {
                    self.setPixel(x0, y0, px);
                }
                else if(x0 < x1) {
                    self.drawLineHorizontal(x0, y0, x1 - x0 + 1, px);
                }
                else {
                    self.drawLineHorizontal(x1, y0, x0 - x1 + 1, px);
                }
            }
            // Optimized special case for vertical lines
            else if(x0 == x1) {
                if(y0 < y1) {
                    self.drawLineVertical(x0, y0, y1 - y0 + 1, px);
                }
                else {
                    self.drawLineVertical(x0, y1, y0 - y1 + 1, px);
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
                        self.drawLineLow(x1i, y1i, x0i, y0i, px);
                    }
                    else {
                        self.drawLineLow(x0i, y0i, x1i, y1i, px);
                    }
                }
                else {
                    if(y0 > y1) {
                        self.drawLineHigh(x1i, y1i, x0i, y0i, px);
                    }
                    else {
                        self.drawLineHigh(x0i, y0i, x1i, y1i, px);
                    }
                }
            }
        }
        
        /// Used internally by `drawLine` for a Y/X slope of less than 1.
        fn drawLineLow(
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
                self.setPixel(@intCast(x), @intCast(y), px);
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
        fn drawLineHigh(
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
                self.setPixel(@intCast(x), @intCast(y), px);
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

/// Represents a bitmap where each pixel is associated with a
/// `gba.ColorRgb555` 16-bit color value.
pub const Bitmap16Bpp = Bitmap(gba.ColorRgb555, 2, true);

/// Represents a bitmap where each pixel is associated with an
/// 8-bit palette index.
/// Use `Bitmap8BppVram` instead for a bitmap located in VRAM,
/// which does not support 8-bit writes.
pub const Bitmap8Bpp = Bitmap(u8, 1, false);

/// Represents a bitmap where each pixel is associated with an
/// 8-bit palette index.
/// Always writes 16 bits at a time, meaning it's safe to use
/// for a bitmap located in the GBA's VRAM.
pub const Bitmap8BppVram = Bitmap(u8, 2, true);
