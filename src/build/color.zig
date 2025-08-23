pub const ColorRgb555 = @import("../gba/color.zig").ColorRgb555;

pub const savePalette = @import("color_palette.zig").savePalette;
pub const SavePaletteStep = @import("color_palette.zig").SavePaletteStep;

pub const Palettizer = @import("color_palettizer.zig").Palettizer;
pub const PalettizerNearest = @import("color_palettizer.zig").PalettizerNearest;
pub const PalettizerNaive = @import("color_palettizer.zig").PalettizerNaive;
pub const SaveQuantizedPalettizerPaletteStep = @import("color_palettizer.zig").SaveQuantizedPalettizerPaletteStep;

pub const convertColorDepthLinear = @import("color_quantizer.zig").convertColorDepthLinear;
pub const ColorQuantizer = @import("color_quantizer.zig").ColorQuantizer;
pub const ColorQuantizerLinear = @import("color_quantizer.zig").ColorQuantizerLinear;

/// Represents 32-bit truecolor with 8-bit red, green, blue, and alpha channels.
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
    
    /// Intensity in red color channel.
    r: u8,
    /// Intensity in green color channel.
    g: u8,
    /// Intensity in blue color channel.
    b: u8,
    /// Alpha level. Determines opacity.
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
