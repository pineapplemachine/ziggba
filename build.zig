const std = @import("std");
const gba = @import("src/build/gba.zig");

pub fn build(b: *std.Build) void {
    _ = gba.addGBAExecutable(b, "first", "examples/first/first.zig");
    _ = gba.addGBAExecutable(b, "mode3draw", "examples/mode3draw/mode3draw.zig");
    _ = gba.addGBAExecutable(b, "mode4draw", "examples/mode4draw/mode4draw.zig");
    _ = gba.addGBAExecutable(b, "debugPrint", "examples/debugPrint/debugPrint.zig");
    _ = gba.addGBAExecutable(b, "secondsTimer", "examples/secondsTimer/secondsTimer.zig");

    // Mode 4 Flip
    const mode4flip = gba.addGBAExecutable(b, "mode4flip", "examples/mode4flip/mode4flip.zig");
    gba.convertMode4Images(mode4flip, &[_]gba.ImageSourceTarget{
        .{
            .source = "examples/mode4flip/front.bmp",
            .target = "examples/mode4flip/front.agi",
        },
        .{
            .source = "examples/mode4flip/back.bmp",
            .target = "examples/mode4flip/back.agi",
        },
    }, "examples/mode4flip/mode4flip.agp");
    
    // Music example (Jesu, Joy of Man's Desiring)
    var jesuMusic_palette = [_]gba.tiles.ColorRgb888 {
        .{ .r = 0, .g = 0, .b = 0 }, // Transparency
        .{ .r = 255, .g = 255, .b = 255 },
        .{ .r = 0, .g = 0, .b = 0 },
    };
    _ = gba.addGBAExecutable(b, "jesuMusic", "examples/jesuMusic/jesuMusic.zig");
    gba.tiles.convertSaveImagePath(
        []gba.tiles.ColorRgb888,
        "examples/jesuMusic/charset.png",
        "examples/jesuMusic/charset.bin",
        .{
            .allocator = std.heap.page_allocator,
            .bpp = .bpp_4,
            .palette_fn = gba.tiles.getNearestPaletteColor,
            .palette_ctx = jesuMusic_palette[0..],
        },
    ) catch {};

    // Key demo, TODO: Use image created by the build system once we support indexed image
    _ = gba.addGBAExecutable(b, "keydemo", "examples/keydemo/keydemo.zig");
    // keydemo.addCSourceFile(.{
    //     .file = .{ .src_path = .{ .owner = b, .sub_path = "examples/keydemo/gba_pic.c" } },
    //     .flags = &[_][]const u8{"-std=c99"},
    // });

    // Simple OBJ demo, TODO: Use tile and palette data created by the build system
    _ = gba.addGBAExecutable(b, "objDemo", "examples/objDemo/objDemo.zig");
    // objDemo.addCSourceFile(.{
    //     .file = .{ .src_path = .{ .owner = b, .sub_path = "examples/objDemo/metroid_sprite_data.c" } },
    //     .flags = &[_][]const u8{"-std=c99"},
    // });

    // tileDemo, TODO: Use tileset, tile and palette created by the build system
    _ = gba.addGBAExecutable(b, "tileDemo", "examples/tileDemo/tileDemo.zig");
    // tileDemo.addCSourceFile(.{
    //     .file = .{ .src_path = .{ .owner = b, .sub_path = "examples/tileDemo/brin.c" } },
    //     .flags = &[_][]const u8{"-std=c99"},
    // });

    // screenBlock
    _ = gba.addGBAExecutable(b, "screenBlock", "examples/screenBlock/screenBlock.zig");

    // charBlock
    _ = gba.addGBAExecutable(b, "charBlock", "examples/charBlock/charBlock.zig");
    // charBlock.addCSourceFile(.{
    //     .file = .{ .src_path = .{.owner = b, .sub_path = "examples/charBlock/cbb_ids.c" } },
    //     .flags = &[_][]const u8{"-std=c99"},
    // });

    // objAffine
    _ = gba.addGBAExecutable(b, "objAffine", "examples/objAffine/objAffine.zig");
    // objAffine.addCSourceFile(.{
    //     .file = .{ .src_path = .{ .owner = b, .sub_path = "examples/objAffine/metr.c" } },
    //     .flags = &[_][]const u8{"-std=c99"},
    // });
}
