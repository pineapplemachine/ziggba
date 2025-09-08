const gba = @import("gba");

export var gameHeader linksection(".gbaheader") = gba.Header.init("SCREENBLOCK", "ASBE", "00", 0);

pub export fn main() void {
    // Initialize a background.
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 28,
        .size = .size_64x64,
    });

    // Initialize tiles: basic tile and a cross.
    gba.display.bg_blocks.tiles_4bpp[0] = @bitCast([_]u32{
        0x11111111, 0x01111111, 0x01111111, 0x01111111,
        0x01111111, 0x01111111, 0x01111111, 0x00000001,
    });
    gba.display.bg_blocks.tiles_4bpp[1] = @bitCast([_]u32{
        0x00000000, 0x00100100, 0x01100110, 0x00011000,
        0x00011000, 0x01100110, 0x00100100, 0x00000000,
    });

    // Create the background palette.
    gba.display.bg_palette.banks[0][1] = .red;
    gba.display.bg_palette.banks[1][1] = .green;
    gba.display.bg_palette.banks[2][1] = .blue;
    gba.display.bg_palette.banks[3][1] = .rgb(16, 16, 16);

    // Create the map: four contigent blocks of 0x0000, 0x1000, 0x2000, 0x3000.
    for(0..4) |palette_index| {
        bg0_map.getScreenblock(@intCast(palette_index)).fill(.{
            .palette = @intCast(palette_index),
        });
    }
    
    // Initialize the display.
    gba.display.ctrl.* = .initMode0(.{
        .bg0 = true,
        .obj = true,
    });
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    // These variables will be used to track the position of a cross.
    const cross_pos_initial: gba.math.Vec2I16 = .init(15, 10);
    var cross_pos_current: gba.math.Vec2I16 = cross_pos_initial;
    var cross_pos_prev_tile: gba.math.Vec2I16 = cross_pos_current;
    
    // This variable will be used in tracking button inputs,
    // for moving the cross around on the background.
    var input: gba.input.KeysState = .{};

    while(true) {
        // Run this loop only once per frame.
        gba.bios.vblankIntrWait();

        // Update cross position depending on dpad input.
        input.poll();
        cross_pos_current.x +%= input.getAxisHorizontal();
        cross_pos_current.y +%= input.getAxisVertical();
        
        // Divide position vector by 8 via `x >> 3, y >> 3`.
        const cross_pos_current_tile = cross_pos_current.asr(3);
        
        // Clear a previous position tile and set a current position tile
        // to represent the current cross position.
        const bg0_prev_x: u6 = @bitCast(@as(i6, @truncate(cross_pos_prev_tile.x)));
        const bg0_prev_y: u6 = @bitCast(@as(i6, @truncate(cross_pos_prev_tile.y)));
        const bg0_current_x: u6 = @bitCast(@as(i6, @truncate(cross_pos_current_tile.x)));
        const bg0_current_y: u6 = @bitCast(@as(i6, @truncate(cross_pos_current_tile.y)));
        bg0_map.set(bg0_prev_x, bg0_prev_y, .{
            .tile = 0,
            .palette = bg0_map.getScreenblockOffset(bg0_prev_x, bg0_prev_y),
        });
        bg0_map.set(bg0_current_x, bg0_current_y, .{
            .tile = 1,
            .palette = bg0_map.getScreenblockOffset(bg0_current_x, bg0_current_y),
        });
        cross_pos_prev_tile = cross_pos_current_tile;
        
        // Keep the cross centered via background scrolling.
        gba.display.bg_scroll[0] = cross_pos_current.sub(
            gba.display.screen_size.lsr(1).toVec2(i16)
        );
    }
}
