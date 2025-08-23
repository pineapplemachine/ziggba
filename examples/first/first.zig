const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("FIRST", "AFSE", "00", 0);

pub export fn main() void {
    gba.display.ctrl.* = .initMode3(.{});
    gba.bitmap.Mode3.setPixel(120, 80, .rgb(31, 0, 0));
    gba.bitmap.Mode3.setPixel(136, 80, .rgb(0, 31, 0));
    gba.bitmap.Mode3.setPixel(120, 96, .rgb(0, 0, 31));
}
