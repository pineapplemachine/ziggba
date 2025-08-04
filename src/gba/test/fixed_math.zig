//! Test coverage for fixed point arithmetic functions.

const std = @import("std");
const gba = @import("../gba.zig");

fn mulTest(
    expected: gba.FixedI32R16,
    x: gba.FixedI32R16,
    y: gba.FixedI32R16,
) !void {
    try std.testing.expectEqual(expected, x.mul(y));
}

// TODO: Improve test coverage.

test "gba.FixedI32R16 math" {
    try mulTest(.initInt(256), .initInt(32), .initInt(8));
    try mulTest(.initInt(10), .initFloat64(2.5), .initInt(4));
}
