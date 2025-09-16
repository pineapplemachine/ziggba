const gba = @import("gba");

const cbb_ids = @import("cbb_ids.zig");

export var header linksection(".gbaheader") = gba.Header.init("CHARBLOCK", "ACBE", "00", 0);

// Charblock index to use for a 4bpp background.
const charblock_4bpp_index = 0;
// Screenblock index to use for a 4bpp background.
const screenblock_4bpp_index = 2;
// Charblock index to use for an 8bpp background.
const charblock_8bpp_index = 2;
// Screenblock index to use for an 8bpp background.
const screenblock_8bpp_index = 4;

fn loadTiles() void {
    const tiles_4bpp: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(&cbb_ids.ids_4_tiles);
    const tiles_8bpp: [*]align(4) const gba.display.Tile8Bpp = @ptrCast(&cbb_ids.ids_8_tiles);

    // Load palette
    gba.display.memcpyBackgroundPalette(0, @ptrCast(&cbb_ids.ids_4_pal));
    gba.display.memcpyObjectPalette(0, @ptrCast(&cbb_ids.ids_4_pal));

    // Loading tiles. Copy 4-bit tiles to charblocks 0 and 1.
    gba.display.charblocks[0].tiles_4bpp[1] = tiles_4bpp[1];
    gba.display.charblocks[0].tiles_4bpp[2] = tiles_4bpp[2];
    gba.display.charblocks[1].tiles_4bpp[0] = tiles_4bpp[3];
    gba.display.charblocks[1].tiles_4bpp[1] = tiles_4bpp[4];

    // Copy 8-bit tiles to charblocks 2 though 5.
    gba.display.charblocks[2].tiles_8bpp[1] = tiles_8bpp[1];
    gba.display.charblocks[2].tiles_8bpp[2] = tiles_8bpp[2];
    gba.display.charblocks[3].tiles_8bpp[0] = tiles_8bpp[3];
    gba.display.charblocks[3].tiles_8bpp[1] = tiles_8bpp[4];
    gba.display.charblocks[4].tiles_8bpp[0] = tiles_8bpp[5];
    gba.display.charblocks[4].tiles_8bpp[1] = tiles_8bpp[6];
    gba.display.charblocks[5].tiles_8bpp[0] = tiles_8bpp[7];
    gba.display.charblocks[5].tiles_8bpp[1] = tiles_8bpp[8];
}

fn initMaps() void {
    const screenblock_4bpp = &gba.display.screenblocks[screenblock_4bpp_index];
    const screenblock_8bpp = &gba.display.screenblocks[screenblock_8bpp_index];

    // Show first tiles of char-blocks available to background 0
    screenblock_4bpp.set(1, 2, .{ .tile = 0x0001 });
    screenblock_4bpp.set(2, 2, .{ .tile = 0x0002 });
    screenblock_4bpp.set(0, 3, .{ .tile = 0x0200 });
    screenblock_4bpp.set(1, 3, .{ .tile = 0x0201 });

    // Show first tiles of char-blocks available to background 1
    screenblock_8bpp.set(1, 8, .{ .tile = 0x0001 });
    screenblock_8bpp.set(2, 8, .{ .tile = 0x0002 });
    screenblock_8bpp.set(0, 9, .{ .tile = 0x0100 });
    screenblock_8bpp.set(1, 9, .{ .tile = 0x0101 });

    // TODO: Why do these not display? Are they supposed to?
    screenblock_8bpp.set(0, 10, .{ .tile = 0x0200 });
    screenblock_8bpp.set(1, 10, .{ .tile = 0x0201 });
    screenblock_8bpp.set(0, 11, .{ .tile = 0x0300 });
    screenblock_8bpp.set(1, 11, .{ .tile = 0x0301 });
}

pub export fn main() void {
    loadTiles();

    initMaps();

    gba.display.ctrl.* = .{
        .bg0 = true,
        .bg1 = true,
    };

    gba.display.bg_ctrl[0] = .{
        .base_charblock = charblock_4bpp_index,
        .base_screenblock = screenblock_4bpp_index,
    };

    gba.display.bg_ctrl[1] = .{
        .base_charblock = charblock_8bpp_index,
        .base_screenblock = screenblock_8bpp_index,
        .bpp = .bpp_8,
    };
}
