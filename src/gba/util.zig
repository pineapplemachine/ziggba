const builtin = @import("builtin");
const std = @import("std");

/// If this function returns true, then code is compiling to run on GBA
/// hardware. If false, then code is running either at comptime or on
/// a different platform, e.g. during automated tests.
pub fn isGbaTarget() bool {
    return !@inComptime() and comptime(
        builtin.cpu.model == &std.Target.arm.cpu.arm7tdmi
    );
}
