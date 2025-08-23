const std = @import("std");
const Image = @import("image.zig").Image;
const ColorRgba32 = @import("color.zig").ColorRgba32;
const Palettizer = @import("color.zig").Palettizer;
const Tile4Bpp = @import("../gba/display.zig").Tile4Bpp;
const Tile8Bpp = @import("../gba/display.zig").Tile8Bpp;

const ConvertImageTilesOptions = struct {
    /// Used to resolve palette indices from colors in the image.
    palettizer: Palettizer,
    /// If not set, then an empty input image will trigger an error.
    allow_empty: bool = false,
};

/// Options expected by `convertImageTiles4Bpp`.
pub const ConvertImageTiles4BppOptions = ConvertImageTilesOptions;

/// Options expected by `convertImageTiles8Bpp`.
pub const ConvertImageTiles8BppOptions = ConvertImageTilesOptions;

/// Returned by `convertImageTiles4Bpp` and `convertImageTiles8Bpp`.
const ConvertImageTilesOutput = struct {
    /// Buffer containing output data.
    /// This is image data in a raw format, ready to be inserted into GBA VRAM.
    data: []u8,
    /// Number of tiles represented in the output data.
    count: u16,
};

const ConvertImageTilesError = error {
    /// The image width and height were not both multiples of 8 pixels,
    /// and the "pad_tiles" option was not used.
    UnexpectedImageSize,
    /// Received an invalid or non-existent image.
    InvalidImage,
    /// The image width and/or height was 0, and the "allow_empty"
    /// option was not used.
    EmptyImage,
    /// The image is larger than 65,355 tiles on either axis.
    ImageTooLarge,
};


/// Errors that may be produced by `convertImageTiles4Bpp`.
pub const ConvertImageTiles4BppError = ConvertImageTilesError || error {
    /// Palettizer returned a color index greater than 15.
    UnexpectedPaletteIndex,
};

/// Errors that may be produced by `convertImageTiles8Bpp`.
pub const ConvertImageTiles8BppError = ConvertImageTilesError;

/// This is a convenience wrapper around `convertImageTiles` which accepts
/// an image file path to read image data from.
pub fn convertImageTiles4BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    options: ConvertImageTiles4BppOptions,
) ![]Tile4Bpp {
    var image = try Image.fromFilePath(allocator, image_path);
    defer image.deinit();
    return convertImageTiles4Bpp(allocator, image, options);
}

/// This is a convenience wrapper around `convertImageTiles4Bpp` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn convertSaveImageTiles4BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTiles4BppOptions,
) !void {
    const tiles = try convertImageTiles4BppPath(allocator, image_path, options);
    defer allocator.free(tiles);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(std.mem.sliceAsBytes(tiles));
}

fn validateImageTileCount(
    comptime OptionsT: type,
    comptime ErrT: type,
    image: Image,
    options: OptionsT,
) ErrT!usize {
    if(!image.isValid()) {
        return ErrT.InvalidImage;
    }
    else if(!options.allow_empty and image.isEmpty()) {
        return ErrT.EmptyImage;
    }
    else if(
        ((image.getWidth() & 0x7) != 0) or
        ((image.getHeight() & 0x7) != 0)
    ) {
        return ErrT.UnexpectedImageSize;
    }
    return (
        @as(usize, image.getWidth() >> 3) *
        @as(usize, image.getHeight() >> 3)
    );
}

/// Convert an arbitrary image to uncompressed tile data which may be
/// copied as-is into VRAM tile memory.
///
/// Tiles are taken from the image data in 8x8 pixel blocks in row-major
/// order, i.e. starting in the top left corner (at 0, 0) proceeding in rows
/// from left to right, then top to bottom.
///
/// When conversion is successful, the function returns a buffer allocated
/// using the provided allocator, containing the converted image data.
pub fn convertImageTiles4Bpp(
    allocator: std.mem.Allocator,
    image: Image,
    options: ConvertImageTiles4BppOptions,
) ![]Tile4Bpp {
    const tile_count = try validateImageTileCount(
        ConvertImageTiles4BppOptions,
        ConvertImageTiles4BppError,
        image,
        options,
    );
    const tiles = try allocator.alloc(Tile4Bpp, tile_count);
    const image_width_tiles = image.getWidth() >> 3;
    for (0..tile_count) |tile_i| {
        for (0..8) |tile_pixel_y| {
            for (0..8) |tile_pixel_x| {
                const image_x: u16 = @intCast(
                    ((tile_i % image_width_tiles) << 3) + tile_pixel_x
                );
                const image_y: u16 = @intCast(
                    ((tile_i / image_width_tiles) << 3) + tile_pixel_y
                );
                const pal_index = options.palettizer.get(.{
                    .color = image.getPixelColor(image_x, image_y),
                    .x = image_x,
                    .y = image_y,
                });
                if(pal_index >= 16) {
                    return ConvertImageTiles4BppError.UnexpectedPaletteIndex;
                }
                tiles[tile_i].setPixel8(
                    @intCast(tile_pixel_x),
                    @intCast(tile_pixel_y),
                    @intCast(pal_index),
                );
            }
        }
    }
    return tiles;
}

/// This is a convenience wrapper around `convertImageTiles` which accepts
/// an image file path to read image data from.
pub fn convertImageTiles8BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    options: ConvertImageTiles8BppOptions,
) ![]Tile8Bpp {
    var image = try Image.fromFilePath(allocator, image_path);
    defer image.deinit();
    return convertImageTiles8Bpp(allocator, image, options);
}

/// This is a convenience wrapper around `convertImageTiles8Bpp` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn convertSaveImageTiles8BppPath(
    allocator: std.mem.Allocator,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTiles8BppOptions,
) !void {
    const tiles = try convertImageTiles8BppPath(allocator, image_path, options);
    defer allocator.free(tiles);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(std.mem.sliceAsBytes(tiles));
}

/// Convert an arbitrary image to uncompressed tile data which may be
/// copied as-is into VRAM tile memory.
///
/// Tiles are taken from the image data in 8x8 pixel blocks in row-major
/// order, i.e. starting in the top left corner (at 0, 0) proceeding in rows
/// from left to right, then top to bottom.
///
/// When conversion is successful, the function returns a buffer allocated
/// using the provided allocator, containing the converted image data.
pub fn convertImageTiles8Bpp(
    allocator: std.mem.Allocator,
    image: Image,
    options: ConvertImageTiles8BppOptions,
) ![]Tile8Bpp {
    const tile_count = try validateImageTileCount(
        ConvertImageTiles4BppOptions,
        ConvertImageTiles4BppError,
        image,
        options,
    );
    const tiles = try allocator.alloc(Tile8Bpp, tile_count);
    const image_width_tiles = image.getWidth() >> 3;
    for (0..tile_count) |tile_i| {
        for (0..8) |tile_pixel_y| {
            for (0..8) |tile_pixel_x| {
                const image_x: u16 = @intCast(
                    ((tile_i % image_width_tiles) << 3) + tile_pixel_x
                );
                const image_y: u16 = @intCast(
                    ((tile_i / image_width_tiles) << 3) + tile_pixel_y
                );
                const pal_index = options.palettizer.get(.{
                    .color = image.getPixelColor(image_x, image_y),
                    .x = image_x,
                    .y = image_y,
                });
                tiles[tile_i].setPixel8(
                    @intCast(tile_pixel_x),
                    @intCast(tile_pixel_y),
                    pal_index,
                );
            }
        }
    }
    return tiles;
}

/// Convert an image as a build step.
pub const ConvertImageTiles4BppStep = struct {
    pub const Options = struct {
        name: ?[]const u8 = null,
        image_path: []const u8,
        output_path: []const u8,
        options: ConvertImageTiles4BppOptions,
    };
    
    step: std.Build.Step,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTiles4BppOptions,
    
    pub fn create(b: *std.Build, options: Options) *ConvertImageTiles4BppStep {
        const step_name = options.name orelse b.fmt(
            "ConvertImageTiles4BppStep {s} -> {s}",
            .{ options.image_path, options.output_path },
        );
        const convert_step = (
            b.allocator.create(ConvertImageTiles4BppStep) catch @panic("OOM")
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
        const self: *ConvertImageTiles4BppStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Converting image tiles: {s} -> {s}",
            .{ self.image_path, self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try convertSaveImageTiles4BppPath(
            step.owner.allocator,
            self.image_path,
            self.output_path,
            self.options,
        );
    }
};

/// Convert an image as a build step.
pub const ConvertImageTiles8BppStep = struct {
    pub const Options = struct {
        name: ?[]const u8 = null,
        image_path: []const u8,
        output_path: []const u8,
        options: ConvertImageTiles8BppOptions,
    };
    
    step: std.Build.Step,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTiles8BppOptions,
    
    pub fn create(b: *std.Build, options: Options) *ConvertImageTiles8BppStep {
        const step_name = options.name orelse b.fmt(
            "ConvertImageTiles8BppStep {s} -> {s}",
            .{ options.image_path, options.output_path },
        );
        const convert_step = (
            b.allocator.create(ConvertImageTiles8BppStep) catch @panic("OOM")
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
        const self: *ConvertImageTiles8BppStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Converting image tiles: {s} -> {s}",
            .{ self.image_path, self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try convertSaveImageTiles8BppPath(
            step.owner.allocator,
            self.image_path,
            self.output_path,
            self.options,
        );
    }
};
