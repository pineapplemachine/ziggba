//! This module implements a helper for rendering text.
//!
//! This text rendering implementation is intended to be a good general-purpose
//! tool for examples and debugging, prioritizing general applicability and
//! ease of use over performance.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

// Imports related to supported character sets.
pub const charset_latin = @import("text_charsets.zig").charset_latin;
pub const charset_latin_supplement = @import("text_charsets.zig").charset_latin_supplement;
pub const charset_greek = @import("text_charsets.zig").charset_greek;
pub const charset_cyrillic = @import("text_charsets.zig").charset_cyrillic;
pub const charset_arrows = @import("text_charsets.zig").charset_arrows;
pub const charset_cjk_symbols = @import("text_charsets.zig").charset_cjk_symbols;
pub const charset_kana = @import("text_charsets.zig").charset_kana;
pub const charset_fullwidth = @import("text_charsets.zig").charset_fullwidth;
pub const all_charsets = @import("text_charsets.zig").all_charsets;
pub const CharsetFlags = @import("text_charsets.zig").CharsetFlags;
pub const Charset = @import("text_charsets.zig").Charset;
pub const enabled_charsets = @import("text_charsets.zig").enabled_charsets;

// Import Unicode-related helpers.
pub const CodePointAlignment = @import("text_unicode.zig").CodePointAlignment;
pub const getCodePointAlignment = @import("text_unicode.zig").getCodePointAlignment;
pub const CodePointIterator = @import("text_unicode.zig").CodePointIterator;

// TODO: It will be tricky in combination with the plan for smarter
// word wrapping, which is going to require a lookahead buffer of a handful
// of characters, but it ought to be feasible to make text layout and rendering
// happen via a stream (e.g. with formatted text).

/// Helper used for text-drawing functions.
/// Provides a common interface for laying out text.
pub const TextLayout = struct {
    // TODO: Support combining characters (e.g. 0x0300-0x036f)
    
    pub const default_space_width = 3;
    pub const full_height = 12;
    pub const full_width = 10;
    
    pub const Wrap = enum(u2) {
        /// No automatic text wrapping.
        none,
        /// Hard cutoffs at the end of lines.
        simple,
        // TODO: `smart` wrap:
        // Try to break at word boundaries, and hyphenate when breaking
        // in the middle of words.
        // This could be reasonably implemented via a lookahead of ~8 chars
        // when nearing the line length limit to find the best place to wrap.
    };
    
    pub const Glyph = struct {
        /// Represents end of text.
        pub const eof: Glyph = .{ .point = -1 };
        /// Unknown or unprintable code point.
        pub const unprintable: Glyph = .{ .point = 0 };
        
        point: i32,
        data: ?[*]const u8 = null,
        data_is_wide: bool = false,
        x: u32 = 0,
        y: u32 = 0,
        next_x: u32 = 0,
        size_x: u4 = 0,
        size_y: u4 = 0,
        truncated_x: bool = false,
        truncated_y: bool = false,
        
        pub fn getDataRow(self: Glyph, row_i: u4) u16 {
            assert(self.data != null);
            const data = self.data orelse unreachable;
            if(!self.data_is_wide) {
                return data[row_i];
            }
            else {
                const row_i_2 = @as(u16, row_i) << 1;
                return data[row_i_2] | (@as(u16, data[row_i_2 + 1]) << 8);
            }
        }
        
        pub fn isEof(self: Glyph) bool {
            return self.point < 0;
        }
        
        pub fn isUnprintable(self: Glyph) bool {
            return self.data == null;
        }
    };
    
    /// Options accepted by `init`, describing how glyphs should be laid out.
    pub const Options = struct {
        /// Start drawing text at this X position.
        x: u32,
        /// Start drawing text at this Y position.
        y: u32,
        /// Clip text exceeding this width in pixels.
        /// Note that this applies from the top-left corner of reserved space,
        /// not from the (X, Y) coordinate of drawn text.
        max_width: u32 = 0xffffffff,
        /// Clip text rendering exceeding this height in pixels.
        /// Note that this applies from the top-left corner of reserved space,
        /// not from the (X, Y) coordinate of drawn text.
        max_height: u32 = 0xffffffff,
        /// Increment Y by this amount for new lines.
        line_height: u8 = full_height,
        /// Width in pixels of the space character (`' '`, 0x20).
        /// Default is 3 pixels. For monospace text with ASCII digits and
        /// upper-case letters, use 6 pixels.
        space_width: u8 = default_space_width,
        /// When a character is less wide than this number of pixels, make it
        /// take up this amount of space anyway.
        ///
        /// Supplying a `space_width` of 6 and a `pad_character_width` of 5
        /// will result in monospace text, if not using any extra wide characters.
        ///
        /// Except for some specially tagged fullwidth characters, the character
        /// will be centered in the widened space.
        pad_character_width: u8 = 0,
        /// Text wrapping behavior.
        wrap: Wrap = .none,
        
        pub fn clampMaxSize(self: Options, max_x: u32, max_y: u32) Options {
            var options: Options = self;
            options.max_width = (
                if(max_x > self.x) @min(options.max_width, max_x - self.x)
                else 0
            );
            options.max_height = (
                if(max_y > self.y) @min(options.max_height, max_y - self.y)
                else 0
            );
            return options;
        }
    };
    
    points: CodePointIterator,
    max_x: u32,
    max_y: u32,
    line_height: u8,
    space_width: u8,
    pad_character_width: u8,
    x_initial: u32,
    y_initial: u32,
    x: u32,
    y: u32,
    wrap: Wrap,
    bounds_min_x: u32,
    bounds_min_y: u32,
    bounds_max_x: u32,
    bounds_max_y: u32,
    
    pub fn init(text: []const u8, options: Options) TextLayout {
        const y = options.y + options.line_height - full_height;
        return .{
            .points = .init(text),
            .max_x = options.max_width +| options.x,
            .max_y = options.max_height +| options.y,
            .x_initial = options.x,
            .y_initial = options.y,
            .x = options.x,
            .y = y,
            .line_height = options.line_height,
            .space_width = options.space_width,
            .pad_character_width = options.pad_character_width,
            .wrap = options.wrap,
            .bounds_min_x = options.x,
            .bounds_min_y = y,
            .bounds_max_x = options.x,
            .bounds_max_y = y,
        };
    }
    
    pub fn getBoundsRect(self: TextLayout) gba.math.RectU32 {
        return .initBounds(
            self.bounds_min_x,
            self.bounds_min_y,
            self.bounds_max_x,
            self.bounds_max_y,
        );
    }
    
    pub fn getBoundsOffset(self: TextLayout) gba.math.Vec2U32 {
        return .init(
            self.bounds_min_x - self.x_initial,
            self.bounds_min_y - self.y_initial,
        );
    }
    
    fn startNextLine(self: *TextLayout) void {
        self.x = self.x_initial;
        self.y += self.line_height;
    }
    
    pub fn next(self: *TextLayout) Glyph {
        if(self.y >= self.max_y) {
            return .eof;
        }
        const point = self.points.next();
        if(point < 0) {
            return .eof;
        }
        switch(point) {
            ' ', 0xa0 => { // space and non-breaking space (nbsp)
                self.x += self.space_width;
            },
            '\t' => { // horizontal tab/line tabulation
                self.x = (self.x & 0xfff0) + 0x10;
            },
            '\n' => { // line feed
                self.startNextLine();
            },
            0x00ad => { // soft hyphen
                // TODO: Printable iff it's the last character on a line
                return .unprintable;
            },
            0x2002 => { // en space
                self.x += full_height >> 1;
            },
            0x2003 => { // em space
                self.x += full_height;
            },
            0x2004 => { // three-per-em space
                const full_height_div3 = comptime(full_height / 3);
                self.x += full_height_div3;
            },
            0x2005 => { // four-per-em space
                self.x += full_height >> 2;
            },
            0x2006 => { // six-per-em space
                const full_height_div6 = comptime(full_height / 6);
                self.x += full_height_div6;
            },
            0x2007 => { // figure space
                self.x += full_width;
            },
            0x2008 => { // punctuation space
                self.x += 3; // width of '.' and ','
            },
            0x2009 => { // thin space
                self.x += 2;
            },
            0x200a => { // hair space
                self.x += 1;
            },
            0x3000 => { // ideographic space
                self.x += full_width;
            },
            else => {
                for(enabled_charsets) |charset| {
                    if(charset.containsCodePoint(point)) {
                        var glyph = self.layoutGlyph(charset, point);
                        if(self.wrap != .none and (
                            glyph.x > self.x_initial and glyph.truncated_x
                        )) {
                            self.startNextLine();
                            glyph = self.layoutGlyph(charset, point);
                        }
                        self.x = glyph.next_x;
                        if(
                            (self.bounds_max_x == self.bounds_min_x) and
                            (self.bounds_max_y == self.bounds_min_y)
                        ) {
                            self.bounds_min_x = glyph.x;
                            self.bounds_min_y = glyph.y;
                        }
                        else {
                            self.bounds_min_x = @min(
                                self.bounds_min_x,
                                glyph.x,
                            );
                            self.bounds_min_y = @min(
                                self.bounds_min_y,
                                glyph.y,
                            );
                        }
                        self.bounds_max_x = @max(
                            self.bounds_max_x,
                            glyph.x + glyph.size_x,
                        );
                        self.bounds_max_y = @max(
                            self.bounds_max_y,
                            glyph.y + glyph.size_y,
                        );
                        return glyph;
                    }
                }
            }
        }
        return .unprintable;
    }
    
    /// Process all glyphs.
    /// This might be useful to compute the bounds of some text.
    pub fn exhaust(self: *TextLayout) void {
        while(!self.next().isEof()) {}
    }
    
    /// Helper called by `TextLayout.next` for a matching charset.
    fn layoutGlyph(
        self: TextLayout,
        charset: Charset,
        point: i32,
    ) Glyph {
        assert(point >= 0);
        assert(charset.hasData());
        const glyph_align = getCodePointAlignment(point);
        const header = charset.getHeader(
            @as(u16, @intCast(point)) - charset.code_point_min
        );
        var next_x = self.x;
        var x = self.x;
        const y = self.y;
        const size_x = @max(header.size_x, self.pad_character_width);
        if(size_x >= full_width) {
            next_x += size_x + 1;
            if(self.pad_character_width > header.size_x) {
                x += (self.pad_character_width - header.size_x) >> 1;
            }
        }
        else {
            switch(glyph_align) {
                .normal => {
                    next_x += size_x + 1;
                    if(self.pad_character_width > header.size_x) {
                        x += (self.pad_character_width - header.size_x) >> 1;
                    }
                },
                .fullwidth_left => {
                    next_x += full_width;
                },
                .fullwidth_right => {
                    x += full_width - header.size_x - 1;
                    next_x += full_width;
                },
                .fullwidth_center => {
                    x += (full_width - size_x) >> 1;
                    next_x += full_width;
                },
            }
        }
        const data = &charset.data[header.data_offset];
        const truncated_x = x > (self.max_x - header.size_x);
        const truncated_y = y > (self.max_y - header.size_y);
        return .{
            .point = point,
            .data = @ptrCast(data),
            .data_is_wide = header.size_x > 8,
            .x = x,
            .y = y + header.offset_y,
            .next_x = next_x,
            .size_x = (
                if(truncated_x) @intCast(self.max_x - header.size_x)
                else header.size_x
            ),
            .size_y = (
                if(truncated_y) @intCast(self.max_y - header.size_y)
                else header.size_y
            ),
            .truncated_x = truncated_x,
            .truncated_y = truncated_y,
        };
    }
};

pub fn TextStyleOptions(comptime PixelT: type) type {
    // TODO: Outline, drop shadow, and potentially other effects
    return struct {
        const Self = @This();
        
        /// Data to write to the surface for each pixel of the displayed text.
        /// Typically either a palette color or `gba.ColorRgb555`, depending
        /// on the type of surface being drawn to.
        pixel: PixelT,
        
        /// Initialize with a foreground pixel/color and no other style effects.
        pub fn init(pixel: PixelT) Self {
            return .{ .pixel = pixel };
        }
    };
}

/// Draw text using a default font provided with ZigGBA.
/// Note that fonts will only be embedded in the ROM and available
/// for drawing text if they are explicitly enabled in build options.
pub fn drawTextLayout(
    comptime SurfaceT: type,
    comptime PixelT: type,
    /// Surface to draw the text to.
    surface: SurfaceT,
    /// Options for text appearance.
    style_options: TextStyleOptions(PixelT),
    /// Object used to determine glyph positions when rendering text.
    layout: *TextLayout,
) void {
    @setRuntimeSafety(false);
    while(true) {
        const glyph = layout.next();
        if(glyph.isEof()) {
            return;
        }
        else if(glyph.isUnprintable()) {
            continue;
        }
        // TODO: It's probably possible to significantly optimize this
        // loop for VRAM by writing 16 bits of pixels at once whenever possible
        for(0..glyph.size_y) |row_i| {
            var row = glyph.getDataRow(@truncate(row_i));
            for(0..glyph.size_x) |col_i| {
                const pixel = row & 1;
                row >>= 1;
                if(pixel != 0) {
                    const px_x = glyph.x + col_i;
                    const px_y = glyph.y + row_i;
                    surface.setPixel(
                        @intCast(px_x),
                        @intCast(px_y),
                        style_options.pixel,
                    );
                }
            }
        }
    }
}

/// Draw text using a default font provided with ZigGBA.
/// Wraps `drawTextLayout`.
pub fn drawText(
    comptime SurfaceT: type,
    comptime PixelT: type,
    /// Surface to draw the text to.
    surface: SurfaceT,
    /// The text to draw, either ASCII or UTF-8 encoded.
    text: []const u8,
    /// Options for text appearance.
    style_options: TextStyleOptions(PixelT),
    /// Options for text layout.
    layout_options: TextLayout.Options,
) void {
    var layout: TextLayout = .init(
        text,
        layout_options.clampMaxSize(surface.getWidth(), surface.getHeight()),
    );
    drawTextLayout(SurfaceT, PixelT, surface, style_options, &layout);
}

/// Draw text using a default font provided with ZigGBA,
/// and get the bounding box rect of drawn pixels.
/// Wraps `drawTextLayout`.
pub fn drawTextGetBounds(
    comptime SurfaceT: type,
    comptime PixelT: type,
    /// Surface to draw the text to.
    surface: SurfaceT,
    /// The text to draw, either ASCII or UTF-8 encoded.
    text: []const u8,
    /// Options for text appearance.
    style_options: TextStyleOptions(PixelT),
    /// Options for text layout.
    layout_options: TextLayout.Options,
) gba.math.RectU32 {
    var layout: TextLayout = .init(
        text,
        layout_options.clampMaxSize(surface.getWidth(), surface.getHeight()),
    );
    drawTextLayout(SurfaceT, PixelT, surface, style_options, &layout);
    return layout.getBoundsRect();
}
