const gba = @import("gba");

export const gameHeader linksection(".gbaheader") = gba.Header.init("SECSTIMER", "ASTE", "00", 0);

pub export fn main() void {
    // Initialize a background.
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 28,
        .size = .size_32x32,
    });

    // Create tiles for numeric digits.
    gba.display.bg_blocks.tiles_4bpp[0] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11000110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[1] = @bitCast([_]u32{
        0x11000000, 0x11000000, 0x11000000, 0x11000000,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[2] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11111110,
        0x00000110, 0x00000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[3] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[4] = @bitCast([_]u32{
        0x11000110, 0x11000110, 0x11000110, 0x11111110,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[5] = @bitCast([_]u32{
        0x11111110, 0x00000110, 0x00000110, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[6] = @bitCast([_]u32{
        0x11111110, 0x00000110, 0x00000110, 0x11111110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[7] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11000000,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[8] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11111110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[9] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_blocks.tiles_4bpp[10] = @bitCast([_]u32{
        0x00000000, 0x00000000, 0x00000000, 0x00000000,
        0x00000000, 0x00000000, 0x00000000, 0x00000000,
    });

    // Initialize background palette.
    gba.display.bg_palette.colors[0] = .black;
    gba.display.bg_palette.colors[1] = .white;

    // Initialize the map to all blank tiles (index 10).
    bg0_map.fill(.{ .tile = 10 });
    
    // Initialize the display.
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });

    // Based on the example here: https://gbadev.net/tonc/timers.html
    // Timer 1 will overflow every 0x4000 * 1024 clock cycles,
    // which is the same as once per second.
    // When it oveflows, Timer 2 will be incremented by 1 due
    // to its "cascade" flag.
    gba.timers[1] = gba.Timer {
        .counter = @truncate(-0x4000),
        .ctrl = .{
            .freq = .cycles_1024,
            .enable = true,
        },
    };
    gba.timers[2] = gba.Timer {
        .counter = 0,
        .ctrl = .{
            .mode = .cascade,
            .enable = true,
        },
    };
    
    while(true) {
        gba.display.naiveVSync();

        // Convert elapsed seconds to a 2-digit display
        const digits = gba.bios.div(gba.timers[2].counter, 10);
        bg0_map.set(1, 1, .{ .tile = @intCast(digits.quotient) });
        bg0_map.set(2, 1, .{ .tile = @intCast(digits.remainder) });
    }
}
