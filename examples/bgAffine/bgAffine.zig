const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("BGAFFINE", "ABAE", "00", 0);

/// This embedded file contains 4bpp tile image data.
const tiles_data align(4) = @embedFile("tiles.bin").*;

/// Buffer will be used to write formatted text.
var text_buffer: [512]u8 = @splat(0);

// VRAM layout for this demo (by screenblock index):
// 0..1: 64x 8bpp tiles from tiles.bin
// 2..3: 128x (32x4) 4bpp tiles reserved as a render target for text
// 4: Background 0 (normal)
// 5: Background 2 (affine)

pub export fn main() void {
    // Copy some tiles into VRAM to use for the affine background.
    gba.display.memcpyBackgroundTiles8Bpp(0, @ptrCast(&tiles_data));
    
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .rgb(26, 26, 26);
    gba.display.bg_palette.banks[0][2] = .rgb(31, 0, 0);
    gba.display.bg_palette.banks[0][3] = .rgb(6, 31, 6);
    gba.display.bg_palette.banks[0][4] = .rgb(9, 22, 31);
    gba.display.bg_palette.banks[0][15] = .white;
    
    // Initialize a regular background. This will be used to display text.
    gba.display.bg_ctrl[0] = .{
        .base_screenblock = 4,
        .size = .normal_32x32,
    };
    const normal_bg_map = gba.display.BackgroundMap.initCtrl(gba.display.bg_ctrl[0]);
    normal_bg_map.getBaseScreenblock().fillRect(.{ .tile = 128 }, 0, 0, 32, 16);
    normal_bg_map.getBaseScreenblock().fillRectLinear(.{ .tile = 128 }, 0, 16, 32, 4);
    
    // Initialize an affine background layer.
    gba.display.bg_ctrl[2] = .{
        .base_screenblock = 5,
        .size = .affine_16,
    };
    const affine_bg_map = gba.display.AffineBackgroundMap.initCtrl(gba.display.bg_ctrl[2]);
    for(0..affine_bg_map.width()) |x| {
        for(0..affine_bg_map.height()) |y| {
            const tile_i = (x & 0xf) | ((y & 0x3) << 4);
            affine_bg_map.set(@truncate(x), @truncate(y), @truncate(tile_i));
        }
    }
    
    // Draw initial static text, which doesn't change from frame to frame.
    gba.text.drawToCharblock4Bpp(.{
        .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4[128]),
        .color = 15,
        .x = 8,
        .y = 4,
        .text = "Press left & right to rotate ↻",
    });
    gba.text.drawToCharblock4Bpp(.{
        .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4[128]),
        .color = 15,
        .x = 8,
        .y = 14,
        .text = "Angle:",
    });
    
    // Initialize the display.
    gba.display.ctrl.* = .initMode1(.{
        .bg0 = true, // Normal background
        .bg2 = true, // Affine background
    });
    
    // Initialize some important variables.
    var angle: gba.math.FixedU16R16 = .{};
    var input: gba.input.KeysState = .{};
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    // Main loop.
    while (true) {
        // Run this loop only once per frame.
        gba.bios.vblankIntrWait();
        
        // Check the state of button inputs for this frame.
        input.poll();
        
        // Handle dpad left and right inputs.
        if(input.isPressed(.left)) {
            angle.value +%= 0x80;
        }
        else if(input.isPressed(.right)) {
            angle.value -%= 0x80;
        }
        
        // Set affine transform values.
        // Rotate the background by the current angle around its center,
        // showing it near the center of the screen.
        gba.display.bg_2_affine.* = .initRotScale(.{
            .bg_origin = .init(.fromInt(64), .fromInt(64)),
            .screen_origin = .init(.fromInt(120), .fromInt(68)),
            .angle = angle,
        });
        
        // Clear tiles where angle text is about to be drawn to.
        // This clears text drawn in the previous frame.
        gba.display.Tile4Bpp.fillLine(
            gba.display.bg_charblock_tiles.bpp_4[197..205],
            0,
        );
        
        // Draw an up-to-date value for the angle, converted to degrees.
        const angle_display = angle.toDegrees().to(gba.math.FixedI32R8);
        const fmt_len = angle_display.formatDecimal(&text_buffer, .{
            .min_fraction_digits = 2,
            .max_fraction_digits = 2,
            .pad_left_len = 6,
        });
        text_buffer[fmt_len] = 0xc2; // Continuation byte (UTF-8 encoding)
        text_buffer[fmt_len + 1] = '°';
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4[128]),
            .color = 15,
            .x = 40,
            .y = 14,
            .text = text_buffer[0..fmt_len + 2],
            .space_width = 6,
        });
    }
}
