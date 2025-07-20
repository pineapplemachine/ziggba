const gba = @import("gba");
const display = gba.display;
const obj = gba.obj;
const debug = gba.debug;
const math = gba.math;
const metr = @import("metr.zig");

export var header linksection(".gbaheader") = gba.Header.init("OBJAFFINE", "AODE", "00", 0);

pub export fn main() void {
    display.ctrl.* = .{
        .obj_mapping = .one_dimension,
        .bg0 = true,
        .obj = true,
    };

    debug.init();

    gba.mem.memcpy32(obj.tile_ram, &metr.box_tiles, metr.box_tiles.len * 4);
    gba.mem.memcpy32(obj.palette, &metr.pal, metr.pal.len * 4);

    var metroid: gba.obj.Obj = .{
        .mode = .affine,
        .transform = .{ .affine_index = 0 },
    };
    metroid.setSize(.@"64x64");
    metroid.setPosition(96, 32);
    gba.obj.AffineTransform.Identity.set(metroid.transform.affine_index);
    
    var shadow_metroid: gba.obj.Obj = .{
        .mode = .affine,
        .transform = .{ .affine_index = 31 },
        .palette = 1,
    };
    shadow_metroid.setSize(.@"64x64");
    shadow_metroid.setPosition(96, 32);
    gba.obj.AffineTransform.Identity.set(shadow_metroid.transform.affine_index);

    gba.obj.objects[0] = metroid;
    gba.obj.objects[1] = shadow_metroid;
    
    var frame: u32 = 0;

    while (true) : (frame +%= 1) {
        display.naiveVSync();
        
        // TODO: Doesn't work correctly
        // const transform = gba.obj.AffineTransform.rotate(@intCast(frame));
        // transform.set(metroid.transform.affine_index);
    }
}
