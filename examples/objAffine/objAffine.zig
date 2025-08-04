const gba = @import("gba");
const metr = @import("metr.zig");

export var header linksection(".gbaheader") = gba.Header.init("OBJAFFINE", "AOAE", "00", 0);

pub export fn main() void {
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&metr.box_tiles));
    gba.display.memcpyObjectPalette(0, @ptrCast(&metr.pal));

    var metroid: gba.obj.Obj = .{
        .mode = .affine,
        .transform = .{ .affine_index = 0 },
    };
    metroid.setSize(.@"64x64");
    metroid.setPosition(96, 32);
    gba.obj.setObjectTransform(
        metroid.transform.affine_index,
        gba.obj.AffineTransform.Identity,
    );
    
    var shadow_metroid: gba.obj.Obj = .{
        .mode = .affine,
        .transform = .{ .affine_index = 1 },
        .palette = 1,
    };
    shadow_metroid.setSize(.@"64x64");
    shadow_metroid.setPosition(96, 32);
    gba.obj.setObjectTransform(
        shadow_metroid.transform.affine_index,
        gba.obj.AffineTransform.Identity,
    );

    gba.obj.hideAllObjects();
    gba.obj.objects[0] = metroid;
    gba.obj.objects[1] = shadow_metroid;
    
    gba.display.ctrl.* = gba.display.Control{
        .obj_mapping = .one_dimension,
        .bg0 = true,
        .obj = true,
    };
    
    var frame: u32 = 0;

    while (true) : (frame +%= 1) {
        gba.display.naiveVSync();

        const transform = gba.obj.AffineTransform.rotateFast(
            .initRaw(@truncate(frame << 8)),
        );
        gba.obj.setObjectTransform(metroid.transform.affine_index, transform);
    }
}
