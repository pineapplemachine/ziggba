//! This module implements runtime APIs for code running on a GBA.

const gba = @This();

pub const bios = @import("bios.zig");
pub const bitmap = @import("bitmap.zig");
pub const ColorRgb555 = @import("color.zig").ColorRgb555;
pub const debug = @import("debug.zig");
pub const display = @import("display.zig");
pub const format = @import("format.zig");
pub const Header = @import("header.zig").Header;
pub const input = @import("input.zig");
pub const interrupt = @import("interrupt.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const sound = @import("sound.zig");
pub const text = @import("text.zig");
pub const Timer = @import("timer.zig").Timer;
pub const timers = @import("timer.zig").timers;
