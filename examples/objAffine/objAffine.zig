const gba = @import("gba");
const metr = @import("metr.zig");

export var header linksection(".gbaheader") = gba.Header.init("OBJAFFINE", "AOAE", "00", 0);

pub export fn main() void {
    gba.display.memcpyObjectTiles4Bpp(0, @ptrCast(&metr.box_tiles));
    gba.display.memcpyObjectPalette(0, @ptrCast(&metr.pal));

    const metroid: gba.obj.Obj = .initAffine(.{
        .size = .size_64x64,
        .x = 96,
        .y = 32,
        .affine_index = 0,
    });
    gba.obj.setTransform(metroid.transform.affine_index, .identity);
    
    const shadow_metroid: gba.obj.Obj = .initAffine(.{
        .size = .size_64x64,
        .x = 96,
        .y = 32,
        .affine_index = 1,
        .palette = 1,
    });
    gba.obj.setTransform(shadow_metroid.transform.affine_index, .identity);

    gba.obj.hideAllObjects();
    gba.obj.objects[0] = metroid;
    gba.obj.objects[1] = shadow_metroid;
    
    gba.display.ctrl.* = gba.display.Control{
        .obj_mapping = .map_1d,
        .bg0 = true,
        .obj = true,
    };
    
    var frame: u32 = 0;

    while(true) : (frame +%= 1) {
        gba.display.naiveVSync();
        
        gba.obj.setTransform(metroid.transform.affine_index, .initRotation(
            .initRaw(@truncate(frame << 8)),
        ));
    }
}
