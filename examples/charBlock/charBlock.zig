const gba = @import("gba");
const input = gba.input;
const display = gba.display;
const bg = gba.bg;

const cbb_ids = @import("cbb_ids.zig");

const character_block_4 = 0;
const screen_block_4 = 2;

const character_block_8 = 2;
const screen_block_8 = 4;

export var header linksection(".gbaheader") = gba.Header.init("CHARBLOCK", "ASBE", "00", 0);

fn loadTiles() void {
    const tl4: [*]align(4) const gba.display.Tile4Bpp = @ptrCast(&cbb_ids.ids_4_tiles);
    const tl8: [*]align(4) const gba.display.Tile8Bpp = @ptrCast(&cbb_ids.ids_8_tiles);

    // Loading tiles. 4-bit tiles to blocks 0 and 1
    gba.display.charblocks[0].bpp_4[1] = tl4[1];
    gba.display.charblocks[0].bpp_4[2] = tl4[2];
    gba.display.charblocks[1].bpp_4[0] = tl4[3];
    gba.display.charblocks[1].bpp_4[1] = tl4[4];

    // and the 8-bit tiles to blocks 2 though 5
    gba.display.charblocks[2].bpp_8[1] = tl8[1];
    gba.display.charblocks[2].bpp_8[2] = tl8[2];
    gba.display.charblocks[3].bpp_8[0] = tl8[3];
    gba.display.charblocks[3].bpp_8[1] = tl8[4];
    gba.display.charblocks[4].bpp_8[0] = tl8[5];
    gba.display.charblocks[4].bpp_8[1] = tl8[6];
    gba.display.charblocks[5].bpp_8[0] = tl8[7];
    gba.display.charblocks[5].bpp_8[1] = tl8[8];

    // Load palette
    gba.mem.memcpy32(gba.bg.palette, &cbb_ids.ids_4_pal, cbb_ids.ids_4_pal.len * 4);
    gba.mem.memcpy32(gba.obj.palette, &cbb_ids.ids_4_pal, cbb_ids.ids_4_pal.len * 4);
}

fn initMaps() void {
    // map coords (0, 2)
    const screen_entry_4: []volatile bg.TextScreenEntry = bg.screen_block_ram[screen_block_4][2 * 32 ..];
    // map coords (0, 8)
    const screen_entry_8: []volatile bg.TextScreenEntry = bg.screen_block_ram[screen_block_8][8 * 32 ..];

    // Show first tiles of char-blocks available to background 0
    // tiles 1, 2 of CharacterBlock4
    screen_entry_4[0x01].tile_index = 0x0001;
    screen_entry_4[0x02].tile_index = 0x0002;
    // tiles 0, 1 of CharacterBlock4+1
    screen_entry_4[0x20].tile_index = 0x0200;
    screen_entry_4[0x21].tile_index = 0x0201;

    // Show first tiles of char-blocks available to background 1
    // tiles 1, 2 of CharacterBlock8 (== 2)
    screen_entry_8[0x01].tile_index = 0x0001;
    screen_entry_8[0x02].tile_index = 0x0002;

    // tiles 1, 2 of CharacterBlock8+1
    screen_entry_8[0x20].tile_index = 0x0100;
    screen_entry_8[0x21].tile_index = 0x0101;

    // tiles 1, 2 of char-block CharacterBlock8+2 (== CBB_OBJ_LO)
    screen_entry_8[0x40].tile_index = 0x0200;
    screen_entry_8[0x41].tile_index = 0x0201;

    // tiles 1, 2 of char-block CharacterBlock8+3 (== CBB_OBJ_HI)
    screen_entry_8[0x60].tile_index = 0x0300;
    screen_entry_8[0x61].tile_index = 0x0301;
}

pub export fn main() void {
    loadTiles();

    initMaps();

    display.ctrl.* = .{
        .bg0 = true,
        .bg1 = true,
        .obj = true,
    };

    bg.ctrl[0] = .{
        .tile_base_block = character_block_4,
        .screen_base_block = screen_block_4,
    };

    bg.ctrl[1] = .{
        .tile_base_block = character_block_8,
        .screen_base_block = screen_block_8,
        .palette_mode = .bpp_8,
    };
}
