//! Test coverage for functions which format an integer as a string.

const std = @import("std");
const gba = @import("../gba.zig");

fn formatTest(
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

test "gba.format.formatDecimalI32" {
    // Default options
    try formatTest("0", 0, .{});
    try formatTest("1", 1, .{});
    try formatTest("-1", -1, .{});
    try formatTest("255", 255, .{});
    try formatTest("1234", 1234, .{});
    try formatTest("2147483647", 2147483647, .{});
    try formatTest("-2147483648", -2147483648, .{});
    // Always include sign
    try formatTest("+1", 1, .{ .always_sign = true });
    try formatTest("+0", 0, .{ .always_sign = true });
    try formatTest("-1", -1, .{ .always_sign = true });
    // Left pad
    try formatTest("   1", 1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("  -1", -1, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("  99", 99, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest(" 999", 999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("9999", 9999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("99999", 99999, .{ .pad_left_len = 4, .pad_left_char = ' ' });
    try formatTest("           0", 0, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest("  2147483647", 2147483647, .{ .pad_left_len = 12, .pad_left_char = ' ' });
    try formatTest(" -2147483648", -2147483648, .{ .pad_left_len = 12, .pad_left_char = ' ' });
}
