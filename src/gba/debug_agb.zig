//! This module implements logging via "agbprint"/"gbaprint", a logging
//! interface supported by some emulators, including mGBA and VBA.
//!
//! See: https://github.com/visualboyadvance-m/visualboyadvance-m/issues/1039
//! See: https://github.com/visualboyadvance-m/visualboyadvance-m/blob/master/src/core/gba/gbaPrint.cpp

const std = @import("std");
const gba = @import("gba.zig");

pub const reg_agb_print_protect: *volatile u16 = @ptrFromInt(0x09fe2ffe);
pub const reg_agb_print_context: *volatile AgbPrintContext = @ptrFromInt(0x09fe20f8);
pub const reg_agb_print_buffer: [*]volatile u16 = @ptrFromInt(0x09fd0000);

pub const agb_buffer_size = 0x100;

pub const AgbPrintContext = packed struct {
    request: u16,
    bank: u16,
    get: u16,
    put: u16,
};

const AgbPrintStream = struct {
    written: usize,

    pub fn init() AgbPrintStream {
        return .{ .written = 0 };
    }

    pub fn write(self: *AgbPrintStream, bytes: []const u8) usize {
        var bytes_i: usize = 0;
        while(bytes_i < bytes.len) {
            if(self.written >= agb_buffer_size) {
                gba.bios.agbPrintFlush();
                self.written = 0;
            }
            const count = @min(
                bytes.len - bytes_i,
                agb_buffer_size - self.written,
            );
            const bytes_i_max = bytes_i + count;
            while(bytes_i < bytes_i_max) {
                // TODO: This can probably be done more efficiently
                // by using gba.mem.memcpy, or at least gba.mem.memcpy16?
                putc(bytes[bytes_i]);
                bytes_i += 1;
            }
            self.written += count;
        }
        return bytes_i;
    }
    
    /// Wraps `write` with an interface compatible with `std.io.Writer`.
    pub fn writerWrite(self: *AgbPrintStream, bytes: []const u8) !usize {
        return self.write(bytes);
    }
    
    pub fn flush(self: *AgbPrintStream) void {
        if(self.written != 0) {
            gba.bios.agbPrintFlush();
        }
    }

    pub fn outStream(
        self: *AgbPrintStream,
    ) std.io.Writer(
        *AgbPrintStream,
        error{BufferTooSmall},
        AgbPrintStream.writerWrite,
    ) {
        return .{ .context = self };
    }
};

/// May need to be called before `agbPrint` or `agbWrite` in VBA?
pub fn agbInit() void {
    reg_agb_print_protect.* = 0x00;
    reg_agb_print_context.request = 0x00;
    reg_agb_print_context.get = 0x00;
    reg_agb_print_context.put = 0x00;
    reg_agb_print_context.bank = 0xFD;
    reg_agb_print_protect.* = 0x00;
}

/// Print a formatted message.
pub fn agbPrint(comptime formatString: []const u8, args: anytype) !void {
    var stream = AgbPrintStream.init();
    lockPrint();
    defer unlockPrint();
    defer stream.flush();
    try std.fmt.format(stream.outStream(), formatString, args);
}

/// Print a message.
pub fn agbWrite(message: []const u8) void {
    var stream = AgbPrintStream.init();
    lockPrint();
    defer unlockPrint();
    defer stream.flush();
    _ = stream.write(message);
}

inline fn lockPrint() void {
    reg_agb_print_protect.* = 0x20;
}

inline fn unlockPrint() void {
    reg_agb_print_protect.* = 0x00;
}

/// Write a single UTF-8 code unit to log output.
fn putc(value: u8) void {
    var data: u16 = reg_agb_print_buffer[reg_agb_print_context.put >> 1];
    if ((reg_agb_print_context.put & 1) == 1) {
        data = (@as(u16, @intCast(value)) << 8) | (data & 0xFF);
    } else {
        data = (data & 0xFF00) | value;
    }
    reg_agb_print_buffer[reg_agb_print_context.put >> 1] = data;
    reg_agb_print_context.put += 1;
}
