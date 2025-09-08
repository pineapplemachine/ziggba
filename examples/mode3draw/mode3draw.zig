const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE3DRAW", "AM3E", "00", 0);

pub export fn main() void {
    // Initialize graphics mode 3.
    gba.display.ctrl.* = .initMode3(.{});
    const mode3 = gba.display.getMode3Surface().draw();

    // Fill the buffer initially with gray.
    mode3.fill(.rgb(12, 12, 12));
    
    // Draw solid rectangles.
    mode3.fillRect(12, 8, 96, 64, .red);
    mode3.fillRect(108, 72, 24, 16, .green);
    mode3.fillRect(132, 88, 96, 64, .blue);

    // Draw rectangle frames.
    mode3.rectOutline(132, 8, 96, 64, .cyan);
    mode3.rectOutline(109, 73, 22, 14, .black);
    mode3.rectOutline(12, 88, 96, 64, .yellow);
    
    // Draw lines.
    for(0..9) |i| {
        const m: u8 = @intCast(i);
        const n: u5 = @intCast(3 * m + 7);
        // Draw lines in the top right frame.
        mode3.line(
            132 + 11 * m,
            9,
            226,
            12 + 7 * m,
            .rgb(n, 0, n),
        );
        mode3.line(
            226 - 11 * m,
            70,
            133,
            69 - 7 * m,
            .rgb(n, 0, n),
        );
        // Draw lines in the bottom left frame.
        mode3.line(
            15 + 11 * m,
            88,
            104 - 11 * m,
            150,
            .rgb(0, n, n),
        );
    }
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    while(true) {
        gba.bios.vblankIntrWait();
    }
}
