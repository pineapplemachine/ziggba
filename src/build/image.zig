const zigimg = @import("zigimg").zigimg;
const std = @import("std");
const assert = @import("std").debug.assert;
const ColorRgba32 = @import("color.zig").ColorRgba32;
const RectU16 = @import("../gba/math.zig").RectU16;
const Vec2U16 = @import("../gba/math.zig").Vec2U16;

pub const ConvertImageBitmap8BppOptions = @import("image_bitmap.zig").ConvertImageBitmap8BppOptions;
pub const ConvertImageBitmap16BppOptions = @import("image_bitmap.zig").ConvertImageBitmap16BppOptions;
pub const ConvertImageBitmap8BppOutput = @import("image_bitmap.zig").ConvertImageBitmap8BppOutput;
pub const ConvertImageBitmap16BppOutput = @import("image_bitmap.zig").ConvertImageBitmap16BppOutput;
pub const ConvertImageBitmap8BppError = @import("image_bitmap.zig").ConvertImageBitmap8BppError;
pub const ConvertImageBitmap16BppError = @import("image_bitmap.zig").ConvertImageBitmap16BppError;
pub const convertImageBitmap8BppPath = @import("image_bitmap.zig").convertImageBitmap8BppPath;
pub const convertSaveImageBitmap8BppPath = @import("image_bitmap.zig").convertSaveImageBitmap8BppPath;
pub const convertImageBitmap8Bpp = @import("image_bitmap.zig").convertImageBitmap8Bpp;
pub const convertImageBitmap16BppPath = @import("image_bitmap.zig").convertImageBitmap16BppPath;
pub const convertSaveImageBitmap16BppPath = @import("image_bitmap.zig").convertSaveImageBitmap16BppPath;
pub const convertImageBitmap16Bpp = @import("image_bitmap.zig").convertImageBitmap16Bpp;
pub const ConvertImageBitmap8BppStep = @import("image_bitmap.zig").ConvertImageBitmap8BppStep;
pub const ConvertImageBitmap16BppStep = @import("image_bitmap.zig").ConvertImageBitmap16BppStep;

pub const ConvertImageTiles4BppOptions = @import("image_tiles.zig").ConvertImageTiles4BppOptions;
pub const ConvertImageTiles8BppOptions = @import("image_tiles.zig").ConvertImageTiles8BppOptions;
pub const ConvertImageTiles4BppError = @import("image_tiles.zig").ConvertImageTiles4BppError;
pub const ConvertImageTiles8BppError = @import("image_tiles.zig").ConvertImageTiles8BppError;
pub const convertImageTiles4BppPath = @import("image_tiles.zig").convertImageTiles4BppPath;
pub const convertSaveImageTiles4BppPath = @import("image_tiles.zig").convertSaveImageTiles4BppPath;
pub const convertImageTiles4Bpp = @import("image_tiles.zig").convertImageTiles4Bpp;
pub const convertImageTiles8BppPath = @import("image_tiles.zig").convertImageTiles8BppPath;
pub const convertSaveImageTiles8BppPath = @import("image_tiles.zig").convertSaveImageTiles8BppPath;
pub const convertImageTiles8Bpp = @import("image_tiles.zig").convertImageTiles8Bpp;
pub const ConvertImageTiles4BppStep = @import("image_tiles.zig").ConvertImageTiles4BppStep;
pub const ConvertImageTiles8BppStep = @import("image_tiles.zig").ConvertImageTiles8BppStep;

/// Provides an interface for loading and reading image data.
/// Wraps a `zigimg.Image`, but it could wrap something else in the future
/// while providing the same interface.
pub const Image = struct {
    data: zigimg.Image,
    
    /// Load image from a file path.
    pub fn fromFilePath(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) (
        std.mem.Allocator.Error ||
        zigimg.Image.ReadError ||
        std.fs.File.OpenError
    )!Image {
        const data = try zigimg.Image.fromFilePath(allocator, path);
        return .{ .data = data };
    }
    
    /// Check whether the instance possesses valid image data.
    pub fn isValid(self: Image) bool {
        return self.data.pixelFormat() != .invalid;
    }
    
    /// Free memory in use by this image.
    pub fn deinit(self: *Image) void {
        self.data.deinit();
    }
    
    /// Get the width of the image, in pixels.
    pub fn getWidth(self: Image) u16 {
        return @intCast(self.data.width);
    }
    
    /// Get the height of the image, in pixels.
    pub fn getHeight(self: Image) u16 {
        return @intCast(self.data.height);
    }
    
    /// Get a rectangle representing the bounds of the image.
    pub fn getRect(self: Image) RectU16 {
        return .init(0, 0, self.getWidth(), self.getHeight());
    }
    
    /// Get a vector representing the size of the image.
    pub fn getSize(self: Image) Vec2U16 {
        return .init(self.getWidth(), self.getHeight());
    }
    
    /// Returns the number of pixels, i.e. `width * height`.
    pub fn getSizePixels(self: Image) u32 {
        return @as(u32, self.getWidth()) * @as(u32, self.getHeight());
    }
    
    /// Returns true when width or height is zero.
    pub fn isEmpty(self: Image) bool {
        return self.getWidth() <= 0 or self.getHeight() <= 0;
    }
    
    /// Get whether a pixel coordinate is within the image bounds.
    pub fn isInBounds(self: Image, x: u16, y: u16) bool {
        return x < self.getWidth() and y < self.getHeight();
    }
    
    /// Get the color of a pixel at a given coordinate.
    pub fn getPixelColor(self: Image, x: u16, y: u16) ColorRgba32 {
        assert(self.isValid());
        assert(x < self.getWidth());
        assert(y < self.getHeight());
        const i = x + (y * self.getWidth());
        return getImagePixelRgba32(self.data, i);
    }
};

/// Helper to get RGBA8888 color from an image.
fn getImagePixelRgba32(image: zigimg.Image, index: usize) ColorRgba32 {
    return switch (image.pixels) {
        .invalid => .transparent,
        .indexed1 => |px| @bitCast(px.palette[px.indices[index]]),
        .indexed2 => |px| @bitCast(px.palette[px.indices[index]]),
        .indexed4 => |px| @bitCast(px.palette[px.indices[index]]),
        .indexed8 => |px| @bitCast(px.palette[px.indices[index]]),
        .indexed16 => |px| @bitCast(px.palette[px.indices[index]]),
        .grayscale1 => |px| {
            const i: u8 = if (px[index].value == 0) 0 else 0xff;
            return ColorRgba32.fromIntensity(i);
        },
        .grayscale2 => |px| {
            const i_table = [4]u8{ 0x00, 0x55, 0xaa, 0xff };
            const i = i_table[px[index].value];
            return ColorRgba32.fromIntensity(i);
        },
        .grayscale4 => |px| {
            const i = (@as(u8, px[index].value) << 4) | px[index].value;
            return ColorRgba32.fromIntensity(i);
        },
        .grayscale8 => |px| {
            const i = px[index].value;
            return ColorRgba32.fromIntensity(i);
        },
        .grayscale8Alpha => |px| {
            const i = px[index].value;
            return ColorRgba32.fromIntensity(i).withAlpha(px[index].alpha);
        },
        .grayscale16 => |px| {
            const i: u8 = @truncate(px[index].value);
            return ColorRgba32.fromIntensity(i);
        },
        .grayscale16Alpha => |px| {
            const i: u8 = @truncate(px[index].value);
            const a: u8 = @truncate(px[index].alpha);
            return ColorRgba32.fromIntensity(i).withAlpha(a);
        },
        .rgb24 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .rgba32 => |px| .rgba(px[index].r, px[index].g, px[index].b, px[index].a),
        .rgb332 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .rgb565 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .rgb555 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .bgr555 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .bgr24 => |px| .rgb(px[index].r, px[index].g, px[index].b),
        .bgra32 => |px| .rgba(px[index].r, px[index].g, px[index].b, px[index].a),
        .rgb48 => |px| {
            const r: u8 = @truncate(px[index].r);
            const g: u8 = @truncate(px[index].g);
            const b: u8 = @truncate(px[index].b);
            return .rgb(r, g, b);
        },
        .rgba64 => |px| {
            const r: u8 = @truncate(px[index].r);
            const g: u8 = @truncate(px[index].g);
            const b: u8 = @truncate(px[index].b);
            const a: u8 = @truncate(px[index].a);
            return .rgba(r, g, b, a);
        },
        .float32 => |px| {
            const r: u8 = @intFromFloat(@round(px[index].r));
            const g: u8 = @intFromFloat(@round(px[index].g));
            const b: u8 = @intFromFloat(@round(px[index].b));
            const a: u8 = @intFromFloat(@round(px[index].a));
            return .rgba(r, g, b, a);
        },
    };
}
