const zigimg = @import("zigimg/zigimg.zig");
const std = @import("std");
const assert = @import("std").debug.assert;

pub const ColorRgba32 = packed struct(u32) {
    pub const transparent: ColorRgba32 = .fromIntArgb(0);
    pub const black: ColorRgba32 = .fromIntRgb(0);
    pub const white: ColorRgba32 = .fromIntRgb(0xffffff);
    pub const gray: ColorRgba32 = .fromIntRgb(0x808080);
    pub const red: ColorRgba32 = .fromIntRgb(0xff0000);
    pub const green: ColorRgba32 = .fromIntRgb(0x00ff00);
    pub const blue: ColorRgba32 = .fromIntRgb(0x0000ff);
    pub const yellow: ColorRgba32 = .fromIntRgb(0xffff00);
    pub const cyan: ColorRgba32 = .fromIntRgb(0x00ffff);
    pub const magenta: ColorRgba32 = .fromIntRgb(0xff00ff);
    pub const orange: ColorRgba32 = .fromIntRgb(0xff8000);
    pub const aqua: ColorRgba32 = .fromIntRgb(0x0080ff);
    
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    
    pub fn rgb(r: u8, g: u8, b: u8) ColorRgba32 {
        return .{ .r = r, .g = g, .b = b, .a = 0xff };
    }
    
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) ColorRgba32 {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
    
    pub fn fromIntensity(i: u8) ColorRgba32 {
        return .{ .r = i, .g = i, .b = i, .a = 0xff };
    }
    
    pub fn fromIntensityAlpha(i: u8, a: u8) ColorRgba32 {
        return .{ .r = i, .g = i, .b = i, .a = a };
    }
    
    pub fn fromIntRgb(int_rgb: u32) ColorRgba32 {
        return .rgb(
            @intCast((int_rgb >> 16) & 0xff),
            @intCast((int_rgb >> 8) & 0xff),
            @intCast(int_rgb & 0xff),
        );
    }
    
    pub fn fromIntArgb(int_argb: u32) ColorRgba32 {
        return .rgba(
            @intCast((int_argb >> 16) & 0xff),
            @intCast((int_argb >> 8) & 0xff),
            @intCast(int_argb & 0xff),
            @intCast((int_argb >> 24) & 0xff),
        );
    }
    
    pub fn toIntArgb(self: ColorRgba32) u32 {
        return (
            (@as(u32, self.a) << 24) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            self.b
        );
    }
    
    pub fn withRed(self: ColorRgba32, r: u8) ColorRgba32 {
        return .{ .r = r, .g = self.g, .b = self.b, .a = self.a };
    }
    
    pub fn withGreen(self: ColorRgba32, g: u8) ColorRgba32 {
        return .{ .r = self.r, .g = g, .b = self.b, .a = self.a };
    }
    
    pub fn withBlue(self: ColorRgba32, b: u8) ColorRgba32 {
        return .{ .r = self.r, .g = self.g, .b = b, .a = self.a };
    }
    
    pub fn withAlpha(self: ColorRgba32, a: u8) ColorRgba32 {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = a };
    }
};

/// Provides an interface for loading and reading image data.
/// Wraps a `zigimg.Image`, but could wrap something else in the future
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
