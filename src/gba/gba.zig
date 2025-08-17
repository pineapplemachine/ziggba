//! This module implements runtime APIs for code running on a GBA.

const gba = @This();

pub const bg = @import("bg.zig");
pub const bios = @import("bios.zig");
pub const bitmap = @import("bitmap.zig");
pub const Color = @import("color.zig").Color;
pub const debug = @import("debug.zig");
pub const display = @import("display.zig");
pub const fixed = @import("fixed.zig");
pub const format = @import("format.zig");
pub const Header = @import("header.zig").Header;
pub const input = @import("input.zig");
pub const interrupt = @import("interrupt.zig");
pub const mem = @import("mem.zig");
pub const obj = @import("obj.zig");
pub const sound = @import("sound.zig");
pub const text = @import("text.zig");
pub const Timer = @import("timer.zig").Timer;
pub const timers = @import("timer.zig").timers;

pub const FixedI16R8 = fixed.FixedI16R8;
pub const FixedU16R16 = fixed.FixedU16R16;
pub const FixedI32R8 = fixed.FixedI32R8;
pub const FixedI32R16 = fixed.FixedI32R16;
pub const FixedVec2I32R8 = fixed.FixedVec2I32R8;
pub const FixedVec2I32R16 = fixed.FixedVec2I32R16;

/// Pointer to EWRAM (external work RAM).
/// More plentiful than IWRAM, but slower.
pub const ewram: *volatile [0x20000]u16 = @ptrFromInt(gba.mem.ewram);

/// Pointer to IWRAM (internal work RAM).
/// Not as large as EWRAM, but faster.
pub const iwram: *volatile [0x2000]u32 = @ptrFromInt(gba.mem.iwram);

/// Width of the GBA video output in pixels.
pub const screen_width = 240;

/// Height of the GBA video output in pixels.
pub const screen_height = 160;
