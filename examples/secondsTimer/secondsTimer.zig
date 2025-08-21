const gba = @import("gba");

export const gameHeader linksection(".gbaheader") = gba.Header.init("SECSTIMER", "ASTE", "00", 0);

fn initMap() void {
    // Init background
    gba.bg.ctrl[0] = gba.bg.Control{
        .screen_base_block = 28,
        .tile_map_size = .{ .normal = .size_32x32 },
    };
    gba.bg.scroll[0] = .zero;

    // Create tiles for numeric digits
    gba.display.bg_charblocks[0].bpp_4[0] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11000110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[1] = @bitCast([_]u32{
        0x11000000, 0x11000000, 0x11000000, 0x11000000,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[2] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11111110,
        0x00000110, 0x00000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[3] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[4] = @bitCast([_]u32{
        0x11000110, 0x11000110, 0x11000110, 0x11111110,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[5] = @bitCast([_]u32{
        0x11111110, 0x00000110, 0x00000110, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[6] = @bitCast([_]u32{
        0x11111110, 0x00000110, 0x00000110, 0x11111110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[7] = @bitCast([_]u32{
        0x11111110, 0x11000000, 0x11000000, 0x11000000,
        0x11000000, 0x11000000, 0x11000000, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[8] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11111110,
        0x11000110, 0x11000110, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[9] = @bitCast([_]u32{
        0x11111110, 0x11000110, 0x11000110, 0x11111110,
        0x11000000, 0x11000000, 0x11111110, 0x00000000,
    });
    gba.display.bg_charblocks[0].bpp_4[10] = @bitCast([_]u32{
        0x00000000, 0x00000000, 0x00000000, 0x00000000,
        0x00000000, 0x00000000, 0x00000000, 0x00000000,
    });

    // Initialize background palette
    gba.display.bg_palette.colors[0] = .black;
    gba.display.bg_palette.colors[1] = .white;

    // Initialize the map to all blank tiles
    const bg0_map: [*]volatile gba.bg.TextScreenEntry = (
        @ptrCast(&gba.bg.screen_block_ram[28])
    );
    for (0..32 * 32) |map_index| {
        bg0_map[map_index].palette_index = 0;
        bg0_map[map_index].tile_index = 10;
    }
}

pub export fn main() void {
    initMap();
    gba.display.ctrl.* = gba.display.Control{
        .bg0 = true,
    };

    // Based on the example here: https://gbadev.net/tonc/timers.html
    // Timer 1 will overflow every 0x4000 * 1024 clock cycles,
    // which is the same as once per second.
    // When it oveflows, Timer 2 will be incremented by 1 due
    // to its "cascade" flag.
    gba.timers[1] = gba.Timer{
        .counter = @truncate(-0x4000),
        .ctrl = .{
            .freq = .cycles_1024,
            .enable = true,
        },
    };
    gba.timers[2] = gba.Timer{
        .counter = 0,
        .ctrl = .{
            .mode = .cascade,
            .enable = true,
        },
    };

    const bg0_map: [*]volatile gba.bg.TextScreenEntry = (
        @ptrCast(&gba.bg.screen_block_ram[28])
    );

    while (true) {
        gba.display.naiveVSync();

        // Convert elapsed seconds to a 2-digit display
        const digits = gba.bios.div(gba.timers[2].counter, 10);
        bg0_map[33].tile_index = @intCast(digits.quotient);
        bg0_map[34].tile_index = @intCast(digits.remainder);
    }
}
