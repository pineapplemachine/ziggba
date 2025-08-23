const std = @import("std");
const assert = @import("std").debug.assert;
const ColorRgba32 = @import("color.zig").ColorRgba32;
const Palettizer = @import("color.zig").Palettizer;
const ColorQuantizer = @import("color.zig").ColorQuantizer;
const Image = @import("image.zig").Image;
const ColorRgb555 = @import("../gba/color.zig").ColorRgb555;
const RectU16 = @import("../gba/math.zig").RectU16;

/// Options expected by `convertImageBitmap8Bpp`.
pub const ConvertImageBitmap8BppOptions = struct {
    /// Used to resolve palette indices from colors in the image.
    palettizer: Palettizer,
    /// Optionally specify a sub-rectangle of the source image to convert.
    rect: ?RectU16 = null,
    /// If not set, then an empty input image will trigger an error.
    allow_empty: bool = false,
};

/// Options expected by `convertImageBitmap16Bpp`.
pub const ConvertImageBitmap16BppOptions = struct {
    /// Convert 32-bit truecolor inputs to 16-bit GBA color outputs.
    quantizer: ColorQuantizer,
    /// Optionally specify a sub-rectangle of the source image to convert.
    rect: ?RectU16 = null,
    /// If not set, then an empty input image will trigger an error.
    allow_empty: bool = false,
};

/// Returned by `convertImageBitmap8Bpp`.
pub const ConvertImageBitmap8BppOutput = struct {
    const Self = @This();
    
    /// Converted bitmap data.
    /// Pixels are represented in row-major order, i.e. the index for a given
    /// pixel coordinate can be computed as `i = x + (y * width)`.
    data: []u8 align(4),
    /// Width of the converted image, in pixels.
    width: u16,
    /// Height of the converted image, in pixels.
    height: u16,
    
    pub fn getPixelColor(self: Self, x: u16, y: u16) u8 {
        assert(x < self.width);
        assert(y < self.height);
        return self.data[x + (y * self.width)];
    }
};

/// Returned by `convertImageBitmap16Bpp`.
pub const ConvertImageBitmap16BppOutput = struct {
    const Self = @This();
    
    /// Converted bitmap data.
    /// Pixels are represented in row-major order, i.e. the index for a given
    /// pixel coordinate can be computed as `i = x + (y * width)`.
    data: []ColorRgb555 align(4),
    /// Width of the converted image, in pixels.
    width: u16,
    /// Height of the converted image, in pixels.
    height: u16,
    
    pub fn getPixelColor(self: Self, x: u16, y: u16) ColorRgb555 {
        assert(x < self.width);
        assert(y < self.height);
        return self.data[x + (y * self.width)];
    }
};

/// Errors that may be produced by `convertImageBitmap8Bpp` or
/// `convertImageBitmap16Bpp`.
const ConvertImageBitmapError = error{
    /// Received an invalid or non-existent image.
    InvalidImage,
    /// The image width and/or height was 0, and the "allow_empty"
    /// option was not used.
    EmptyImage,
    /// Received a sub-rectangle that isn't fully within the image bounds.
    InvalidRect,
};

pub const ConvertImageBitmap8BppError = ConvertImageBitmapError;
pub const ConvertImageBitmap16BppError = ConvertImageBitmapError;

/// This is a convenience wrapper around `convertImageBitmap8Bpp` which accepts
/// an image file path to read image data from.
pub fn convertImageBitmap8BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    options: ConvertImageBitmap8BppOptions,
) !ConvertImageBitmap8BppOutput {
    var image = try Image.fromFilePath(allocator, image_path);
    defer image.deinit();
    return convertImageBitmap8Bpp(allocator, image, options);
}

/// This is a convenience wrapper around `convertImageBitmap8Bpp` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn convertSaveImageBitmap8BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageBitmap8BppOptions,
) !void {
    const tiles_data = try convertImageBitmap8BppPath(allocator, image_path, options);
    defer allocator.free(tiles_data.data);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(tiles_data.data);
}

/// Convert an arbitrary image to uncompressed bitmap data which may be
/// copied as-is into VRAM for display in video mode 4.
pub fn convertImageBitmap8Bpp(
    allocator: std.mem.Allocator,
    image: Image,
    options: ConvertImageBitmap8BppOptions,
) !ConvertImageBitmap8BppOutput {
    // Validate image and handle size
    if (!image.isValid()) {
        return ConvertImageBitmap8BppError.InvalidImage;
    }
    else if (!options.allow_empty and image.isEmpty()) {
        return ConvertImageBitmap8BppError.EmptyImage;
    }
    const rect: RectU16 = options.rect orelse image.getRect();
    if(!image.getRect().containsRect(rect)) {
        return ConvertImageBitmap8BppError.InvalidRect;
    }
    // Encode image data
    var data = try allocator.alloc(u8, image.getSizePixels());
    for(0..rect.height) |pixel_y| {
        for(0..rect.width) |pixel_x| {
            const image_x: u16 = @intCast(pixel_x + rect.x);
            const image_y: u16 = @intCast(pixel_y + rect.y);
            const i = image_x + (image_y * image.getWidth());
            data[i] = options.palettizer.get(.{
                .color = image.getPixelColor(image_x, image_y),
                .x = image_x,
                .y = image_y,
            });
        }
    }
    // All done
    return ConvertImageBitmap8BppOutput{
        .data = data,
        .width = rect.width,
        .height = rect.height,
    };
}

/// This is a convenience wrapper around `convertImageBitmap8Bpp` which accepts
/// an image file path to read image data from.
pub fn convertImageBitmap16BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    options: ConvertImageBitmap16BppOptions,
) !ConvertImageBitmap16BppOutput {
    var image = try Image.fromFilePath(allocator, image_path);
    defer image.deinit();
    return convertImageBitmap16Bpp(allocator, image, options);
}

/// This is a convenience wrapper around `convertImageBitmap16Bpp` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn convertSaveImageBitmap16BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageBitmap16BppOptions,
) !void {
    const tiles_data = try convertImageBitmap16BppPath(allocator, image_path, options);
    defer allocator.free(tiles_data.data);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(tiles_data.data);
}

/// Convert an arbitrary image to uncompressed bitmap data which may be
/// copied as-is into VRAM for display in video modes 3 and 5.
pub fn convertImageBitmap16Bpp(
    allocator: std.mem.Allocator,
    image: Image,
    options: ConvertImageBitmap16BppOptions,
) !ConvertImageBitmap16BppOutput {
    // Validate image and handle size
    if (!image.isValid()) {
        return ConvertImageBitmap16BppError.InvalidImage;
    }
    else if (!options.allow_empty and image.isEmpty()) {
        return ConvertImageBitmap16BppError.EmptyImage;
    }
    const rect: RectU16 = options.rect orelse image.getRect();
    if(!image.getRect().containsRect(rect)) {
        return ConvertImageBitmap16BppError.InvalidRect;
    }
    // Encode image data
    var data = try allocator.alloc(ColorRgb555, image.getSizePixels());
    for(0..rect.height) |pixel_y| {
        for(0..rect.width) |pixel_x| {
            const image_x: u16 = @intCast(pixel_x + rect.x);
            const image_y: u16 = @intCast(pixel_y + rect.y);
            const i = image_x + (image_y * image.getWidth());
            data[i] = options.quantizer.get(.{
                .color = image.getPixelColor(image_x, image_y),
                .x = image_x,
                .y = image_y,
            });
        }
    }
    // All done
    return ConvertImageBitmap16BppOutput{
        .data = data,
        .width = rect.width,
        .height = rect.height,
    };
}

/// Convert an image as a build step.
pub const ConvertImageBitmap8BppStep = struct {
    pub const Options = struct {
        name: ?[]const u8 = null,
        image_path: []const u8,
        output_path: []const u8,
        options: ConvertImageBitmap8BppOptions,
    };
    
    step: std.Build.Step,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageBitmap8BppOptions,
    
    pub fn create(b: *std.Build, options: Options) *ConvertImageBitmap8BppStep {
        const step_name = options.name orelse b.fmt(
            "ConvertImageBitmap8BppStep {s} -> {s}",
            .{ options.image_path, options.output_path },
        );
        const convert_step = (
            b.allocator.create(ConvertImageBitmap8BppStep) catch @panic("OOM")
        );
        convert_step.* = .{
            .image_path = options.image_path,
            .output_path = options.output_path,
            .options = options.options,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b,
                .makeFn = make,
                .name = step_name,
            }),
        };
        return convert_step;
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *ConvertImageBitmap8BppStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Converting image tiles: {s} -> {s}",
            .{ self.image_path, self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try convertSaveImageBitmap8BppPath(
            step.owner.allocator,
            self.image_path,
            self.output_path,
            self.options,
        );
    }
};

/// Convert an image as a build step.
pub const ConvertImageBitmap16BppStep = struct {
    pub const Options = struct {
        name: ?[]const u8 = null,
        image_path: []const u8,
        output_path: []const u8,
        options: ConvertImageBitmap16BppOptions,
    };
    
    step: std.Build.Step,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageBitmap16BppOptions,
    
    pub fn create(b: *std.Build, options: Options) *ConvertImageBitmap16BppStep {
        const step_name = options.name orelse b.fmt(
            "ConvertImageBitmap16BppStep {s} -> {s}",
            .{ options.image_path, options.output_path },
        );
        const convert_step = (
            b.allocator.create(ConvertImageBitmap16BppStep) catch @panic("OOM")
        );
        convert_step.* = .{
            .image_path = options.image_path,
            .output_path = options.output_path,
            .options = options.options,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b,
                .makeFn = make,
                .name = step_name,
            }),
        };
        return convert_step;
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *ConvertImageBitmap16BppStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Converting image tiles: {s} -> {s}",
            .{ self.image_path, self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try convertSaveImageBitmap16BppPath(
            step.owner.allocator,
            self.image_path,
            self.output_path,
            self.options,
        );
    }
};
