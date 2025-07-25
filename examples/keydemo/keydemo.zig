const gba = @import("gba");
const gba_pic = @import("gba_pic.zig");
const Color = gba.Color;
const display = gba.display;

export var header linksection(".gbaheader") = gba.Header.init("KEYDEMO", "AKDE", "00", 0);

fn loadImageData() void {
    gba.mem.memcpy32(gba.display.vram, &gba_pic.bitmap, gba_pic.bitmap.len * 4);
    gba.mem.memcpy32(gba.bg.palette, &gba_pic.pal, gba_pic.pal.len * 4);
}

pub export fn main() void {
    display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    loadImageData();

    const color_up = Color.rgb(27, 27, 29);
    const button_palette_id = 5;
    const bank0 = &gba.bg.palette.banks[0];

    var input: gba.input.BufferedKeysState = .{};
    var frame: u3 = 0;
    while (true) {
        display.naiveVSync();

        if (frame == 0) {
            input.poll();
        }

        for (0..10) |i| {
            const key: gba.input.Key = @enumFromInt(i);
            bank0[button_palette_id + i] = if (input.isJustPressed(key))
                Color.red
            else if (input.isJustReleased(key))
                Color.yellow
            else if (input.isPressed(key))
                Color.lime
            else
                color_up;
        }

        frame +%= 1;
    }
}
