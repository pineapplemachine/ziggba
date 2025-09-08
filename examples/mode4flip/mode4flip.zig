const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE4FLIP", "AMFE", "00", 0);

const front_image_data align(4) = @embedFile("front.agi").*;
const back_image_data align(4) = @embedFile("back.agi").*;
const palette_data align(4) = @embedFile("mode4flip.agp").*;

pub export fn main() void {
    // Initialize graphics mode 4.
    gba.display.ctrl.* = .initMode4(.{});
    
    // Load graphics data into VRAM.
    gba.mem.memcpy(gba.display.getMode4Surface(0).data, &front_image_data, front_image_data.len);
    gba.mem.memcpy(gba.display.getMode4Surface(1).data, &back_image_data, back_image_data.len);
    gba.mem.memcpy(gba.display.bg_palette, &palette_data, palette_data.len);
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;

    var i: u32 = 0;
    while(true) {
        // Run this loop at most once per frame.
        gba.bios.vblankIntrWait();

        // Flip every 120 frames, i.e. about every two seconds,
        // but pause this while the start button is held down.
        if(!gba.input.state.isPressed(.start)) {
            i += 1;
            if (i >= 120) {
                gba.display.ctrl.bitmapFlip();
                i = 0;
            }
        }
    }
}
