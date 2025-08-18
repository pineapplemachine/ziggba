const std = @import("std");
const assert = @import("std").debug.assert;
const Palettizer = @import("color.zig").Palettizer;
const ColorRgba32 = @import("color.zig").ColorRgba32;
const ColorRgb555 = @import("../gba/color.zig").ColorRgb555;

/// Naïve bit depth conversion from 8-bit to 5-bit color channels.
pub fn convertColorDepthLinear(truecolor: ColorRgba32) ColorRgb555 {
    return .rgb(
        @intCast(truecolor.r >> 3),
        @intCast(truecolor.g >> 3),
        @intCast(truecolor.b >> 3),
    );
}

/// Helper for determining what color in a palette should be used for
/// a corresponding pixel within an image.
pub const ColorQuantizer = struct {
    pub const Pixel = Palettizer.Pixel;
    
    pub const VTable = struct {
        get: *const fn(*anyopaque, px: Pixel) ColorRgb555,
    };
    
    context: *anyopaque,
    vtable: VTable,
    
    pub fn get(self: ColorQuantizer, px: Pixel) ColorRgb555 {
        return self.vtable.get(self.context, px);
    }
    
    pub fn quantizeSlice(
        self: ColorQuantizer,
        colors_in: []const ColorRgba32,
        colors_out: []ColorRgb555,
        px_defaults: ColorQuantizer.Pixel,
    ) void {
        assert(colors_in.len == colors_out.len);
        for(0..colors_out.len) |i| {
            colors_out[i] = self.get(.{
                .color = colors_in[i],
                .x = px_defaults.x,
                .y = px_defaults.y,
            });
        }
    }
};

pub const ColorQuantizerLinear = struct {
    pub fn init() ColorQuantizerLinear {
        return .{};
    }
    
    pub fn create(allocator: std.mem.Allocator) !*ColorQuantizerLinear {
        return try allocator.create(ColorQuantizerLinear);
    }
    
    pub fn quantizer(self: *const ColorQuantizerLinear) ColorQuantizer {
        return .{
            .context = @constCast(self),
            .vtable = .{
                .get = get,
            },
        };
    }
    
    pub fn get(_: *anyopaque, px: ColorQuantizer.Pixel) ColorRgb555 {
        return convertColorDepthLinear(px.color);
    }
};
