const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

const build_options = @import("ziggba_build_options");

/// Contains data regarding supported character sets for text rendering.
pub const Charset = struct {
    /// Represents the structure of a header in charset binary data,
    /// containing metadata about that charset.
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
    
    /// Represents an empty or missing charset.
    /// The `hasData` method returns false for this charset instance.
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
    
    /// Options accepted by `init`.
    pub const InitOptions = struct {
        /// Inclusive low bound of Unicode code point range.
        code_point_min: u16,
        /// Inclusive high bound of Unicode code point range.
        code_point_max: u16,
    };
    
    pub fn init(
        comptime name: []const u8,
        code_point_min: u16,
        code_point_max: u16,
    ) Charset {
        const enabled: bool = @field(build_options.text_charsets, name);
        const data align(2) = blk: {
            if(enabled) {
                break :blk @embedFile("ziggba_font_" ++ name ++ ".bin").*;
            }
            else {
                break :blk charset_data_empty;
            }
        };
        return .{
            .enabled = enabled,
            .code_point_min = code_point_min,
            .code_point_max = code_point_max,
            .data = &data,
        };
    }
    
    /// Get a `CharHeader` representing metadata for this charset.
    pub inline fn getHeader(
        self: Charset,
        index: u16,
    ) *align(2) const CharHeader {
        const header_data: [*]align(2) const CharHeader = @ptrCast(self.data);
        return &header_data[index];
    }
    
    /// Check whether the charset contains glyph image data for a given
    /// Unicode code point.
    pub fn containsCodePoint(self: Charset, point: i32) bool {
        return point >= self.code_point_min and point <= self.code_point_max;
    }
    
    /// Returns true when the charset contains any glyph image data.
    pub fn hasData(self: Charset) bool {
        return self.data.len > 0;
    }
};

// The seemingly obvious solution of using an optional pointer for a
// `Charset` without data causes the compiler to crash in 0.14.1.
// https://github.com/ziglang/zig/issues/24593
const charset_data_empty: [0]u8 = .{};

pub const charset_latin: Charset = .init("latin", 0x20, 0x7f);
pub const charset_latin_supplement: Charset = .init("latin_supplement", 0xa0, 0xff);
pub const charset_greek: Charset = .init("greek", 0x0370, 0x03ff);
pub const charset_cyrillic: Charset = .init("cyrillic", 0x0400, 0x04ff);
pub const charset_arrows: Charset = .init("arrows", 0x2190, 0x21ff);
pub const charset_cjk_symbols: Charset = .init("cjk_symbols", 0x3000, 0x303f);
pub const charset_kana: Charset = .init("kana", 0x3040, 0x30ff);
pub const charset_fullwidth: Charset = .init("fullwidth", 0xff00, 0xff60);

/// List of all supported charsets.
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

/// Contains a flag for each supported character set.
pub const CharsetFlags = struct {
    /// No flags set.
    pub const none: CharsetFlags = .{};
    /// All flags set.
    pub const all: CharsetFlags = blk: {
        var flags: CharsetFlags = .{};
        for(@typeInfo(CharsetFlags).@"struct".fields) |field| {
            @field(flags, field.name) = true;
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

const num_enabled_charsets: u8 = blk: {
    var count: u8 = 0;
    for(all_charsets) |charset| {
        count += @intFromBool(charset.hasData());
    }
    break :blk count;
};

/// List of all supported charsets whose font image data has been embedded
/// based on ZigGBA's build options.
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
