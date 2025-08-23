const std = @import("std");
const assert = @import("std").debug.assert;
const GbaBuild = @import("build.zig").GbaBuild;
const Image = @import("image.zig").Image;
const RectU16 = @import("../gba/math.zig").RectU16;
const Vec2U16 = @import("../gba/math.zig").Vec2U16;

pub const Charset = struct {
    /// Represents an invalid or missing charset.
    pub const none: Charset = .init("", "", .{}, .{});
    
    /// Name of the charset, e.g. `"latin"`.
    name: []const u8,
    /// Name of image containing charset bitmap data.
    image_name: []const u8,
    /// Characters are placed on a grid with the given cell size in pixels.
    grid_size: Vec2U16,
    /// Subrect of the image to take character bitmap data from.
    image_rect: RectU16,
    
    pub fn init(
        name: []const u8,
        image_name: []const u8,
        grid_size: Vec2U16,
        image_rect: RectU16,
    ) Charset {
        return .{
            .name = name,
            .image_name = image_name,
            .grid_size = grid_size,
            .image_rect = image_rect,
        };
    }
};

/// List of supported font charsets which can be individually selected
/// for embedding, depending on one's expected usage of `gba.text`.
pub const charsets = [_]Charset{
    .init("latin", "latin", .init(8, 12), .init(0, 24, 128, 72)),
    .init("latin_supplement", "latin", .init(8, 12), .init(0, 120, 128, 72)),
    .init("greek", "greek", .init(8, 12), .init(0, 0, 128, 108)),
    .init("cyrillic", "cyrillic", .init(9, 12), .init(0, 0, 144, 192)),
    .init("arrows", "arrows", .init(10, 12), .init(0, 0, 160, 84)),
    .init("cjk_symbols", "cjk_symbols", .init(10, 12), .init(0, 0, 160, 48)),
    .init("kana", "kana", .init(10, 12), .init(0, 0, 160, 144)),
    .init("fullwidth", "fullwidth", .init(10, 12), .init(0, 0, 160, 180)),
};

/// Contains a flag for each supported character set.
pub const CharsetFlags = struct {
    pub const none: CharsetFlags = .{};
    pub const all: CharsetFlags = blk: {
        var flags: CharsetFlags = .{};
        for(charsets) |charset| {
            @field(flags, charset.name) = true;
        }
        break :blk flags;
    };
    
    /// Unicode Latin block.
    /// Contains code points 0x20 through 0x7f.
    latin: bool = false,
    /// Unicode Latin1-Supplement block.
    /// Contains code points 0xa0 through 0xff.
    latin_supplement: bool = false,
    /// Unicode Greek and Coptic block.
    /// Contains code points 0x0370 through 0x03ff.
    greek: bool = false,
    /// Unicode Cyrillic block.
    /// Contains code points 0x0400 through 0x04ff.
    cyrillic: bool = false,
    /// Unicode Arrows block.
    /// Contains code points 0x2190 through 0x21ff.
    arrows: bool = false,
    /// Unicode CJK Symbols and Punctuation block.
    /// Contains code points 0x3000 through 0x303f.
    cjk_symbols: bool = false,
    /// Unicode Hiragana block and Katakana block.
    /// Contains code points 0x3040 through 0x30ff.
    kana: bool = false,
    /// Unicode Halfwidth and Fullwidth Forms block.
    /// Contains code points 0xff00 through 0xffee.
    fullwidth: bool = false,
};

/// Helper to check if a glyph pixel is set or not set.
fn isImagePixelSet(image: Image, x: usize, y: usize) bool {
    const color = image.getPixelColor(@intCast(x), @intCast(y));
    return color.a == 0xff and (color.r != 0 or color.g != 0 or color.b != 0);
}

/// Data structure used internally by `buildFont` to represent one glyph
/// found in the source image.
const Glyph = struct {
    image_rect: RectU16,
    x_min: u16,
    x_max: u16,
    y_min: u16,
    y_max: u16,
    rows: std.ArrayList(u16),

    pub fn init(
        image: Image,
        image_rect: RectU16,
        allocator: std.mem.Allocator,
    ) !Glyph {
        var glyph = Glyph{
            .image_rect = image_rect,
            .x_min = image_rect.x + image_rect.width,
            .x_max = image_rect.x,
            .y_min = image_rect.y + image_rect.height,
            .y_max = image_rect.y,
            .rows = std.ArrayList(u16).init(allocator),
        };
        // Find bounds of image data within the grid cell rect.
        for(image_rect.y..image_rect.y + image_rect.height) |px_y| {
            for(image_rect.x..image_rect.x + image_rect.width) |px_x| {
                if(isImagePixelSet(image, px_x, px_y)) {
                    glyph.x_min = @intCast(@min(glyph.x_min, px_x));
                    glyph.x_max = @intCast(@max(glyph.x_max, px_x + 1));
                    glyph.y_min = @intCast(@min(glyph.y_min, px_y));
                    glyph.y_max = @intCast(@max(glyph.y_max, px_y + 1));
                }
            }
        }
        // Check for blank image data.
        if(glyph.x_min >= glyph.x_max or glyph.y_min >= glyph.y_max) {
            return glyph;
        }
        assert(glyph.x_max >= glyph.x_min);
        assert(glyph.x_max - glyph.x_min <= 12);
        assert(glyph.y_max >= glyph.y_min);
        assert(glyph.y_max - glyph.y_min <= 12);
        assert(glyph.y_min >= glyph.image_rect.y);
        assert(glyph.y_min - glyph.image_rect.y <= 12);
        // Build bitmap data.
        for(glyph.y_min..glyph.y_max) |px_y| {
            var row: u16 = 0;
            var col: u4 = 0;
            for(glyph.x_min..glyph.x_max) |px_x| {
                if(isImagePixelSet(image, px_x, px_y)) {
                    row |= (@as(u16, 1) << col);
                }
                col += 1;
            }
            try glyph.rows.append(row);
        }
        // All done!
        return glyph;
    }
    
    pub fn deinit(self: Glyph) void {
        self.rows.deinit();
    }
        
    pub fn isBlank(self: Glyph) bool {
        return self.x_max <= self.x_min or self.y_max <= self.y_min;
    }
    
    /// Write header bytes into a buffer.
    pub fn encodeHeader(self: Glyph, buffer: *std.ArrayList(u8)) !void {
        const width: usize = if(self.x_max >= self.x_min) self.x_max - self.x_min else 0;
        const height: usize = if(self.y_max >= self.y_min) self.y_max - self.y_min else 0;
        const y_offset = self.y_min - self.image_rect.y;
        assert(width >= 0 and width < 16);
        assert(height >= 0 and height < 16);
        assert(y_offset >= 0 and y_offset < 16);
        try buffer.append(@intCast((width & 0xF) | ((height & 0xF) << 4)));
        try buffer.append(@intCast(y_offset & 0xF));
    }

    /// Write bitmap data bytes into a buffer.
    pub fn encodeRows(self: Glyph, buffer: *std.ArrayList(u8)) !void {
        const wide = (self.x_max - self.x_min) > 8;
        for(self.rows.items) |row| {
            if(wide) {
                try buffer.append(@intCast(row & 0xff));
                try buffer.append(@intCast((row >> 8) & 0xff));
            } else {
                try buffer.append(@intCast(row & 0xff));
            }
        }
    }
};

/// This is a convenience wrapper around `buildFont` which accepts
/// an image file path to read image data from.
pub fn buildFontPath(
    image_path: []const u8,
    grid_size: Vec2U16,
    image_rect: RectU16,
    allocator: std.mem.Allocator,
) ![]u8 {
    var image = try Image.fromFilePath(allocator, image_path);
    defer image.deinit();
    return buildFont(image, grid_size, image_rect, allocator);
}

/// This is a convenience wrapper around `buildFont` which accepts
/// both an image file path to read image data from and an output file path
/// to write the resulting data to.
pub fn buildSaveFontPath(
    /// Read image from this path.
    image_path: []const u8,
    /// Write encoded binary font data, suitable for embedding, to this path.
    output_path: []const u8,
    /// Grid cell size in pixels upon which glyphs are aligned.
    grid_size: Vec2U16,
    /// Rectangle within the image to read glyphs from.
    image_rect: RectU16,
    /// Use this allocator.
    allocator: std.mem.Allocator,
) !void {
    const font_data = try buildFontPath(
        image_path,
        grid_size,
        image_rect,
        allocator,
    );
    defer allocator.free(font_data);
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(font_data);
}

/// This function converts monochrome image data (e.g. in PNG format)
/// to a binary representation compatible with `gba.text`.
pub fn buildFont(
    image: Image,
    grid_size: Vec2U16,
    image_rect: RectU16,
    allocator: std.mem.Allocator,
) ![]u8 {
    assert(image.getRect().containsRect(image_rect));
    assert(!grid_size.isZero());
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    // Read glyphs from the image.
    var glyphs = std.ArrayList(Glyph).init(arena.allocator());
    const grid_cols = image_rect.width / grid_size.x;
    const grid_rows = image_rect.height / grid_size.y;
    for(0..grid_rows) |row| {
        for(0..grid_cols) |col| {
            const grid_rect = RectU16{
                .x = @intCast(image_rect.x + col * grid_size.x),
                .y = @intCast(image_rect.y + row * grid_size.y),
                .width = grid_size.x,
                .height = grid_size.y,
            };
            const glyph = try Glyph.init(image, grid_rect, arena.allocator());
            try glyphs.append(glyph);
        }
    }
    // Encode glyph data.
    var headers = std.ArrayList(u8).init(allocator);
    defer headers.deinit();
    var bitmaps = std.ArrayList(u8).init(arena.allocator());
    const headers_len = glyphs.items.len * 4; // 4 bytes per glyph
    for(glyphs.items) |glyph| {
        var offset: usize = 0;
        if(!glyph.isBlank()) {
            offset = bitmaps.items.len + headers_len;
            try glyph.encodeRows(&bitmaps);
        }
        try glyph.encodeHeader(&headers);
        try headers.append(@intCast(offset & 0xff));
        try headers.append(@intCast((offset >> 8) & 0xff));
    }
    // All done!
    assert(headers.items.len == headers_len);
    try headers.appendSlice(bitmaps.items);
    return headers.toOwnedSlice();
}

/// Convert font images as a build step.
pub const BuildFontsStep = struct {
    step: std.Build.Step,
    b: *GbaBuild,
    
    pub fn create(b: *GbaBuild) *BuildFontsStep {
        const fonts_step = (
            b.allocator().create(BuildFontsStep) catch @panic("OOM")
        );
        fonts_step.* = .{
            .b = b,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b.b,
                .makeFn = make,
                .name = "BuildFontsStep",
            }),
        };
        return fonts_step;
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *BuildFontsStep = @fieldParentPtr("step", step);
        const root_node = make_options.progress_node.start(
            "Building ZigGBA fonts",
            charsets.len,
        );
        defer root_node.end();
        inline for(charsets) |charset| {
            const charset_node = make_options.progress_node.start(
                "Building ZigGBA font charset: " ++ charset.name,
                1,
            );
            defer charset_node.end();
            // ;_;
            const image_path = "assets/font_" ++ charset.image_name ++ ".png";
            const image_path_dep = self.b.ziggbaPath(image_path);
            const image_path_cache = image_path_dep.getPath3(self.b.b, step);
            const image_path_str = try image_path_cache.toString(self.b.allocator());
            defer self.b.allocator().free(image_path_str);
            const output_path = "assets/font_" ++ charset.name ++ ".bin";
            const output_path_dep = self.b.ziggbaPath(output_path);
            const output_path_cache = output_path_dep.getPath3(self.b.b, step);
            const output_path_str = try output_path_cache.toString(self.b.allocator());
            defer self.b.allocator().free(output_path_str);
            try buildSaveFontPath(
                image_path_str,
                output_path_str,
                charset.grid_size,
                charset.image_rect,
                self.b.allocator(),
            );
            root_node.completeOne();
        }
    }
};
