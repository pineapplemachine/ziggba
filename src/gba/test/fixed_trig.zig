//! Test coverage for trigonometry functions in fixed point math utils.
//! Tests verify that arithmetic error is within expected bounds.

const std = @import("std");
const gba = @import("../gba.zig");

const MathErrorTracker = struct {
    count: usize = 0,
    sum: f64 = 0,
    min: f64 = 0,
    max: f64 = 0,
    
    pub fn addSample(self: *MathErrorTracker, err: f64) void {
        self.count += 1;
        self.sum += err;
        self.min = @min(self.min, err);
        self.max = @max(self.max, err);
    }
    
    pub fn average(self: MathErrorTracker) f64 {
        return self.sum / @as(f64, @floatFromInt(self.count));
    }
    
    pub fn log(self: MathErrorTracker, title: []const u8) void {
        std.debug.print("Error statistics for {s}:\n", .{ title });
        std.debug.print("  min: {d}\n", .{ self.min });
        std.debug.print("  max: {d}\n", .{ self.max });
        std.debug.print("  avg: {d}\n", .{ self.average() });
    }
};

fn trigTest(
    comptime name: []const u8,
    comptime get_expected: fn(radians: f64) f64,
    comptime get_actual: fn(i: u16) i32,
) !MathErrorTracker {
    var err_tracker: MathErrorTracker = .{};
    for(0..0x10000) |i| {
        const radians: f64 = @as(f64, @floatFromInt(i)) * 2.0 * std.math.pi / 0x10000;
        const actual: i32 = get_actual(@truncate(i));
        const expected: i32 = @intFromFloat(get_expected(radians) * 0x10000);
        const err = @as(f64, @floatFromInt(@abs(expected - actual))) / 0x10000;
        err_tracker.addSample(err);
        // Useful for debugging
        // if(err > 0.00003) {
        //     std.debug.print(
        //         "i={x} rads={d:.4} actual {d} expected {d} err {d}\n",
        //         .{ i, radians, actual, expected, err }
        //     );
        // }
    }
    err_tracker.log(name);
    return err_tracker;
}

fn sinExpected(radians: f64) f64 {
    return @sin(radians);
}
fn sinFastActual(i: u16) i32 {
    return gba.FixedU16R16.initRaw(i).sinFast().value;
}
fn sinLerpActual(i: u16) i32 {
    return gba.FixedU16R16.initRaw(i).sinLerp().value;
}

fn cosExpected(radians: f64) f64 {
    return @cos(radians);
}
fn cosFastActual(i: u16) i32 {
    return gba.FixedU16R16.initRaw(i).cosFast().value;
}
fn cosLerpActual(i: u16) i32 {
    return gba.FixedU16R16.initRaw(i).cosLerp().value;
}

test "gba.FixedU16R16.sinFast" {
    const err_tracker = try trigTest(
        "gba.FixedU16R16.sinFast",
        sinExpected,
        sinFastActual,
    );
    try std.testing.expect(err_tracker.max < 0.01);
    try std.testing.expect(err_tracker.average() < 0.002);
}

test "gba.FixedU16R16.sinLerp" {
    const err_tracker = try trigTest(
        "gba.FixedU16R16.sinLerp",
        sinExpected,
        sinLerpActual,
    );
    try std.testing.expect(err_tracker.max < 0.00005);
    try std.testing.expect(err_tracker.average() < 0.00001);
}

test "gba.FixedU16R16.cosFast" {
    const err_tracker = try trigTest(
        "gba.FixedU16R16.cosFast",
        cosExpected,
        cosFastActual,
    );
    try std.testing.expect(err_tracker.max < 0.01);
    try std.testing.expect(err_tracker.average() < 0.002);
}

test "gba.FixedU16R16.cosLerp" {
    const err_tracker = try trigTest(
        "gba.FixedU16R16.cosLerp",
        cosExpected,
        cosLerpActual,
    );
    try std.testing.expect(err_tracker.max < 0.00005);
    try std.testing.expect(err_tracker.average() < 0.00001);
}
