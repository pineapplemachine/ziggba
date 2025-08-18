//! This module implements a helper for rendering text.
//!
//! This text rendering implementation is intended to be a good general-purpose
//! tool for examples and debugging, prioritizing general applicability and
//! ease of use over performance.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

const build_options = @import("ziggba_build_options");

// The seemingly obvious solution of using an optional pointer for a
// `Charset` without data causes the compiler to crash in 0.14.1.
// https://github.com/ziglang/zig/issues/24593
const charset_data_empty: [0]u8 = .{};

/// Contains data regarding supported character sets for text rendering.
pub const Charset = struct {
    pub const CharHeader = packed struct(u32) {
        /// Width of character in pixels.
        /// If this is 8 or less, then the character's bitmap data is stored
        /// in 8-bit rows. Otherwise, it's stored in 16-bit rows.
        size_x: u4 = 0,
        /// Height of character in pixels.
        /// Indicates the number of rows of bitmap data belonging to this
        /// character.
        size_y: u4 = 0,
        /// A Y offset of this character, representing an amount of empty
        /// space above the first populated row of the character.
        offset_y: u4 = 0,
        /// Unused padding bits.
        _: u4 = 0,
        /// Offset of character bitmap within the binary charset data.
        data_offset: u16 = 0,
    };
    
    pub const none: Charset = .{
        .enabled = false,
        .data = &charset_data_empty,
        .code_point_min = 0,
        .code_point_max = 0,
    };
    
    /// Records whether support for this charset has been enabled in
    /// build options.
    enabled: bool,
    /// Spacing and image data for this charset, if enabled,
    /// or an empty array if not enabled.
    data: []align(2) const u8,
    /// Inclusive low bound of Unicode code point range represented by
    /// this charset.
    code_point_min: u16,
    /// Inclusive high bound of Unicode code point range represented by
    /// this charset.
    code_point_max: u16,
    
    pub inline fn getHeader(self: Charset, index: u16) *align(2) const CharHeader {
        const header_data: [*]align(2) const CharHeader = @ptrCast(self.data);
        return &header_data[index];
    }
    
    pub fn containsCodePoint(self: Charset, point: i32) bool {
        return point >= self.code_point_min and point <= self.code_point_max;
    }
    
    pub fn hasData(self: Charset) bool {
        return self.data.len > 0;
    }
};

const charset_latin_data align(2) = blk: {
    if (build_options.text_charset_latin) {
        break :blk @embedFile("ziggba_font_latin.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_latin = Charset{
    .enabled = build_options.text_charset_latin,
    .code_point_min = 0x20,
    .code_point_max = 0x7f,
    .data = &charset_latin_data,
};

const charset_latin_supplement_data align(2) = blk: {
    if (build_options.text_charset_latin_supplement) {
        break :blk @embedFile("ziggba_font_latin_supplement.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_latin_supplement = Charset{
    .enabled = build_options.text_charset_latin_supplement,
    .code_point_min = 0xa0,
    .code_point_max = 0xff,
    .data = &charset_latin_supplement_data,
};

const charset_greek_data align(2) = blk: {
    if (build_options.text_charset_greek) {
        break :blk @embedFile("ziggba_font_greek.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_greek = Charset{
    .enabled = build_options.text_charset_greek,
    .code_point_min = 0x0370,
    .code_point_max = 0x03ff,
    .data = &charset_greek_data,
};

const charset_cyrillic_data align(2) = blk: {
    if (build_options.text_charset_cyrillic) {
        break :blk @embedFile("ziggba_font_cyrillic.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_cyrillic = Charset{
    .enabled = build_options.text_charset_cyrillic,
    .code_point_min = 0x0400,
    .code_point_max = 0x04ff,
    .data = &charset_cyrillic_data,
};

const charset_arrows_data align(2) = blk: {
    if (build_options.text_charset_arrows) {
        break :blk @embedFile("ziggba_font_arrows.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_arrows = Charset{
    .enabled = build_options.text_charset_arrows,
    .code_point_min = 0x2190,
    .code_point_max = 0x21ff,
    .data = &charset_arrows_data,
};

const charset_cjk_symbols_data align(2) = blk: {
    if (build_options.text_charset_cjk_symbols) {
        break :blk @embedFile("ziggba_font_cjk_symbols.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_cjk_symbols = Charset{
    .enabled = build_options.text_charset_cjk_symbols,
    .code_point_min = 0x3000,
    .code_point_max = 0x303f,
    .data = &charset_cjk_symbols_data,
};

const charset_kana_data align(2) = blk: {
    if (build_options.text_charset_kana) {
        break :blk @embedFile("ziggba_font_kana.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_kana = Charset{
    .enabled = build_options.text_charset_kana,
    .code_point_min = 0x3040,
    .code_point_max = 0x30ff,
    .data = &charset_kana_data,
};

const charset_fullwidth_data align(2) = blk: {
    if (build_options.text_charset_fullwidth) {
        break :blk @embedFile("ziggba_font_fullwidth.bin").*;
    }
    else {
        break :blk charset_data_empty;
    }
};
pub const charset_fullwidth = Charset{
    .enabled = build_options.text_charset_fullwidth,
    .code_point_min = 0xff00,
    .code_point_max = 0xff60,
    .data = &charset_fullwidth_data,
};

pub const all_charsets = [_]Charset{
    charset_latin,
    charset_latin_supplement,
    charset_greek,
    charset_cyrillic,
    charset_arrows,
    charset_cjk_symbols,
    charset_kana,
    charset_fullwidth,
};

const num_enabled_charsets: u8 = blk: {
    var count: u8 = 0;
    for(all_charsets) |charset| {
        count += @intFromBool(charset.hasData());
    }
    break :blk count;
};

pub const enabled_charsets = blk: {
    var array: [num_enabled_charsets]Charset = @splat(.none);
    var array_index: u8 = 0;
    for(all_charsets) |charset| {
        if(charset.hasData()) {
            array[array_index] = charset;
            array_index += 1;
        }
    }
    assert(array_index == array.len);
    break :blk array;
};

/// This type can be used to decode and iterator Unicode code points in
/// a UTF-8 encoded string.
///
/// This implementation does not validate that the input is well-formed
/// UTF-8 text. The output may be unpredictable when the iterator attempts
/// to decode invalid UTF-8.
const CodePointIterator = struct {
    /// UTF-8 encoded text.
    text: []const u8,
    /// Current byte index within the encoded text.
    index: u32 = 0,
    
    pub fn init(text: []const u8) CodePointIterator {
        return CodePointIterator{ .text = text };
    }
    
    /// Decode and return the next Unicode code point.
    /// Returns -1 upon reaching the end of the encoded text.
    /// Return value is undefined when the input is not valid UTF-8.
    pub fn next(self: *CodePointIterator) i32 {
        if(self.index >= self.text.len) {
            return -1;
        }
        const ch0: i32 = self.text[self.index];
        self.index += 1;
        if((ch0 & 0x80) == 0) {
            return ch0;
        }
        if((ch0 & 0xe0) == 0xc0) {
            const ch1: i32 = self.continuation();
            return ((ch0 & 0x1f) << 6) | ch1;
        }
        if((ch0 & 0xf0) == 0xe0) {
            const ch1: i32 = self.continuation();
            const ch2: i32 = self.continuation();
            return ((ch0 & 0x0f) << 12) | (ch1 << 6) | ch2;
        }
        if((ch0 & 0xf8) == 0xf0) {
            const ch1: i32 = self.continuation();
            const ch2: i32 = self.continuation();
            const ch3: i32 = self.continuation();
            return ((ch0 & 0x07) << 18) | (ch1 << 12) | (ch2 << 6) | ch3;
        }
        return 0;
    }
    
    /// Decode the next code point without advancing the position of
    /// the iterator.
    pub fn peek(self: CodePointIterator) i32 {
        const iter = CodePointIterator{ .text = self.text, .index = self.index };
        return iter.next();
    }
    
    /// Helper function used by `CodePointIterator.next` to fetch the
    /// next continuation byte.
    fn continuation(self: *CodePointIterator) u8 {
        if(self.index >= self.text.len) {
            return 0;
        }
        const unit = self.text[self.index];
        self.index += 1;
        return unit & 0x3f;
    }
};

const GlyphLayoutIterator = struct {
    // TODO: Might be helpful to support line wrapping
    // TODO: Support combining characters (e.g. 0x0300-0x036f)
    
    pub const default_space_width = 3;
    pub const full_height = 12;
    pub const full_width = 10;
    
    pub const Glyph = struct {
        pub const eof: Glyph = .{ .point = -1 };
        pub const unknown: Glyph = .{ .point = 0 };
        
        point: i32,
        data: ?[*]const u8 = null,
        data_is_wide: bool = false,
        x: u16 = 0,
        y: u16 = 0,
        size_x: u4 = 0,
        size_y: u4 = 0,
        
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
        
        pub fn isUnknown(self: Glyph) bool {
            return self.data == null;
        }
    };
    
    pub const GlyphAlignment = enum {
        /// Normal character alignment.
        /// Reserves as much horizontal space as it needs and no more.
        normal,
        /// Fullwidth character, aligned to the left side of its reserved space.
        fullwidth_left,
        /// Fullwidth character, aligned to the right side of its reserved space.
        fullwidth_right,
        /// Fullwidth character, horizontally centered within its reserved space.
        fullwidth_center,
    };
    
    /// Get alignment for the glyph corresponding to a given code point.
    pub inline fn getGlyphAlignment(point: i32) GlyphAlignment {
        return switch(point) {
            // CJK Symbols and Punctuation
            0x3000 => .fullwidth_center,
            0x3001, 0x3002 => .fullwidth_left, // '、' '。'
            0x3003...0x3007 => .fullwidth_center,
            0x3008, 0x300a, 0x300c, 0x300e, 0x3010 => .fullwidth_right, // brackets
            0x3009, 0x300b, 0x300d, 0x300f, 0x3011 => .fullwidth_left, // brackets
            0x3012, 0x3013 => .fullwidth_center,
            0x3014, 0x3016, 0x3018, 0x301a => .fullwidth_right, // more brackets
            0x3015, 0x3017, 0x3019, 0x301b => .fullwidth_left, // more brackets
            0x301c => .fullwidth_center,
            0x301d => .fullwidth_right, // quotation mark
            0x301e, 0x301f => .fullwidth_left, // quotation marks
            0x3020...0x3029 => .fullwidth_center,
            0x302a, 0x302b => .fullwidth_left, // tone marks
            0x302c, 0x302d => .fullwidth_right, // tone marks
            0x302e, 0x302f => .fullwidth_left, // more tone marks
            0x3030...0x303f => .fullwidth_center,
            // Hiragana, Katakana
            0x3040...0x30ff => .fullwidth_center,
            // Fullwidth Forms
            0xff00...0xff60 => .fullwidth_center,
            // Everything else...
            else => .normal,
        };
    }
    
    pub const InitOptions = struct {
        text: []const u8,
        x: u16,
        y: u16,
        max_width: u16 = 0xffff,
        max_height: u16 = 0xffff,
        line_height: u8 = full_height,
        space_width: u8 = default_space_width,
        pad_character_width: u8 = 0,
    };
    
    points: CodePointIterator,
    prev_point: i32 = -1,
    max_width: u16 = 0xffff,
    max_height: u16 = 0xffff,
    line_height: u8 = full_height,
    space_width: u8 = default_space_width,
    pad_character_width: u8 = 0,
    x_initial: u16,
    x: u16,
    y: u16,
    
    pub fn init(options: InitOptions) GlyphLayoutIterator {
        return .{
            .points = .init(options.text),
            .max_width = options.max_width,
            .max_height = options.max_height,
            .x_initial = options.x,
            .x = options.x,
            .y = options.y + options.line_height - full_height,
            .line_height = options.line_height,
            .space_width = options.space_width,
            .pad_character_width = options.pad_character_width,
        };
    }
    
    pub fn next(self: *GlyphLayoutIterator) Glyph {
        if(self.y >= self.max_height) {
            return .eof;
        }
        const point = self.points.next();
        defer self.prev_point = point;
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
                self.x = self.x_initial;
                self.y += self.line_height;
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
                        return self.layoutGlyph(charset, point);
                    }
                }
            }
        }
        return .unknown;
    }
    
    /// Helper called by `GlyphLayoutIterator.next` for a matching charset.bdg
    fn layoutGlyph(
        self: *GlyphLayoutIterator,
        charset: Charset,
        point: i32,
    ) Glyph {
        assert(point >= 0);
        assert(charset.hasData());
        const glyph_align = getGlyphAlignment(point);
        const header = charset.getHeader(
            @as(u16, @intCast(point)) - charset.code_point_min
        );
        var x = self.x;
        const y = self.y;
        const size_x = @max(header.size_x, self.pad_character_width);
        if(size_x >= full_width) {
            self.x += size_x + 1;
            if(self.pad_character_width > header.size_x) {
                x += (self.pad_character_width - header.size_x) >> 1;
            }
        }
        else {
            switch(glyph_align) {
                .normal => {
                    self.x += size_x + 1;
                    if(self.pad_character_width > header.size_x) {
                        x += (self.pad_character_width - header.size_x) >> 1;
                    }
                },
                .fullwidth_left => {
                    self.x += full_width;
                },
                .fullwidth_right => {
                    x += full_width - header.size_x - 1;
                    self.x += full_width;
                },
                .fullwidth_center => {
                    x += (full_width - size_x) >> 1;
                    self.x += full_width;
                },
            }
        }
        const data = &charset.data[header.data_offset];
        return .{
            .point = point,
            .data = @ptrCast(data),
            .data_is_wide = header.size_x > 8,
            .x = x,
            .y = y + header.offset_y,
            .size_x = @min(
                header.size_x,
                self.max_width - @min(self.max_width, x),
            ),
            .size_y = @min(
                header.size_y,
                self.max_height - @min(self.max_height, y)
            ),
        };
    }
};

/// Options type accepted by `drawToCharblock4Bpp`.
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
    });
    while(true) {
        @setRuntimeSafety(false);
        const glyph = layoutGlyphs.next();
        if(glyph.isEof()) {
            return;
        }
        else if(glyph.isUnknown()) {
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
