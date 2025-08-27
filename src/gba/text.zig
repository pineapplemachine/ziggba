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

/// Helper used for text-drawing functions.
/// Provides a common interface for laying out text.
pub const GlyphLayoutIterator = struct {
    // TODO: Might be helpful to support line wrapping
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
        x: u16 = 0,
        y: u16 = 0,
        next_x: u16 = 0,
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
    
    /// Options accepted by `init`.
    pub const InitOptions = struct {
        /// Text to be laid out.
        text: []const u8,
        /// X position of text, top-left corner.
        x: u16,
        /// Y position of text, top-left corner.
        y: u16,
        /// Clip text rendering exceeding this width in pixels.
        max_width: u16 = 0xffff,
        /// Clip text rendering exceeding this height in pixels.
        max_height: u16 = 0xffff,
        /// Increment Y by this amount for new lines.
        line_height: u8 = full_height,
        // Width of the space character 0x20 `' '`.
        space_width: u8 = default_space_width,
        /// Characters normally less wide than this are padded to this width.
        /// Can be used, for example, to make text appear monospace.
        pad_character_width: u8 = 0,
        /// Text wrapping behavior.
        wrap: Wrap = .none,
    };
    
    points: CodePointIterator,
    max_x: u16 = 0xffff,
    max_y: u16 = 0xffff,
    line_height: u8 = full_height,
    space_width: u8 = default_space_width,
    pad_character_width: u8 = 0,
    x_initial: u16,
    x: u16,
    y: u16,
    wrap: Wrap,
    
    pub fn init(options: InitOptions) GlyphLayoutIterator {
        return .{
            .points = .init(options.text),
            .max_x = options.max_width +| options.x,
            .max_y = options.max_height +| options.y,
            .x_initial = options.x,
            .x = options.x,
            .y = options.y + options.line_height - full_height,
            .line_height = options.line_height,
            .space_width = options.space_width,
            .pad_character_width = options.pad_character_width,
            .wrap = options.wrap,
        };
    }
    
    fn startNextLine(self: *GlyphLayoutIterator) void {
        self.x = self.x_initial;
        self.y += self.line_height;
    }
    
    pub fn next(self: *GlyphLayoutIterator) Glyph {
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
                        return glyph;
                    }
                }
            }
        }
        return .unprintable;
    }
    
    /// Helper called by `GlyphLayoutIterator.next` for a matching charset.
    fn layoutGlyph(
        self: GlyphLayoutIterator,
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

/// Options accepted by `drawToCharblock4Bpp`.
pub const DrawToCharblock4BppOptions = struct {
    /// Location in memory where the text should be drawn.
    /// This tile is treated as the top-left corner.
    /// Normally, this should be a location in VRAM.
    target: [*]volatile gba.display.Tile4Bpp,
    /// Determines how many tiles are considered to constitute one row.
    /// Number of tiles wide is computed as `1 << pitch_shift`.
    ///
    /// You probably want this to be the width in 8x8 tiles of the
    /// destination where the text will be drawn, i.e. not more than
    /// `1 << 5 == 32` (includes full width of the GBA's screen).
    pitch_shift: u4 = 5,
    /// Palette color index for drawn text.
    color: u4,
    /// The text to draw, either ASCII or UTF-8 encoded.
    text: []const u8,
    /// Start drawing text at this X position.
    x: u16,
    /// Start drawing text at this Y position.
    y: u16,
    /// Clip text past this width.
    ///
    /// This applies from the top-left corner of reserved space, not from the
    /// (X, Y) coordinate of drawn text.
    ///
    /// If this value is larger than `8px << pitch_shift`, then the text
    /// is clipped to that width limit instead.
    max_width: u16 = 0xffff,
    /// Clip text past this height.
    ///
    /// This applies from the top-left corner of reserved space, not from the
    /// (X, Y) coordinate of drawn text.
    max_height: u16 = 0xffff,
    /// Added to Y position to represent a newline ('\n').
    line_height: u8 = 12,
    /// Width in pixels of the space character (' ', 0x20).
    /// Default is 3 pixels. For monospace text with ASCII digits and
    /// upper-case letters, use 6 pixels.
    space_width: u8 = GlyphLayoutIterator.default_space_width,
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
    wrap: GlyphLayoutIterator.Wrap = .none,
};

// TODO: Add similar functions for other kinds of render targets.

/// Draw text to memory structured as 16-color background or object tile data.
pub fn drawToCharblock4Bpp(options: DrawToCharblock4BppOptions) void {
    var layoutGlyphs = GlyphLayoutIterator.init(.{
        .text = options.text,
        .x = options.x,
        .y = options.y,
        .max_width = @min(options.max_width, @as(u16, 8) << options.pitch_shift),
        .max_height = options.max_height,
        .line_height = options.line_height,
        .space_width = options.space_width,
        .pad_character_width = options.pad_character_width,
        .wrap = options.wrap,
    });
    while(true) {
        @setRuntimeSafety(false);
        const glyph = layoutGlyphs.next();
        if(glyph.isEof()) {
            return;
        }
        else if(glyph.isUnprintable()) {
            continue;
        }
        for(0..glyph.size_y) |row_i| {
            var row = glyph.getDataRow(@truncate(row_i));
            for(0..glyph.size_x) |col_i| {
                const pixel = row & 1;
                row >>= 1;
                if(pixel != 0) {
                    const px_x = glyph.x + col_i;
                    const px_y = glyph.y + row_i;
                    var tile = &options.target[
                        (px_x >> 3) +
                        ((px_y >> 3) << options.pitch_shift)
                    ];
                    tile.setPixel16(
                        @truncate(px_x),
                        @truncate(px_y),
                        options.color,
                    );
                }
            }
        }
    }
}
