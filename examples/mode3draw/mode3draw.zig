const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MODE3DRAW", "AWJE", "00", 0);

pub export fn main() void {
    gba.display.ctrl.* = .{
        .mode = .mode3,
        .bg2 = true,
    };

    // Fill screen with grey color
    gba.bitmap.Mode3.fill(.rgb(12, 12, 12));

    // Rectangles:
    gba.bitmap.Mode3.rect(.{ 12, 8 }, .{ 109, 72 }, .red);
    gba.bitmap.Mode3.rect(.{ 108, 72 }, .{ 132, 88 }, .green);
    gba.bitmap.Mode3.rect(.{ 132, 88 }, .{ 228, 152 }, .blue);

    // Rectangle frames
    gba.bitmap.Mode3.frame(.{ 132, 8 }, .{ 228, 72 }, .cyan);
    gba.bitmap.Mode3.frame(.{ 109, 73 }, .{ 131, 87 }, .black);
    gba.bitmap.Mode3.frame(.{ 12, 88 }, .{ 108, 152 }, .yellow);

    for (0..9) |i| {
        const m: u8 = @intCast(i);
        const n: u5 = @intCast(3 * m + 7);
        // Lines in top right frame
        gba.bitmap.Mode3.line(
            .{ 132 + 11 * m, 9 },
            .{ 226, 12 + 7 * m },
            .rgb(n, 0, n),
        );
        gba.bitmap.Mode3.line(
            .{ 226 - 11 * m, 70 },
            .{ 133, 69 - 7 * m },
            .rgb(n, 0, n),
        );
        // Lines in bottom left frame
        gba.bitmap.Mode3.line(
            .{ 15 + 11 * m, 88 },
            .{ 104 - 11 * m, 150 },
            .rgb(0, n, n),
        );
    }
}
