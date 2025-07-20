const gba = @import("gba");
const display = gba.display;

export var header linksection(".gbaheader") = gba.Header.init("MODE4FLIP", "AMFE", "00", 0);

const front_image_data = @embedFile("front.agi");
const back_image_data = @embedFile("back.agi");
const palette_data = @embedFile("mode4flip.agp");

fn loadImageData() void {
    gba.mem.memcpy32(display.vram, @as([*]align(2) const u8, @ptrCast(@alignCast(front_image_data))), front_image_data.len);
    gba.mem.memcpy32(display.back_page, @as([*]align(2) const u8, @ptrCast(@alignCast(back_image_data))), back_image_data.len);
    gba.mem.memcpy32(gba.bg.palette, @as([*]align(2) const u8, @ptrCast(@alignCast(palette_data))), palette_data.len);
}

pub export fn main() void {
    display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    loadImageData();

    var i: u32 = 0;
    while (true) : (i += 1) {
        while(gba.input.state.startIsPressed()) {}

        display.naiveVSync();

        if (i == 60 * 2) {
            i = 0;
            display.pageFlip();
        }
    }
}
