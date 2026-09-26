const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("BIOSCPUTEST", "ABPE", "00", 0);

// Initialize values in a buffer starting at an offset with incrementing values
fn initBufInc(buffer: []u8, initial: u8, count: u32) void {
    for(0..count) |i| {
        buffer[i] = @intCast(initial + i);
    }
}

// Initialize values in a buffer starting at an offset with a given value
fn initBufEq(buffer: []u8, value: u8, count: u32) void {
    for(0..count) |i| {
        buffer[i] = value;
    }
}

// Check if values in a buffer starting at an offset are incrementing/ascending
fn isBufInc(buffer: []const u8, initial: u8, count: u32) bool {
    for(0..count) |i| {
        if(buffer[i] != initial + i) {
            return false;
        }
    }
    return true;
}

// Check if values in a buffer starting at an offset are all the same
fn isBufEq(buffer: []const u8, value: u8, count: u32) bool {
    for(0..count) |i| {
        if(buffer[i] != value) {
            return false;
        }
    }
    return true;
}

// Check if values in a buffer starting at an offset repeat a 4-byte pattern
fn isBufEq32(buffer: []const u8, value: u32, count: u32) bool {
    for(0..count) |i| {
        const byteValue = (value >> @intCast((i & 0x3) << 3)) & 0xff;
        if(buffer[i] != byteValue) {
            return false;
        }
    }
    return true;
}

pub export fn main() void {
    // Initialize an array of success flags
    var buf_ok: [6]bool = @splat(false);
    // Initialize a buffer, to do BIOS calls on.
    var buffer: [2048]u8 = @splat(0);
    initBufInc(buffer[0..], 0, 256);
    
    buf_ok[0] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufEq(buffer[256..], 0, buffer.len - 256)
    );
    
    gba.bios.cpuSet(
        @alignCast(@ptrCast(&buffer[0])),
        @alignCast(@ptrCast(&buffer[256])),
        .{
            .count = 256 / 4,
            .size = .bits_32,
            .fixed = false,
        },
    );
    buf_ok[1] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufInc(buffer[256..], 0, 256) and
        isBufEq(buffer[512..], 0, buffer.len - 512)
    );
    
    gba.bios.cpuSet(
        @alignCast(@ptrCast(&buffer[0])),
        @alignCast(@ptrCast(&buffer[512])),
        .{
            .count = 256 / 2,
            .size = .bits_16,
            .fixed = false,
        },
    );
    buf_ok[2] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufInc(buffer[256..], 0, 256) and
        isBufInc(buffer[512..], 0, 256) and
        isBufEq(buffer[768..], 0, buffer.len - 768)
    );
    
    gba.bios.cpuSet(
        @alignCast(@ptrCast(&buffer[0])),
        @alignCast(@ptrCast(&buffer[256])),
        .{
            .count = 256 / 4,
            .size = .bits_32,
            .fixed = true,
        },
    );
    buf_ok[3] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufEq32(buffer[256..], 0x03020100, 256) and
        isBufInc(buffer[512..], 0, 256) and
        isBufEq(buffer[768..], 0, buffer.len - 768)
    );
    
    // Reset the buffer
    initBufEq(buffer[0..], 0, buffer.len);
    initBufInc(buffer[0..], 0, 256);
    
    gba.bios.cpuFastSet(
        @alignCast(@ptrCast(&buffer[0])),
        @alignCast(@ptrCast(&buffer[256])),
        .{
            .count = 256 / 4,
            .fixed = false,
        },
    );
    buf_ok[4] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufInc(buffer[256..], 0, 256) and
        isBufEq(buffer[512..], 0, buffer.len - 512)
    );
    
    gba.bios.cpuFastSet(
        @alignCast(@ptrCast(&buffer[0])),
        @alignCast(@ptrCast(&buffer[512])),
        .{
            .count = 256 / 4,
            .fixed = true,
        },
    );
    buf_ok[5] = (
        isBufInc(buffer[0..], 0, 256) and
        isBufInc(buffer[256..], 0, 256) and
        isBufEq32(buffer[512..], 0x03020100, 256) and
        isBufEq(buffer[768..], 0, buffer.len - 768)
    );
    
    // TODO: Test more things, e.g. cpuSetCopy16 and other cpuset wrappers
    // TODO: Test comptime calls, since this is meant to be supported
    
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .white;
    
    // Initialize a background, to be used for displaying text.
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 31,
        .size = .size_32x32,
    });
    bg0_map.getBaseScreenblock().fillLinear(.{});
    
    // Draw status text
    const text_surface = gba.display.bg_blocks.getSurface4Bpp(0, 32, 32);
    text_surface.draw().text("Status:", .init(1), .{
        .x = 8,
        .y = 4,
    });
    const text_pass = "PASS";
    const text_fail = "FAIL";
    for(0..buf_ok.len) |i| {
        const ok = buf_ok[i];
        text_surface.draw().text(if(ok) text_pass else text_fail, .init(1), .{
            .x = 8,
            .y = 4 + ((i + 1) * 12),
        });
    }
    
    // Initialize the display.
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    // Main loop.
    while(true) {
        gba.bios.vblankIntrWait();
    }
}
