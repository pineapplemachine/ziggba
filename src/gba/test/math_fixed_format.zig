//! Test coverage for functions which format an integer as a string.

const std = @import("std");
const gba = @import("../gba.zig");

const FixedI32R8 = gba.math.FixedI32R8;

fn formatTest(
    expected: []const u8,
    value: FixedI32R8,
    options: gba.math.FormatDecimalFixedOptions,
) !void {
    var buffer: [256]u8 = @splat(0);
    const actual_len = value.formatDecimal(
        @ptrCast(&buffer),
        options,
    );
    try std.testing.expectEqual(expected.len, actual_len);
    try std.testing.expectEqualSlices(u8, expected, buffer[0..actual_len]);
}

test "FixedI32R8.formatDecimal" {
    // Default options (integers)
    try formatTest("0", FixedI32R8.initInt(0), .{});
    try formatTest("1", FixedI32R8.initInt(1), .{});
    try formatTest("-1", FixedI32R8.initInt(-1), .{});
    try formatTest("255", FixedI32R8.initInt(255), .{});
    try formatTest("1234", FixedI32R8.initInt(1234), .{});
    try formatTest("8388607", FixedI32R8.initInt(8388607), .{});
    try formatTest("-8388608", FixedI32R8.initInt(-8388608), .{});
    // Default options (fractional values from 0 to 1)
    try formatTest("0.5", FixedI32R8.initFloat64(0.5), .{});
    try formatTest("0.25", FixedI32R8.initFloat64(0.25), .{});
    try formatTest("0.75", FixedI32R8.initFloat64(0.75), .{});
    try formatTest("0.1015625", FixedI32R8.initFloat64(0.1015625), .{});
    try formatTest("0.00390625", FixedI32R8.initFloat64(0.00390625), .{});
    try formatTest("0.02734375", FixedI32R8.initFloat64(0.02734375), .{});
    try formatTest("0.99609375", FixedI32R8.initFloat64(0.99609375), .{});
    // Default options (int and fraction parts)
    try formatTest("1.5", FixedI32R8.initFloat64(1.5), .{});
    try formatTest("-1.5", FixedI32R8.initFloat64(-1.5), .{});
    try formatTest("8388606.00390625", FixedI32R8.initFloat64(8388606.00390625), .{});
    try formatTest("-8388607.00390625", FixedI32R8.initFloat64(-8388607.00390625), .{});
    // Always include sign
    try formatTest("+1", FixedI32R8.initInt(1), .{ .always_sign = true });
    try formatTest("+0", FixedI32R8.initInt(0), .{ .always_sign = true });
    try formatTest("-1", FixedI32R8.initInt(-1), .{ .always_sign = true });
    try formatTest("+1.5", FixedI32R8.initFloat64(1.5), .{ .always_sign = true });
    try formatTest("+0.5", FixedI32R8.initFloat64(0.5), .{ .always_sign = true });
    try formatTest("-1.5", FixedI32R8.initFloat64(-1.5), .{ .always_sign = true });
    // Left pad
    try formatTest("   1", FixedI32R8.initInt(1), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("  -1", FixedI32R8.initInt(-1), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("  99", FixedI32R8.initInt(99), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest(" 999", FixedI32R8.initInt(999), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("9999", FixedI32R8.initInt(9999), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("99999", FixedI32R8.initInt(99999), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest(" 0.5", FixedI32R8.initFloat64(0.5), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("0.25", FixedI32R8.initFloat64(0.25), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("0.125", FixedI32R8.initFloat64(0.125), .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("           0", FixedI32R8.initInt(0), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("     8388607", FixedI32R8.initInt(8388607), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("    -8388608", FixedI32R8.initInt(-8388608), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("         0.5", FixedI32R8.initFloat64(0.5), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("     125.125", FixedI32R8.initFloat64(125.125), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("8388606.00390625", FixedI32R8.initFloat64(8388606.00390625), .{ .pad_left_len = 12, .pad_left_char = ' ' });
    // Min and max fraction digits
    try formatTest("1.00", FixedI32R8.initInt(1), .{ .min_fraction_digits = 2 });
    try formatTest("1.50", FixedI32R8.initFloat64(1.5), .{ .min_fraction_digits = 2 });
    try formatTest("1.25", FixedI32R8.initFloat64(1.25), .{ .min_fraction_digits = 2 });
    try formatTest("1.125", FixedI32R8.initFloat64(1.125), .{ .min_fraction_digits = 2 });
    try formatTest("1.00390625", FixedI32R8.initFloat64(1.00390625), .{ .min_fraction_digits = 2 });
    try formatTest("1.1015625", FixedI32R8.initFloat64(1.1015625), .{ .min_fraction_digits = 2 });
    try formatTest("1.02734375", FixedI32R8.initFloat64(1.02734375), .{ .min_fraction_digits = 2 });
    try formatTest("1", FixedI32R8.initInt(1), .{ .max_fraction_digits = 2 });
    try formatTest("1.5", FixedI32R8.initFloat64(1.5), .{ .max_fraction_digits = 2 });
    try formatTest("1.25", FixedI32R8.initFloat64(1.25), .{ .max_fraction_digits = 2 });
    try formatTest("1.12", FixedI32R8.initFloat64(1.125), .{ .max_fraction_digits = 2 });
    try formatTest("1", FixedI32R8.initFloat64(1.00390625), .{ .max_fraction_digits = 2 });
    try formatTest("1.1", FixedI32R8.initFloat64(1.1015625), .{ .max_fraction_digits = 2 });
    try formatTest("1.02", FixedI32R8.initFloat64(1.02734375), .{ .max_fraction_digits = 2 });
    try formatTest("1.00", FixedI32R8.initInt(1), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.50", FixedI32R8.initFloat64(1.5), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.25", FixedI32R8.initFloat64(1.25), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.12", FixedI32R8.initFloat64(1.125), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.00", FixedI32R8.initFloat64(1.00390625), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.10", FixedI32R8.initFloat64(1.1015625), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
    try formatTest("1.02", FixedI32R8.initFloat64(1.02734375), .{ .min_fraction_digits = 2, .max_fraction_digits = 2 });
}
