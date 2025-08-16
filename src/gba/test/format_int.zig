//! Test coverage for functions which format an integer as a string.

const std = @import("std");
const gba = @import("../gba.zig");

fn formatDecimalTest(
    expected: []const u8,
    value: i32,
    options: gba.format.FormatDecimalIntOptions,
) !void {
    var buffer: [256]u8 = @splat(0);
    const actual_len = gba.format.formatDecimalI32(
        @ptrCast(&buffer),
        value,
        options,
    );
    try std.testing.expectEqual(expected.len, actual_len);
    try std.testing.expectEqualSlices(u8, expected, buffer[0..actual_len]);
}

fn formatHexI32Test(
    expected: []const u8,
    value: i32,
    options: gba.format.FormatHexIntOptions,
) !void {
    var buffer: [256]u8 = @splat(0);
    const actual_len = gba.format.formatHexI32(
        @ptrCast(&buffer),
        value,
        options,
    );
    try std.testing.expectEqual(expected.len, actual_len);
    try std.testing.expectEqualSlices(u8, expected, buffer[0..actual_len]);
}

test "gba.format.formatDecimalI32" {
    // Default options
    try formatDecimalTest("0", 0, .{});
    try formatDecimalTest("1", 1, .{});
    try formatDecimalTest("-1", -1, .{});
    try formatDecimalTest("255", 255, .{});
    try formatDecimalTest("1234", 1234, .{});
    try formatDecimalTest("2147483647", 2147483647, .{});
    try formatDecimalTest("-2147483648", -2147483648, .{});
    // Always include sign
    try formatDecimalTest("+1", 1, .{ .always_sign = true });
    try formatDecimalTest("+0", 0, .{ .always_sign = true });
    try formatDecimalTest("-1", -1, .{ .always_sign = true });
    // Left pad
    try formatDecimalTest("   1", 1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest("  -1", -1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest("  99", 99, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest(" 999", 999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest("9999", 9999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest("99999", 99999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatDecimalTest("           0", 0, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatDecimalTest("  2147483647", 2147483647, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatDecimalTest(" -2147483648", -2147483648, .{ .pad_left_len = 12, .pad_left_char = ' ' });
}

test "gba.format.formatHexI32" {
    // Default options
    try formatHexI32Test("0", 0, .{});
    try formatHexI32Test("1", 1, .{});
    try formatHexI32Test("-1", -1, .{});
    try formatHexI32Test("FF", 0xff, .{});
    try formatHexI32Test("1234", 0x1234, .{});
    try formatHexI32Test("7FFFFFFF", 0x7fffffff, .{});
    try formatHexI32Test("-80000000", -0x80000000, .{});
    // Always include sign
    try formatHexI32Test("+1", 1, .{ .always_sign = true });
    try formatHexI32Test("+0", 0, .{ .always_sign = true });
    try formatHexI32Test("-1", -1, .{ .always_sign = true });
    // Left pad
    try formatHexI32Test("   1", 1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test("  -1", -1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test("  FF", 0xff, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test(" FFF", 0xfff, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test("FFFF", 0xffff, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test("FFFFF", 0xfffff, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatHexI32Test("           0", 0, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatHexI32Test("    7FFFFFFF", 0x7fffffff, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatHexI32Test("   -80000000", -0x80000000, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    // Digits prefix
    try formatHexI32Test("0x1234", 0x1234, .{ .digits_prefix = "0x" });
    try formatHexI32Test("  0xFF", 0xff, .{ .digits_prefix = "0x", .pad_left_len = 6, .pad_left_char = ' ' });
    // Zero padding
    try formatHexI32Test("000B", 0xb, .{ .pad_zero_len = 4 });
    try formatHexI32Test("0012", 0x12, .{ .pad_zero_len = 4 });
    try formatHexI32Test("1234", 0x1234, .{ .pad_zero_len = 4 });
    try formatHexI32Test("00001234", 0x1234, .{ .pad_zero_len = 8 });
    try formatHexI32Test("12345678", 0x12345678, .{ .pad_zero_len = 8 });
    try formatHexI32Test("000012345678", 0x12345678, .{ .pad_zero_len = 12 });
    try formatHexI32Test("0x000012345678", 0x12345678, .{ .digits_prefix = "0x", .pad_zero_len = 12 });
}
