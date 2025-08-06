const gba = @import("gba");
const Mode4 = gba.bitmap.Mode4;

export var header linksection(".gbaheader") = gba.Header.init("MODE4DRAW", "AWJE", "00", 0);

const palette: [26]gba.Color = [_]gba.Color{
    gba.Color.black,
    gba.Color.rgb(12, 12, 12),
    gba.Color.red,
    gba.Color.lime,
    gba.Color.blue,
    gba.Color.cyan,
    gba.Color.black,
    gba.Color.yellow,
} ++ blk: {
    var pink: [9]gba.Color = undefined;
    var teal: [9]gba.Color = undefined;

    for (0..9) |i| {
        const j = @as(u5, @intCast(i)) * 3 + 7;
        pink[i] = gba.Color.rgb(j, 0, j);
        teal[i] = gba.Color.rgb(0, j, j);
    }

    break :blk pink ++ teal;
};

pub export fn main() void {
    gba.display.memcpyBackgroundPalette(0, &palette);

    gba.display.ctrl.* = .{
        .mode = .mode4,
        .bg2 = true,
    };

    // Fill screen with grey color
    Mode4.fill(1);

    // Rectangles:
    Mode4.rect(.{ 12, 8 }, .{ 109, 72 }, 2);
    Mode4.rect(.{ 108, 72 }, .{ 132, 88 }, 3);
    Mode4.rect(.{ 132, 88 }, .{ 228, 152 }, 4);

    // Rectangle frames
    Mode4.frame(.{ 132, 8 }, .{ 228, 72 }, 5);
    Mode4.frame(.{ 109, 73 }, .{ 131, 87 }, 6);
    Mode4.frame(.{ 12, 88 }, .{ 108, 152 }, 7);

    for (0..9) |i| {
        const n: u8 = @intCast(i);
        // Lines in top right frame
        Mode4.line(.{ 132 + 11 * n, 9 }, .{ 226, 12 + 7 * n }, 8 + n);
        Mode4.line(.{ 226 - 11 * n, 70 }, .{ 133, 69 - 7 * n }, 8 + n);
        // Lines in bottom left frame
        Mode4.line(.{ 15 + 11 * n, 88 }, .{ 104 - 11 * n, 150 }, 17 + n);
    }
}
