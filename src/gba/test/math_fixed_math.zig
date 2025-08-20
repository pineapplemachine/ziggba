//! Test coverage for fixed point arithmetic functions.

const std = @import("std");
const gba = @import("../gba.zig");

const FixedI16R8 = gba.math.FixedI16R8;
const FixedI16R14 = gba.math.FixedI16R14;
const FixedU16R16 = gba.math.FixedU16R16;
const FixedI32R8 = gba.math.FixedI32R8;
const FixedI32R16 = gba.math.FixedI32R16;

fn addTest(comptime T: type, expected: T, x: T, y: T) !void {
    try std.testing.expectEqual(expected, x.add(y));
}

fn subTest(comptime T: type, expected: T, x: T, y: T) !void {
    try std.testing.expectEqual(expected, x.sub(y));
}

fn mulTest(comptime T: type, expected: T, x: T, y: T) !void {
    try std.testing.expectEqual(expected, x.mul(y));
}

// TODO: Improve test coverage.

test "gba.math.FixedI32R8 math" {
    const T = FixedI32R8;
    try addTest(T, .fromInt(56), .fromInt(32), .fromInt(24));
    try addTest(T, .fromInt(21), .fromFloat(9.5), .fromFloat(11.5));
    try addTest(T, .fromInt(0), .fromInt(100), .fromInt(-100));
    try subTest(T, .fromInt(32), .fromInt(64), .fromInt(32));
    try subTest(T, .fromInt(-32), .fromInt(0), .fromInt(32));
    try subTest(T, .fromInt(0), .fromInt(100), .fromInt(100));
    try mulTest(T, .fromInt(256), .fromInt(32), .fromInt(8));
    try mulTest(T, .fromInt(10), .fromFloat(2.5), .fromInt(4));
    try mulTest(T, .fromInt(-5), .fromFloat(2.5), .fromInt(-2));
}

test "gba.math.FixedI32R16 math" {
    const T = FixedI32R16;
    try addTest(T, .fromInt(56), .fromInt(32), .fromInt(24));
    try addTest(T, .fromInt(21), .fromFloat(9.5), .fromFloat(11.5));
    try addTest(T, .fromInt(0), .fromInt(100), .fromInt(-100));
    try subTest(T, .fromInt(32), .fromInt(64), .fromInt(32));
    try subTest(T, .fromInt(-32), .fromInt(0), .fromInt(32));
    try subTest(T, .fromInt(0), .fromInt(100), .fromInt(100));
    try mulTest(T, .fromInt(256), .fromInt(32), .fromInt(8));
    try mulTest(T, .fromInt(10), .fromFloat(2.5), .fromInt(4));
    try mulTest(T, .fromInt(-5), .fromFloat(2.5), .fromInt(-2));
}
