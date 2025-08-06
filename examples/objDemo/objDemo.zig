const gba = @import("gba");
const display = gba.display;
const obj = gba.obj;

export var header linksection(".gbaheader") = gba.Header.init("OBJDEMO", "AODE", "00", 0);

const metr = @import("metroid_sprite_data.zig");

fn loadSpriteData() void {
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&metr.tiles));
    gba.display.memcpyObjectPalette(0, @ptrCast(&metr.pal));
}

pub export fn main() void {
    display.ctrl.* = .{
        .obj_mapping = .one_dimension,
        .obj = true,
    };

    loadSpriteData();

    var metroid: gba.obj.Obj = .{
        .x_pos = 100,
        .y_pos = 150,
    };
    metroid.setSize(.@"64x64");

    var input: gba.input.BufferedKeysState = .{};
    var x: i9 = 96;
    var y: i8 = 32;
    const scale_factor: i4 = 2;
    var tile_index: i10 = 0;

    while (true) {
        display.naiveVSync();

        input.poll();

        x +%= scale_factor * input.getAxisHorizontal();
        y +%= scale_factor * input.getAxisVertical();

        tile_index +%= input.getAxisShoulders();

        if (input.isJustPressed(.A)) {
            metroid.transform.flip.h = !metroid.transform.flip.h;
        }
        if (input.isJustPressed(.B)) {
            metroid.transform.flip.v = !metroid.transform.flip.v;
        }

        metroid.palette = if (input.isPressed(.select)) 1 else 0;

        display.ctrl.obj_mapping = (
            if (input.isPressed(.start)) .two_dimensions else .one_dimension
        );

        metroid.setPosition(@bitCast(x), @bitCast(y));
        metroid.tile = @bitCast(tile_index);
        
        gba.obj.objects[0] = metroid;
    }
}
