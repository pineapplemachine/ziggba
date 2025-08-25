const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("PANICEXAMPLE", "APNE", "00", 0);

pub export fn main() void {
    // Initialize the display with a solid green background.
    gba.display.ctrl.* = .initMode0(.{});
    gba.display.bg_palette.colors[0] = .green;
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    // Keep track of button inputs.
    var input: gba.input.BufferedKeysState = .{};
    
    // Main loop.
    // Panic and change the background to red upon any button being pressed.
    while(true) {
        gba.bios.vblankIntrWait();
        if(input.isJustPressed(.A)) {
            gba.display.bg_palette.colors[0] = .red;
            // @panic("Button pressed");
        }
    }
}
