//! This module implements logging via "mgba_log", a logging
//! interface supported by some emulators, including mGBA and Mesen.
//!
//! See: https://github.com/devkitPro/libtonc/commit/702397459d3259aa019340aaf534bc3a7963c87c

const std = @import("std");
const gba = @import("gba.zig");

/// Enumeration of recognized log levels.
pub const MgbaLogLevel = enum(u16) {
    fatal = 0x100,
    err = 0x101,
    warn = 0x102,
    info = 0x103,
};

/// Length of string buffer.
pub const reg_mgba_log_str_size = 0x100;

/// Write this constant to `reg_mgba_log_enable` to enable logging.
pub const reg_mgba_log_enabled: u16 = 0xc0de;

/// Log string buffer.
pub const reg_mgba_log_str: *volatile [reg_mgba_log_str_size]u8 = @ptrFromInt(0x4fff600);

/// Log level. Write a `MgbaLogLevel` constant to this register after writing to
/// the `reg_mgba_log_str` buffer to log it.
pub const reg_mgba_log_level: *volatile u16 = @ptrFromInt(0x4fff700);

/// Write `reg_mgba_log_enabled` to this register to enable logging.
pub const reg_mgba_log_enable: *volatile u16 = @ptrFromInt(0x4fff780);

const MgbaLogStream = struct {
    log_level: MgbaLogLevel,
    buffer_pos: usize,

    pub fn init(log_level: MgbaLogLevel) MgbaLogStream {
        return .{
            .log_level = log_level,
            .buffer_pos = 0,
        };
    }
    
    pub fn write(self: *MgbaLogStream, bytes: []const u8) usize {
        var bytes_i: usize = 0;
        while(bytes_i < bytes.len) {
            if(self.buffer_pos >= reg_mgba_log_str_size) {
                reg_mgba_log_level.* = @intFromEnum(self.log_level);
                self.buffer_pos = 0;
            }
            const count = @min(
                bytes.len - bytes_i,
                reg_mgba_log_str_size - self.buffer_pos,
            );
            gba.mem.memcpy(
                &reg_mgba_log_str[self.buffer_pos],
                &bytes[bytes_i],
                count,
            );
            self.buffer_pos += count;
            bytes_i += count;
        }
        return bytes_i;
    }
    
    /// Wraps `write` with an interface compatible with `std.io.Writer`.
    pub fn writerWrite(self: *MgbaLogStream, bytes: []const u8) !usize {
        return self.write(bytes);
    }
    
    pub fn flush(self: *MgbaLogStream) void {
        if(self.buffer_pos != 0) {
            reg_mgba_log_level.* = @intFromEnum(self.log_level);
        }
    }

    pub fn outStream(
        self: *MgbaLogStream,
    ) std.io.Writer(
        *MgbaLogStream,
        error{BufferTooSmall},
        MgbaLogStream.writerWrite,
    ) {
        return .{ .context = self };
    }
};

/// Print a formatted message with a given log level.
pub fn mgbaPrint(
    level: MgbaLogLevel,
    comptime formatString: []const u8,
    args: anytype,
) !void {
    var stream = MgbaLogStream.init(level);
    defer stream.flush();
    reg_mgba_log_enable.* = reg_mgba_log_enabled;
    try std.fmt.format(stream.outStream(), formatString, args);
}

/// Print a message with a given log level.
pub fn mgbaWrite(level: MgbaLogLevel, message: []const u8) void {
    var stream = MgbaLogStream.init(level);
    defer stream.flush();
    reg_mgba_log_enable.* = reg_mgba_log_enabled;
    _ = stream.write(message);
}

/// Print a formatted message with log level "info".
pub fn mgbaPrintInfo(comptime formatString: []const u8, args: anytype) !void {
    try mgbaPrint(.info, formatString, args);
}

/// Print a message with log level "info".
pub fn mgbaWriteInfo(message: []const u8) void {
    mgbaWrite(.info, message);
}

/// Print a formatted message with log level "warn".
pub fn mgbaPrintWarning(comptime formatString: []const u8, args: anytype) !void {
    try mgbaPrint(.warn, formatString, args);
}

/// Print a message with log level "warn".
pub fn mgbaWriteWarning(message: []const u8) void {
    mgbaWrite(.warn, message);
}

/// Print a formatted message with log level "err".
pub fn mgbaPrintError(comptime formatString: []const u8, args: anytype) !void {
    try mgbaPrint(.err, formatString, args);
}

/// Print a message with log level "err".
pub fn mgbaWriteError(message: []const u8) void {
    mgbaWrite(.err, message);
}

/// Print a formatted message with log level "fatal".
pub fn mgbaPrintFatal(comptime formatString: []const u8, args: anytype) !void {
    try mgbaPrint(.fatal, formatString, args);
}

/// Print a message with log level "fatal".
pub fn mgbaWriteFatal(message: []const u8) void {
    mgbaWrite(.fatal, message);
}
