const gba = @import("gba");
const brin = @import("brin.zig");

export var header linksection(".gbaheader") = gba.Header.init("TILEDEMO", "ATDE", "00", 0);

// Screenblock index is chosen to not overlap with VRAM used by tiles.
const screenblock_index: u5 = 31;

fn loadData() void {
    const screenblock = &gba.display.screenblocks[screenblock_index];
    gba.display.memcpyBackgroundPalette(0, @ptrCast(&brin.pal));
    gba.display.memcpyBackgroundTiles4Bpp(0, @ptrCast(&brin.tiles));
    gba.mem.memcpy16(screenblock, &brin.map, brin.map.len);
}

pub export fn main() void {
    loadData();
    gba.bg.ctrl[0] = .{
        .base_screenblock = screenblock_index,
        .size = .normal_64x32,
    };
    gba.bg.scroll[0] = .zero;

    gba.display.ctrl.* = .{
        .bg0 = true,
    };

    var input: gba.input.KeysState = .{};
    var x: i10 = 192;
    var y: i10 = 64;

    while (true) {
        gba.display.naiveVSync();

        input.poll();

        x +%= input.getAxisHorizontal();
        y +%= input.getAxisVertical();

        gba.bg.scroll[0] = .init(x, y);
    }
}
