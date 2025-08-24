const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE4DRAW", "AM4E", "00", 0);

const palette = [_]gba.ColorRgb555{
    .black,
    .rgb(12, 12, 12),
    .red,
    .green,
    .blue,
    .cyan,
    .black,
    .yellow,
} ++ blk: {
    var pink: [9]gba.ColorRgb555 = undefined;
    var teal: [9]gba.ColorRgb555 = undefined;
    for (0..9) |i| {
        const j = @as(u5, @intCast(i)) * 3 + 7;
        pink[i] = .rgb(j, 0, j);
        teal[i] = .rgb(0, j, j);
    }
    break :blk pink ++ teal;
};

pub export fn main() void {
    // Initialize a palette for use with mode 4's 8bpp paletted graphics.
    gba.display.memcpyBackgroundPalette(0, &palette);

    // Initialize graphics mode 4.
    gba.display.ctrl.* = .initMode4(.{});
    const mode4_front = gba.display.getMode4Bitmap(0);

    // Fill the buffer initially with gray.
    mode4_front.fill(1);

    // Draw solid rectangles.
    mode4_front.fillRect(12, 8, 96, 64, 2);
    mode4_front.fillRect(108, 72, 24, 16, 3);
    mode4_front.fillRect(132, 88, 96, 64, 4);

    // Draw rectangle frames.
    mode4_front.drawRectOutline(132, 8, 96, 64, 5);
    mode4_front.drawRectOutline(109, 73, 22, 14, 6);
    mode4_front.drawRectOutline(12, 88, 96, 64, 7);

    // Draw lines.
    for (0..9) |i| {
        const n: u8 = @intCast(i);
        // Draw lines in the top right frame.
        mode4_front.drawLine(
            132 + 11 * n,
            9,
            226,
            12 + 7 * n,
            8 + n,
        );
        mode4_front.drawLine(
            226 - 11 * n,
            70,
            133,
            69 - 7 * n,
            8 + n,
        );
        // Draw lines in the bottom left frame.
        mode4_front.drawLine(
            15 + 11 * n,
            88,
            104 - 11 * n,
            150,
            17 + n,
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
