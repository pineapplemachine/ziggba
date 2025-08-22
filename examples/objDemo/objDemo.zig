const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("OBJDEMO", "AODE", "00", 0);

const metr = @import("metroid_sprite_data.zig");

fn loadSpriteData() void {
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&metr.tiles));
    gba.display.memcpyObjectPalette(0, @ptrCast(&metr.pal));
}

pub export fn main() void {
    gba.display.ctrl.* = .initMode0(.{
        .obj_mapping = .map_1d,
        .obj = true,
    });

    loadSpriteData();

    var metroid: gba.obj.Obj = .init(.{
        .size = .size_64x64,
        .x = 100,
        .y = 150,
    });
    
    var input: gba.input.BufferedKeysState = .{};
    var x: i9 = 96;
    var y: i8 = 32;
    const scale_factor: i4 = 2;
    var base_tile_index: i10 = 0;

    while (true) {
        gba.display.naiveVSync();

        input.poll();

        x +%= scale_factor * input.getAxisHorizontal();
        y +%= scale_factor * input.getAxisVertical();

        base_tile_index +%= input.getAxisShoulders();

        if (input.isJustPressed(.A)) {
            metroid.transform.flip.x = !metroid.transform.flip.x;
        }
        if (input.isJustPressed(.B)) {
            metroid.transform.flip.y = !metroid.transform.flip.y;
        }

        metroid.palette = if (input.isPressed(.select)) 1 else 0;

        gba.display.ctrl.obj_mapping = (
            if (input.isPressed(.start)) .map_2d else .map_1d
        );

        metroid.setPosition(@bitCast(x), @bitCast(y));
        metroid.base_tile = @bitCast(base_tile_index);
        
        gba.obj.objects[0] = metroid;
    }
}
