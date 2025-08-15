const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE4FLIP", "AMFE", "00", 0);

const front_image_data align(4) = @embedFile("front.agi");
const back_image_data align(4) = @embedFile("back.agi");
const palette_data align(4) = @embedFile("mode4flip.agp");

fn loadImageData() void {
    gba.mem.memcpy(gba.display.vram, front_image_data, front_image_data.len);
    gba.mem.memcpy(gba.display.back_page, back_image_data, back_image_data.len);
    gba.display.memcpyBackgroundPalette(0, @ptrCast(@alignCast(palette_data)));
}

pub export fn main() void {
    gba.display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    loadImageData();

    var i: u32 = 0;
    while (true) : (i += 1) {
        // Pause while the start button is held down.
        while(gba.input.state.startIsPressed()) {}

        gba.display.naiveVSync();

        // Flip every 120 frames, i.e. about every two seconds.
        if (i == 120) {
            i = 0;
            gba.display.pageFlip();
        }
    }
}
