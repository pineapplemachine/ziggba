const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE4DRAW", "AWJE", "00", 0);

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
    gba.display.memcpyBackgroundPalette(0, &palette);

    gba.display.ctrl.* = .initMode4(.{});

    // Fill screen with grey color
    gba.bitmap.Mode4.fill(1);

    // Rectangles:
    gba.bitmap.Mode4.rect(.{ 12, 8 }, .{ 109, 72 }, 2);
    gba.bitmap.Mode4.rect(.{ 108, 72 }, .{ 132, 88 }, 3);
    gba.bitmap.Mode4.rect(.{ 132, 88 }, .{ 228, 152 }, 4);

    // Rectangle frames
    gba.bitmap.Mode4.frame(.{ 132, 8 }, .{ 228, 72 }, 5);
    gba.bitmap.Mode4.frame(.{ 109, 73 }, .{ 131, 87 }, 6);
    gba.bitmap.Mode4.frame(.{ 12, 88 }, .{ 108, 152 }, 7);

    for (0..9) |i| {
        const n: u8 = @intCast(i);
        // Lines in top right frame
        gba.bitmap.Mode4.line(.{ 132 + 11 * n, 9 }, .{ 226, 12 + 7 * n }, 8 + n);
        gba.bitmap.Mode4.line(.{ 226 - 11 * n, 70 }, .{ 133, 69 - 7 * n }, 8 + n);
        // Lines in bottom left frame
        gba.bitmap.Mode4.line(.{ 15 + 11 * n, 88 }, .{ 104 - 11 * n, 150 }, 17 + n);
    }
}
