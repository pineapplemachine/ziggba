const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

test {
    _ = @import("test/format_int.zig");
}

/// Default value for `FormatDecimalIntOptions.decimal_digits`.
pub const decimal_digits_ascii: [10]u8 = (
    .{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }
);

/// Default value for `FormatHexIntOptions.hex_digits`.
pub const hex_digits_ascii: [16]u8 = .{
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
};

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

/// Get the number of digits in a signed integer's
/// hexadecimal representation.
/// Does not count the sign, only digits.
pub fn lenHexI32(n: i32) u4 {
    if(n == -0x80000000) {
        return 8;
    }
    else {
        return lenHexU32(@abs(n));
    }
}

/// Get the number of digits in an unsigned integer's
/// hexadecimal representation.
pub fn lenHexU32(n: u32) u4 {
    if((n & 0xf0000000) != 0) {
        return 8;
    }
    else if((n & 0x0f000000) != 0) {
        return 7;
    }
    else if((n & 0x00f00000) != 0) {
        return 6;
    }
    else if((n & 0x000f0000) != 0) {
        return 5;
    }
    else if((n & 0x0000f000) != 0) {
        return 4;
    }
    else if((n & 0x00000f00) != 0) {
        return 3;
    }
    else if((n & 0x000000f0) != 0) {
        return 2;
    }
    else {
        return 1;
    }
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
/// buffer.
/// Uses ASCII encoding by default.
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
) u32 {
    @setRuntimeSafety(false);
    var i: u32 = 0;
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
    var i_end: u32 = (
        @intFromBool(value < 0 or options.always_sign) +
        lenDecimalI32(v_abs)
    );
    while(i_end < options.pad_left_len) {
        buffer[i] = options.pad_left_char;
        i += 1;
        i_end += 1;
    }
    var i_reverse: i32 = @intCast(i_end - 1);
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

/// Options type accepted by `formatHexI32`.
pub const FormatHexIntOptions = struct {
    /// Array of hexadecimal digits, e.g. `'0'...'9', 'A'...'F'`.
    hex_digits: [16]u8 = hex_digits_ascii,
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
    /// Pad with leading zeros if the number has fewer digits than this.
    pad_zero_len: u8 = 0,
    /// Optional prefix to add after the sign and before the first digit,
    /// e.g. "0x".
    digits_prefix: []const u8 = "",
};

/// Write a hexadecimal representation of a signed integer to a target buffer.
/// Uses ASCII encoding by default.
///
/// Normally, the longest string written to the buffer by this function will
/// be `-ffffffff`, 9 characters long.
/// This could be longer, depending on `options.digits_prefix` and
/// `options.pad_left_len`.
///
/// Returns the number of bytes written to the output buffer.
pub fn formatHexI32(
    buffer: [*]volatile u8,
    value: i32,
    options: FormatHexIntOptions,
) u32 {
    @setRuntimeSafety(false);
    const digits = lenHexI32(value);
    const len = (
        options.digits_prefix.len +
        @intFromBool(value < 0 or options.always_sign) +
        @max(digits, options.pad_zero_len)
    );
    var shift: u5 = @as(u5, digits - 1) << 2;
    var i: u32 = 0;
    if(options.pad_left_len > len) {
        for(0..options.pad_left_len - len) |_| {
            buffer[i] = options.pad_left_char;
            i += 1;
        }
    }
    if(value < 0) {
        buffer[i] = options.sign_negative_char;
        i += 1;
    }
    else if(options.always_sign) {
        buffer[i] = options.sign_positive_char;
        i += 1;
    }
    for(options.digits_prefix) |prefix_char| {
        buffer[i] = prefix_char;
        i += 1;
    }
    if(options.pad_zero_len > digits) {
        for(0..options.pad_zero_len - digits) |_| {
            buffer[i] = options.hex_digits[0];
            i += 1;
        }
    }
    const value_abs = @abs(value);
    for(0..digits) |_| {
        buffer[i] = options.hex_digits[@intCast((value_abs >> shift) & 0xf)];
        shift -= 4;
        i += 1;
    }
    return i;
}

/// Write a hexadecimal representation of an unsigned integer to a target buffer.
/// Uses ASCII encoding by default.
pub fn formatHexU32(
    buffer: [*]volatile u8,
    value: u32,
    options: FormatHexIntOptions,
) u32 {
    @setRuntimeSafety(false);
    const digits = lenHexU32(value);
    const len = (
        options.digits_prefix.len +
        @intFromBool(options.always_sign) +
        @max(digits, options.pad_zero_len)
    );
    var shift: u5 = @as(u5, digits - 1) << 2;
    var i: u32 = 0;
    if(options.pad_left_len > len) {
        for(0..options.pad_left_len - len) |_| {
            buffer[i] = options.pad_left_char;
            i += 1;
        }
    }
    if(options.always_sign) {
        buffer[i] = options.sign_positive_char;
        i += 1;
    }
    for(options.digits_prefix) |prefix_char| {
        buffer[i] = prefix_char;
        i += 1;
    }
    if(options.pad_zero_len > digits) {
        for(0..options.pad_zero_len - digits) |_| {
            buffer[i] = options.hex_digits[0];
            i += 1;
        }
    }
    for(0..digits) |_| {
        buffer[i] = options.hex_digits[@intCast((value >> shift) & 0xf)];
        shift -= 4;
        i += 1;
    }
    return i;
}
