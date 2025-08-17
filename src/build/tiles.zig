const std = @import("std");
const Image = @import("image.zig").Image;
const ColorRgba32 = @import("image.zig").ColorRgba32;
const Palettizer = @import("palettizer.zig").Palettizer;

/// Enumeration of possible bit depths for GBA tile data. (Bits per pixel.)
pub const Bpp = @import("../gba/color.zig").Color.Bpp;

/// GBA 16-bit RGB555 color.
pub const GbaColor = @import("../gba/color.zig").Color;

/// Enumeration of options for how many blocks converted tile image data
/// is intended to fit within.
pub const ConvertFit = enum(u3) {
    /// Allow any number of tiles, up to 65,535.
    unlimited = 0,
    /// The number of tiles should fit within one block.
    /// This limit is 512 tiles with 4bpp, or 256 tiles with 8bpp.
    within_block = 1,
    /// The number of tiles should fit within two blocks, i.e. within
    /// the total space for sprite tile data.
    /// This limit is 1024 tiles with 4bpp, or 512 tiles with 8bpp.
    within_2_blocks = 2,
    /// The number of tiles should fit within three blocks.
    within_3_blocks = 3,
    /// The number of tiles should fit within four blocks, i.e. within
    /// the total space for bg tile data.
    /// This limit is 2048 tiles with 4bpp, or 1024 tiles with 8bpp.
    within_4_blocks = 4,
    /// The number of tiles should fit within five blocks.
    within_5_blocks = 5,
    /// The number of tiles should fit within all six blocks.
    /// This limit is 3072 tiles with 4bpp, or 1536 tiles with 8bpp.
    within_6_blocks = 6,
};

/// Options expected by the convertTiles function, to determine its behavior.
pub const ConvertImageTilesOptions = struct {
    /// Allocator for intermediate memory allocations.
    allocator: std.mem.Allocator,
    /// Used to resolve palette indices from colors in the image.
    palettizer: Palettizer,
    /// Value to use for padding behavior with pad_fit and
    /// pad_tiles settings.
    pad: u8 = 0,
    /// Produce an error if the tile data does not fit within
    /// the given constraint.
    fit: ConvertFit = .within_block,
    /// Whether to write 4 or 8 bits per pixel.
    bpp: Bpp,
    /// If the amount of tile data is smaller than indicated by fit,
    /// then pad the rest. (Does not apply when fit is unlimited.)
    pad_fit: bool = false,
    /// Pad the edges of the image to a multiple of 8 pixels,
    /// instead of producing an error for strangely sized images.
    pad_tiles: bool = false,
    /// If not set, then an empty input image will trigger an error.
    allow_empty: bool = false,
};

/// Returned by convertTiles.
pub const ConvertImageTilesOutput = struct {
    /// Buffer containing output data.
    /// This is image data in a raw format, ready to be inserted into GBA VRAM.
    data: []u8,
    /// Number of tiles represented in the output data.
    count: u16,
};

/// Errors that may be produced by convertTiles.
pub const ConvertImageTilesError = error{
    /// Palette function returned a value that was out of range given the
    /// image encoding settings.
    UnexpectedPaletteIndex,
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
    /// The image contains too much tile data to fit within the space
    /// determined by the "fit" option.
    TooManyTiles,
};

/// This is a convenience wrapper around `convertImageTiles` which accepts
/// an image file path to read image data from.
pub fn convertImageTilesPath(
    image_path: []const u8,
    options: ConvertImageTilesOptions,
) !ConvertImageTilesOutput {
    var image = try Image.fromFilePath(options.allocator, image_path);
    defer image.deinit();
    return convertImageTiles(image, options);
}

/// This is a convenience wrapper around `convertImageTiles` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn convertSaveImagePath(
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTilesOptions,
) !void {
    const tiles_data = try convertImageTilesPath(image_path, options);
    defer options.allocator.free(tiles_data.data);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(tiles_data.data);
}

/// Convert an arbitrary image to uncompressed tile data which may be
/// copied as-is into VRAM tile memory.
/// Tiles are taken from the image data in 8x8 pixel blocks, starting
/// in the top left corner (at 0, 0) proceeding in rows from left to right,
/// then top to bottom.
/// If the image contains more tiles than will fit into a single charblock
/// in the GBA's VRAM, you will need to make this intention explicit in
/// the options object. Otherwise, the function will fail with an error.
/// The limit per charblock is 128 4bpp tiles or 64 8bpp tiles.
/// When conversion is successful, the function returns a buffer allocated
/// using the provided allocator, containing the converted image data.
pub fn convertImageTiles(
    image: Image,
    options: ConvertImageTilesOptions,
) !ConvertImageTilesOutput {
    if (!image.isValid()) {
        return ConvertImageTilesError.InvalidImage;
    }
    // Check image size
    if (image.getWidth() > 0xffff or image.getHeight() > 0xffff) {
        return ConvertImageTilesError.ImageTooLarge;
    }
    else if (!options.allow_empty and (
        image.getWidth() <= 0 or image.getHeight() <= 0
    )) {
        return ConvertImageTilesError.EmptyImage;
    }
    var image_tiles_x: u16 = @truncate(image.getWidth() >> 3);
    var image_tiles_y: u16 = @truncate(image.getHeight() >> 3);
    if (image.getWidth() & 0x7 != 0) {
        if (!options.pad_tiles) {
            return ConvertImageTilesError.UnexpectedImageSize;
        }
        image_tiles_x += 1;
    }
    if (image.getHeight() & 0x7 != 0) {
        if (!options.pad_tiles) {
            return ConvertImageTilesError.UnexpectedImageSize;
        }
        image_tiles_y += 1;
    }
    const bpp_shift: u4 = if (options.bpp == .bpp_4) 0 else 1;
    const tile_count = image_tiles_x * image_tiles_y;
    const tile_limit = (512 * @as(u16, @intFromEnum(options.fit))) >> bpp_shift;
    if (options.fit == .unlimited) {
        if (tile_count >= 0xffff) {
            return ConvertImageTilesError.TooManyTiles;
        }
    }
    else {
        if (tile_count > tile_limit) {
            return ConvertImageTilesError.TooManyTiles;
        }
    }
    // Encode image data
    var data = std.ArrayList(u8).init(options.allocator);
    defer data.deinit();
    var tile_x: u16 = 0;
    var tile_y: u16 = 0;
    var pal_index_prev: u8 = 0;
    for (0..tile_count) |_| {
        for (0..8) |pixel_y| {
            for (0..8) |pixel_x| {
                const image_x: u16 = @intCast(tile_x + pixel_x);
                const image_y: u16 = @intCast(tile_y + pixel_y);
                var pal_index: u8 = 0;
                if (!image.isInBounds(image_x, image_y)) {
                    pal_index = options.pad;
                }
                else {
                    pal_index = options.palettizer.get(.{
                        .color = image.getPixelColor(pixel_x, pixel_y),
                        .x = image_x,
                        .y = image_y,
                        .bpp = options.bpp,
                    });
                }
                if (options.bpp == .bpp_4) {
                    if (pal_index >= 16) {
                        return ConvertImageTilesError.UnexpectedPaletteIndex;
                    }
                    if ((pixel_x & 1) != 0) {
                        try data.append(pal_index_prev | (pal_index << 4));
                    }
                    else {
                        pal_index_prev = pal_index;
                    }
                }
                else {
                    try data.append(pal_index);
                }
            }
        }
        tile_x += 8;
        if (tile_x >= image.getWidth()) {
            tile_x = 0;
            tile_y += 8;
        }
    }
    // Apply padding, when necessary
    if (options.pad_fit and options.fit != .unlimited and data.items.len < tile_limit) {
        try data.appendNTimes(options.pad, tile_limit - data.items.len);
    }
    // All done
    return ConvertImageTilesOutput{
        .data = try data.toOwnedSlice(),
        .count = tile_count,
    };
}

/// Convert an image as a build step.
pub const ConvertImageTilesStep = struct {
    pub const InitOptions = struct {
        name: ?[]const u8 = null,
        image_path: []const u8,
        output_path: []const u8,
        options: ConvertImageTilesOptions,
    };
    
    step: std.Build.Step,
    image_path: []const u8,
    output_path: []const u8,
    options: ConvertImageTilesOptions,
    output: ?ConvertImageTilesOutput = null,
    
    pub fn init(b: *std.Build, options: InitOptions) ConvertImageTilesStep {
        return .{
            .image_path = options.image_path,
            .output_path = options.output_path,
            .options = options.options,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b,
                .makeFn = make,
                .name = options.name orelse b.fmt(
                    "ConvertImageTilesStep {s} -> {s}",
                    .{ options.image_path, options.output_path },
                ),
            }),
        };
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *ConvertImageTilesStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Converting image tiles: {s} -> {s}",
            .{ self.image_path, self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try convertSaveImagePath(
            self.image_path,
            self.output_path,
            self.options,
        );
    }
};
