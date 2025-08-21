const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("OBJDEMO", "AODE", "00", 0);

const metr = @import("metroid_sprite_data.zig");

fn loadSpriteData() void {
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&metr.tiles));
    gba.display.memcpyObjectPalette(0, @ptrCast(&metr.pal));
}

pub export fn main() void {
    gba.display.ctrl.* = .{
        .obj_mapping = .one_dimension,
        .obj = true,
    };

    loadSpriteData();

    const metroid: gba.obj.Obj = .init(.{
        .size = .size_64x64,
        .x = 100,
        .y = 150,
    });
    
    var input: gba.input.BufferedKeysState = .{};
    var x: i9 = 96;
    var y: i8 = 32;
    const scale_factor: i4 = 2;
    var tile_index: i10 = 0;

    while (true) {
        gba.display.naiveVSync();

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

        gba.display.ctrl.obj_mapping = (
            if (input.isPressed(.start)) .two_dimensions else .one_dimension
        );

        metroid.setPosition(@bitCast(x), @bitCast(y));
        metroid.tile = @bitCast(tile_index);
        
        gba.obj.objects[0] = metroid;
    }
}
