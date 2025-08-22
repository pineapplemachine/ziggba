const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("HELLOWORLD", "AHWE", "00", 0);

pub export fn main() void {
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .white;
    
    // Initialize a background, to be used for displaying text.
    gba.bg.ctrl[0] = .{
        .base_screenblock = 31,
        .size = .normal_32x32,
    };
    const normal_bg_map = gba.display.BackgroundMap.initCtrl(gba.bg.ctrl[0]);
    normal_bg_map.getBaseScreenblock().fillLinear(.{});
    
    // Draw text to the tile memory used by the initialized background.
    gba.text.drawToCharblock4Bpp(.{
        .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
        .color = 1,
        .x = 8,
        .y = 4,
        .line_height = 16,
        .text = (
            "Hello, world!\n" ++ // English (ASCII)
            "Ｈｅｌｌｏ，　ｗｏｒｌｄ！\n" ++ // English (Fullwidth)
            "¡Hola, mundo!\n" ++ // Spanish
            "Hej, världen!\n" ++ // Swedish
            "Γειά σου, κόσμε!\n" ++ // Greek
            "Привет, мир!\n" ++ // Russian
            "こんにちは、せかい！" // Japanese (Kana)
        ),
    });
    
    // Initialize the display.
    gba.display.ctrl.* = gba.display.Control{
        .bg0 = true,
    };
    
    // Initialize some important variables.
    var scroll: i16 = 0;
    var input: gba.input.KeysState = .{};
    
    // Main loop.
    while (true) {
        // Run this loop only once per frame.
        gba.display.naiveVSync();
        
        // Check the state of button inputs for this frame.
        input.poll();
        
        // Handle dpad up and down, to scroll the background up and down.
        if(input.isPressed(.down)) {
            scroll -%= 2;
        }
        else if(input.isPressed(.up)) {
            scroll +%= 2;
        }
        gba.bg.scroll[0].y = @truncate(scroll);
    }
}
