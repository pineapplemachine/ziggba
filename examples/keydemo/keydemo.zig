const gba = @import("gba");
const gba_pic = @import("gba_pic.zig");

export var header linksection(".gbaheader") = gba.Header.init("KEYDEMO", "AKDE", "00", 0);

fn loadImageData() void {
    gba.mem.memcpy(gba.display.vram, &gba_pic.bitmap, gba_pic.bitmap.len << 2);
    gba.display.memcpyBackgroundPalette(0, @ptrCast(&gba_pic.pal));
}

pub export fn main() void {
    gba.display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    loadImageData();

    const color_up = gba.Color.rgb(27, 27, 29);
    const button_palette_id = 5;
    const bank0 = &gba.display.bg_palette.banks[0];

    var input: gba.input.BufferedKeysState = .{};
    var frame: u3 = 0;
    while (true) {
        gba.display.naiveVSync();

        if (frame == 0) {
            input.poll();
        }

        for (0..10) |i| {
            const key: gba.input.Key = @enumFromInt(i);
            bank0[button_palette_id + i] = if (input.isJustPressed(key))
                gba.Color.red
            else if (input.isJustReleased(key))
                gba.Color.yellow
            else if (input.isPressed(key))
                gba.Color.lime
            else
                color_up;
        }

        frame +%= 1;
    }
}
