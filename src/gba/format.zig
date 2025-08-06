const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

test {
    _ = @import("test/format_int.zig");
}

/// Default value for `FormatDecimalIntOptions.decimal_digits`.
pub const decimal_digits_ascii: [10]u8 = (
    .{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }
);

/// Get the number of digits in a number's decimal representation.
/// Does not count the sign, only digits.
pub fn lenDecimalI32(n: i32) u4 {
    if(n == -2147483648) {
        return 10;
    }
    const n_abs: i32 = if(n >= 0) n else -%n;
    return switch(n_abs) {
        0...9 => 1,
        10...99 => 2,
        100...999 => 3,
        1000...9999 => 4,
        10000...99999 => 5,
        100000...999999 => 6,
        1000000...9999999 => 7,
        10000000...99999999 => 8,
        100000000...999999999 => 9,
        else => 10,
    };
}

/// Options type accepted by `formatDecimalI32`.
pub const FormatDecimalIntOptions = struct {
    /// Array of decimal digits, e.g. `'0'...'9'`.
    decimal_digits: [10]u8 = decimal_digits_ascii,
    /// This character is prepended to negative numbers.
    sign_negative_char: u8 = '-',
    /// This character may be prepended to positive numbers, if `always_sign`
    /// is true.
    sign_positive_char: u8 = '+',
    /// Always prepend a `sign_positive_char` for non-negative numbers,
    /// not only `sign_negative_char` for negative ones.
    always_sign: bool = false,
    /// If the output string would be shorter than this many bytes,
    /// prepend enough `pad_left_char` to match this padded length.
    pad_left_len: u8 = 0,
    /// Padding byte, for use with `pad_left_len`.
    pad_left_char: u8 = ' ',
};

/// Write a human-readable decimal representation of an integer to a target
/// buffer. Uses ASCII encoding.
///
/// Normally, the longest string written to the buffer by this function will
/// be `-2147483648`, 11 characters long.
/// This could be longer, depending on `options.pad_left_len`.
///
/// Returns the number of bytes written to the output buffer.
pub fn formatDecimalI32(
    buffer: [*]volatile u8,
    value: i32,
    options: FormatDecimalIntOptions,
) u8 {
    @setRuntimeSafety(false);
    var i: u8 = 0;
    // Special case: 0
    if(value == 0) {
        const z_len: u2 = if(options.always_sign) 2 else 1;
        if(options.pad_left_len > z_len) {
            for(0..options.pad_left_len - z_len) |_| {
                buffer[i] = options.pad_left_char;
                i += 1;
            }
        }
        if(options.always_sign) {
            buffer[i] = options.sign_positive_char;
            i += 1;
        }
        buffer[i] = options.decimal_digits[0];
        return i + 1;
    }
    // Special case: Avoid overflow with -2147483648
    else if(value == -2147483648) {
        if(options.pad_left_len > 11) {
            for(0..options.pad_left_len - 11) |_| {
                buffer[i] = options.pad_left_char;
                i += 1;
            }
        }
        buffer[i] = options.sign_negative_char;
        i += 1;
        buffer[i] = options.decimal_digits[2];
        i += 1;
        buffer[i] = options.decimal_digits[1];
        i += 1;
        buffer[i] = options.decimal_digits[4];
        i += 1;
        buffer[i] = options.decimal_digits[7];
        i += 1;
        buffer[i] = options.decimal_digits[4];
        i += 1;
        buffer[i] = options.decimal_digits[8];
        i += 1;
        buffer[i] = options.decimal_digits[3];
        i += 1;
        buffer[i] = options.decimal_digits[6];
        i += 1;
        buffer[i] = options.decimal_digits[4];
        i += 1;
        buffer[i] = options.decimal_digits[8];
        return i + 1;
    }
    // General case
    var v_abs: i32 = if(value >= 0) value else -value;
    var i_end: u8 = (
        @intFromBool(value < 0 or options.always_sign) +
        lenDecimalI32(v_abs)
    );
    while(i_end < options.pad_left_len) {
        buffer[i] = options.pad_left_char;
        i += 1;
        i_end += 1;
    }
    var i_reverse: i32 = i_end - 1;
    while(v_abs > 0) {
        const div10 = gba.bios.div(v_abs, 10);
        assert(div10.remainder < 10);
        buffer[@intCast(i_reverse)] = (
            options.decimal_digits[@intCast(div10.remainder)]
        );
        i_reverse -%= 1;
        v_abs = div10.quotient;
    }
    if(value < 0) {
        buffer[@intCast(i_reverse)] = options.sign_negative_char;
    }
    else if(options.always_sign) {
        buffer[@intCast(i_reverse)] = options.sign_positive_char;
    }
    return i_end;
}
