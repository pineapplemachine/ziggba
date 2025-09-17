const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("HELLOWORLD", "AHWE", "00", 0);

pub export fn main() void {
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .white;
    
    // Initialize a background, to be used for displaying text.
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 31,
        .size = .size_32x32,
    });
    bg0_map.getBaseScreenblock().fillLinear(.{});
    
    // Draw text to the tile memory used by the initialized background.
    const text_surface = gba.display.bg_blocks.getSurface4Bpp(0, 32, 32);
    const text_hello = (
        "Hello, world!\n" ++ // English (ASCII)
        "Ｈｅｌｌｏ，　ｗｏｒｌｄ！\n" ++ // English (Fullwidth)
        "¡Hola, mundo!\n" ++ // Spanish
        "Hej, världen!\n" ++ // Swedish
        "Γειά σου, κόσμε!\n" ++ // Greek
        "Привет, мир!\n" ++ // Russian
        "こんにちは、せかい！" // Japanese (Kana)
    );
    text_surface.draw().text(text_hello, .init(1), .{
        .x = 8,
        .y = 4,
        .line_height = 16,
    });
    
    // Initialize the display.
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });
    
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
        gba.display.bg_scroll[0].y = @truncate(scroll);
    }
}
