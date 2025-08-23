/// Enumeration of recognized Unicode code point alignments, as returned by
/// `getCodePointAlignment`.
pub const CodePointAlignment = enum {
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

/// Get alignment information for a Unicode code point.
pub fn getCodePointAlignment(point: i32) CodePointAlignment {
    return switch(point) {
        // Etc.
        -0x80000000...-1 => .normal,
        0x0000...0x2fff => .normal,
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
        // Etc.
        0x3100...0xfeff => .normal,
        // Fullwidth Forms
        0xff00...0xff07 => .fullwidth_center,
        0xff08 => .fullwidth_right, // '（'
        0xff09 => .fullwidth_left, // '）'
        0xff0a, 0xff0b => .fullwidth_center,
        0xff0c => .fullwidth_left, // '，'
        0xff0d => .fullwidth_center,
        0xff0e => .fullwidth_left, // '．'
        0xff0f...0xff19 => .fullwidth_center,
        0xff1a, 0xff1b => .fullwidth_left, // '：', '；'
        0xff1c...0xff1e => .fullwidth_center,
        0xff1f => .fullwidth_left, // '？'
        0xff20...0xff3a => .fullwidth_center,
        0xff3b => .fullwidth_right, // '［'
        0xff3c => .fullwidth_center,
        0xff3d => .fullwidth_left, // '］'
        0xff3e...0xff5a => .fullwidth_center,
        0xff5b => .fullwidth_right, // '｛'
        0xff5c => .fullwidth_center,
        0xff5d => .fullwidth_left, // '｝'
        0xff5e => .fullwidth_center,
        0xff5f => .fullwidth_right, // '｟'
        0xff60 => .fullwidth_left, // '｠'
        0xff61...0xff65 => .fullwidth_center,
        0xff66...0xffdf => .normal, // halfwidth forms
        0xffe0...0xffee => .fullwidth_center,
        // Etc.
        0xffef...0x7fffffff => .normal,
    };
}

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
