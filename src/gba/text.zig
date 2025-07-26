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
        size_x: u4 = 0,
        size_y: u4 = 0,
        offset_y: u4 = 0,
        kerning_dangle_top_right: bool = false,
        kerning_gap_top_left: bool = false,
        kerning_dangle_bottom_left: bool = false,
        kerning_gap_bottom_right: bool = false,
        data_offset: u16 = 0,
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

pub const charset_latin = Charset{
    .enabled = build_options.text_charset_latin,
    .code_point_min = 0x20,
    .code_point_max = 0x7f,
    .data = @ptrCast(@alignCast(
        if (!build_options.text_charset_latin) &charset_data_empty
        else @embedFile("ziggba_font_latin.bin")
    )),
};

pub const charset_latin_supplement = Charset{
    .enabled = build_options.text_charset_latin_supplement,
    .code_point_min = 0xa0,
    .code_point_max = 0xff,
    .data = @ptrCast(@alignCast(
        if (!build_options.text_charset_latin_supplement) &charset_data_empty
        else @embedFile("ziggba_font_latin_supplement.bin")
    )),
};

pub const charset_kana = Charset{
    .enabled = build_options.text_charset_kana,
    .code_point_min = 0x3040,
    .code_point_max = 0x30ff,
    .data = @ptrCast(@alignCast(
        if (!build_options.text_charset_kana) &charset_data_empty
        else @embedFile("ziggba_font_kana.bin")
    )),
};

// pub const charset_latin = Charset{
//     .enabled = build_options.text_charset_latin,
//     .code_point_min = 0x20,
//     .code_point_max = 0x7f,
//     .data = @ptrCast(@alignCast(@embedFile("ziggba_font_latin.bin"))),
// };

// pub const charset_latin_supplement = Charset{
//     .enabled = build_options.text_charset_latin_supplement,
//     .code_point_min = 0xa0,
//     .code_point_max = 0xff,
//     .data = @ptrCast(@alignCast(@embedFile("ziggba_font_latin_supplement.bin"))),
// };

// pub const charset_kana = Charset{
//     .enabled = build_options.text_charset_kana,
//     .code_point_min = 0x3040,
//     .code_point_max = 0x30ff,
//     .data = @ptrCast(@alignCast(@embedFile("ziggba_font_kana.bin"))),
// };

pub const charsets = [_]Charset{
    charset_latin,
    charset_latin_supplement,
    charset_kana,
};

/// This type can be used to decode and iterator Unicode code points in
/// a UTF-8 encoded string.
///
/// This implementation does not validate that the input is well-formed
/// UTF-8 text. The output may be unpredictable when the iterator attempts
/// to decode invalid UTF-8.
pub const CodePointIterator = struct {
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
                const row_i_2 = row_i << 1;
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
    
    pub const InitOptions = struct {
        text: []const u8,
        x: u16,
        y: u16,
        max_width: u16 = 0xffff,
        max_height: u16 = 0xffff,
        line_height: u8 = 12,
    };
    
    points: CodePointIterator,
    prev_kerning_dangle_top_right: bool = false,
    prev_kerning_gap_bottom_right: bool = false,
    max_width: u16 = 0xffff,
    max_height: u16 = 0xffff,
    line_height: u8 = 12,
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
            .y = options.y + options.line_height - 12,
            .line_height = options.line_height,
        };
    }
    
    pub fn next(self: *GlyphLayoutIterator) Glyph {
        if(self.y >= self.max_height) {
            return .eof;
        }
        const point = self.points.next();
        if(point < 0) {
            return .eof;
        }
        for(charsets) |charset| {
            if(charset.hasData() and charset.containsCodePoint(point)) {
                return self.layoutGlyph(charset, point);
            }
        }
        return .unknown;
    }
    
    /// Helper called by `GlyphLayoutIterator.next` for a matching charset.
    fn layoutGlyph(
        self: *GlyphLayoutIterator,
        charset: Charset,
        point: i32,
    ) Glyph {
        assert(point >= 0);
        assert(charset.hasData());
        const header = charset.getHeader(
            @as(u16, @intCast(point)) - charset.code_point_min
        );
        if(
            (
                header.kerning_dangle_bottom_left and
                self.prev_kerning_gap_bottom_right
            ) or
            (
                header.kerning_gap_top_left and
                self.prev_kerning_dangle_top_right
            )
        ) {
            self.x -= 1;
        }
        const x = self.x;
        const y = self.y;
        if(point == ' ') {
            self.x += 5;
        }
        else if(point == '\t') {
            self.x = (self.x & 0xfff0) + 0x10;
        }
        else if(point == '\n') {
            self.x = self.x_initial;
            self.prev_kerning_gap_bottom_right = false;
            self.prev_kerning_dangle_top_right = false;
            self.y += self.line_height;
        }
        else {
            self.x += header.size_x + 1;
        }
        return .{
            .point = point,
            .data = @ptrCast(&charset.data[header.data_offset]),
            .data_is_wide = header.size_x > 8,
            .x = x,
            .y = y,
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
};

// TODO: Add similar functions for other kinds of render targets.

/// Draw text to memory structured as 16-color background or object tile data.
pub fn drawToCharblock4Bpp(options: DrawToCharblock4BppOptions) void {
    var glyphs = GlyphLayoutIterator.init(.{
        .text = options.text,
        .x = options.x,
        .y = options.y,
        .max_width = @min(options.max_width, @as(u16, 8) << options.pitch_shift),
        .max_height = options.max_height,
        .line_height = options.line_height,
    });
    while(true) {
        const glyph = glyphs.next();
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
                row <<= 1;
                if(pixel != 0) {
                    const px_x = glyph.x + col_i;
                    const px_y = glyph.y + row_i;
                    var tile = options.target[
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
