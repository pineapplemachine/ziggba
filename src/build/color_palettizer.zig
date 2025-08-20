const std = @import("std");
const assert = @import("std").debug.assert;
const ColorRgba32 = @import("color.zig").ColorRgba32;
const ColorQuantizer = @import("color.zig").ColorQuantizer;
const ColorQuantizerLinear = @import("color.zig").ColorQuantizerLinear;
const savePalette = @import("color.zig").savePalette;
const ColorRgb555 = @import("../gba/color.zig").ColorRgb555;

/// Result type returned by `colorRgbNearestLinear`.
const NearestColorResult = struct {
    /// Index of the nearest color to the input.
    index: u8,
    /// A measurement of distance between the input and the chosen color.
    /// A distance of zero should be taken as indicating an exact match.
    distance: i32,
};

/// Helper to get linear Euclidean distance between two colors, treated
/// as (R, G, B) vectors.
fn colorRgbDistanceLinear(a: ColorRgba32, b: ColorRgba32) i32 {
    const dr = @as(i32, a.r) - @as(i32, b.r);
    const dg = @as(i32, a.g) - @as(i32, b.g);
    const db = @as(i32, a.b) - @as(i32, b.b);
    const dist: i32 = (dg * dg) + (dr * dr) + (db * db);
    return dist;
}

/// Get the index of the color in `colors` with the smallest Euclidean
/// distance, as computed by `colorRgbDistanceLinear`.
/// Lower color indices are given precedence over higher indices.
fn colorRgbNearestLinear(
    find_color: ColorRgba32,
    colors: []const ColorRgba32,
    start_index: u8,
) NearestColorResult {
    assert(start_index < colors.len);
    var nearest_i: u8 = start_index;
    var nearest_dist: i32 = colorRgbDistanceLinear(
        find_color,
        colors[start_index],
    );
    for(start_index + 1..colors.len) |i| {
        const dist = colorRgbDistanceLinear(find_color, colors[i]);
        if(dist < nearest_dist) {
            nearest_i = @intCast(i);
            nearest_dist = dist;
        }
    }
    return .{ .index = nearest_i, .distance = nearest_dist };
}

/// Helper for determining what color in a palette should be used for
/// a corresponding pixel within an image.
pub const Palettizer = struct {
    /// Contains information about a pixel in an image whose color should
    /// be handled and converted.
    pub const Pixel = struct {
        /// Color of the pixel.
        color: ColorRgba32 = .transparent,
        /// X position of the pixel within an image.
        x: u16 = 0,
        /// Y position of the pixel within an image.
        y: u16 = 0,
    };
    
    pub const VTable = struct {
        get: *const fn(*anyopaque, px: Pixel) u8,
        getPalette: *const fn(*anyopaque) []const ColorRgba32,
    };
    
    context: *anyopaque,
    vtable: VTable,
    
    pub fn get(self: Palettizer, px: Pixel) u8 {
        return self.vtable.get(self.context, px);
    }
    
    pub fn getPalette(self: Palettizer) []const ColorRgba32 {
        return self.vtable.getPalette(self.context);
    }
};

/// Simple `Palettizer` implementation which assigns indices based on the
/// nearest linear color match within an array of colors.
///
/// Only the first 16 items are considered for 4bpp tiles,
/// and only the first 256 items for 8bpp tiles.
/// The first palette color is treated as full transparency, to reflect
/// GBA rendering behavior.
///
/// Pixels with less than full 100% opacity are always matched with palette
/// index 0. Otherwise, a Euclidean distance algorithm is used to match the
/// nearest color that isn't at index 0.
pub const PalettizerNearest = struct {
    colors: []const ColorRgba32,
    
    pub fn init(colors: []const ColorRgba32) PalettizerNearest {
        return .{ .colors = colors };
    }
    
    pub fn create(
        allocator: std.mem.Allocator,
        colors: []const ColorRgba32,
    ) !*PalettizerNearest {
        const create_pal = try allocator.create(PalettizerNearest);
        create_pal.* = .init(colors);
        return create_pal;
    }
    
    pub fn pal(self: *PalettizerNearest) Palettizer {
        return .{
            .context = self,
            .vtable = .{
                .get = get,
                .getPalette = getPalette,
            },
        };
    }
    
    pub fn get(ctx: *anyopaque, px: Palettizer.Pixel) u8 {
        const self: *PalettizerNearest = @ptrCast(@alignCast(ctx));
        if (px.color.a < 0xff) {
            // Transparent pixels are always palette index 0
            return 0;
        }
        return colorRgbNearestLinear(px.color, self.colors, 1).index;
    }
    
    pub fn getPalette(ctx: *anyopaque) []const ColorRgba32 {
        const self: *PalettizerNearest = @ptrCast(@alignCast(ctx));
        return self.colors;
    }
};

/// Simple `Palettizer` implementation which is appropriate for images
/// already using a reduced number of colors.
/// It records the first N unique colors that appear as its palette.
/// If there are more than N colors, subsequent pixels are matched to
/// the nearest color with a Euclidean distance calculation.
pub const PalettizerNaive = struct {
    colors: []ColorRgba32,
    colors_count: u32 = 1,
    
    /// Initialize using the provided buffer to store discovered colors.
    pub fn initBuffer(colors: []ColorRgba32) PalettizerNaive {
        assert(colors.len <= 256);
        colors[0] = .transparent;
        return .{ .colors = colors };
    }
    
    /// Initialize and allocate a buffer to contain up to `max_colors`
    /// distinct colors.
    pub fn init(
        allocator: std.mem.Allocator,
        max_colors: usize,
    ) !PalettizerNaive {
        assert(max_colors <= 256);
        const colors = try allocator.alloc(ColorRgba32, max_colors);
        colors[0] = .transparent;
        return .{ .colors = colors };
    }
    
    pub fn create(
        allocator: std.mem.Allocator,
        max_colors: usize,
    ) !*PalettizerNaive {
        const create_pal = try allocator.create(PalettizerNaive);
        create_pal.* = try .init(allocator, max_colors);
        return create_pal;
    }
    
    pub fn pal(self: *PalettizerNaive) Palettizer {
        return .{
            .context = self,
            .vtable = .{
                .get = get,
                .getPalette = getPalette,
            },
        };
    }
    
    pub fn get(ctx: *anyopaque, px: Palettizer.Pixel) u8 {
        const self: *PalettizerNaive = @ptrCast(@alignCast(ctx));
        if (px.color.a < 0xff) {
            // Transparent pixels are always palette index 0
            return 0;
        }
        if(self.colors_count <= 1) {
            self.colors[self.colors_count] = px.color;
            defer self.colors_count += 1;
            return @intCast(self.colors_count);
        }
        const nearest = colorRgbNearestLinear(
            px.color,
            self.colors[0..self.colors_count],
            1,
        );
        if(nearest.distance == 0 or self.colors_count >= self.colors.len) {
            return nearest.index;
        }
        self.colors[self.colors_count] = px.color;
        defer self.colors_count += 1;
        return @intCast(self.colors_count);
    }
    
    pub fn getPalette(ctx: *anyopaque) []const ColorRgba32 {
        const self: *PalettizerNaive = @ptrCast(@alignCast(ctx));
        return self.colors[0..self.colors_count];
    }
};

/// Quantize and save a palettizer's palette as a build step.
pub const SaveQuantizedPalettizerPaletteStep = struct {
    pub const Options = struct {
        /// Optionally specify a name for the build step.
        name: ?[]const u8 = null,
        /// Save the palette belonging to this palettizer instance.
        palettizer: Palettizer,
        /// Quantizer to use for converting 32-bit palette colors to 16-bit
        /// GBA palette colors. Defaults to `ColorQuantizerLinear` if not
        /// specified here.
        quantizer: ?ColorQuantizer = null,
        /// File path to which the palette data should be written.
        output_path: []const u8,
    };
    
    step: std.Build.Step,
    palettizer: Palettizer,
    quantizer: ?ColorQuantizer,
    output_path: []const u8,
    
    pub fn create(b: *std.Build, options: Options) *SaveQuantizedPalettizerPaletteStep {
        const step_name = options.name orelse b.fmt(
            "SaveQuantizedPalettizerPaletteStep {s}",
            .{ options.output_path },
        );
        const save_step = (
            b.allocator.create(SaveQuantizedPalettizerPaletteStep) catch @panic("OOM")
        );
        save_step.* = .{
            .palettizer = options.palettizer,
            .quantizer = options.quantizer,
            .output_path = options.output_path,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b,
                .makeFn = make,
                .name = step_name,
            }),
        };
        return save_step;
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *SaveQuantizedPalettizerPaletteStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Saving palettized palette: {s}",
            .{ self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        const palette_colors = self.palettizer.getPalette();
        const quantized_colors = try step.owner.allocator.alloc(
            ColorRgb555,
            palette_colors.len,
        );
        defer step.owner.allocator.free(quantized_colors);
        const default_quantizer = ColorQuantizerLinear.init();
        const quantizer = (
            self.quantizer orelse default_quantizer.quantizer()
        );
        quantizer.quantizeSlice(palette_colors, quantized_colors, .{});
        try savePalette(quantized_colors, self.output_path);
    }
};
