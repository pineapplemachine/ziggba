const std = @import("std");
const gba = @import("src/build/build.zig");

pub fn build(std_b: *std.Build) void {
    const b = gba.GbaBuild.init(std_b);
    
    // TODO: Use tile and palette data created by the build system for demos
    
    // Build font data
    
    _ = b.addBuildFontsStep("font");
    
    // Examples
    
    _ = b.addExecutable("charBlock", "examples/charBlock/charBlock.zig", .{});
    _ = b.addExecutable("debugPrint", "examples/debugPrint/debugPrint.zig", .{});
    _ = b.addExecutable("first", "examples/first/first.zig", .{});
    _ = b.addExecutable("helloWorld", "examples/helloWorld/helloWorld.zig", .{ .text_charsets = .all });
    _ = b.addExecutable("interrupts", "examples/interrupts/interrupts.zig", .{ .text_charsets = .all });
    _ = b.addExecutable("keydemo", "examples/keydemo/keydemo.zig", .{});
    _ = b.addExecutable("memory", "examples/memory/memory.zig", .{ .text_charsets = .all });
    _ = b.addExecutable("mode3draw", "examples/mode3draw/mode3draw.zig", .{});
    _ = b.addExecutable("mode4draw", "examples/mode4draw/mode4draw.zig", .{});
    _ = b.addExecutable("objAffine", "examples/objAffine/objAffine.zig", .{});
    _ = b.addExecutable("objDemo", "examples/objDemo/objDemo.zig", .{});
    _ = b.addExecutable("secondsTimer", "examples/secondsTimer/secondsTimer.zig", .{});
    _ = b.addExecutable("screenBlock", "examples/screenBlock/screenBlock.zig", .{});
    _ = b.addExecutable("tileDemo", "examples/tileDemo/tileDemo.zig", .{});
    
    const bgAffine = b.addExecutable("bgAffine", "examples/bgAffine/bgAffine.zig", .{ .text_charsets = .all });
    const bgAffine_tiles = b.addConvertImageTilesStep(.{
        .image_path = "examples/bgAffine/tiles.png",
        .output_path = "examples/bgAffine/tiles.bin",
        .options = .{
            .allocator = std.heap.page_allocator,
            .bpp = .bpp_8, // Affine backgrounds require 8bpp tile data
            .palettizer = gba.palettizer.PalettizerNearest.init(&[_]gba.image.ColorRgba32 {
                .transparent,
                .white,
                .red,
                .green,
                .aqua,
            }).pal(),
        },
    });
    bgAffine.dependOn(&bgAffine_tiles.step);
    
    var jesuMusic_palette = [_]gba.tiles.ColorRgb24 {
        .{ .r = 0, .g = 0, .b = 0 }, // Transparency
        .{ .r = 255, .g = 255, .b = 255 },
        .{ .r = 0, .g = 0, .b = 0 },
    };
    _ = b.addExecutable("jesuMusic", "examples/jesuMusic/jesuMusic.zig", .{});
    gba.tiles.convertSaveImagePath(
        []gba.tiles.ColorRgb24,
        "examples/jesuMusic/charset.png",
        "examples/jesuMusic/charset.bin",
        .{
            .allocator = std.heap.page_allocator,
            .bpp = .bpp_4,
            .palette_fn = gba.tiles.getNearestPaletteColor,
            .palette_ctx = jesuMusic_palette[0..],
        },
    ) catch {};

    const mode4flip = b.addExecutable("mode4flip", "examples/mode4flip/mode4flip.zig", .{});
    gba.mode4.convertMode4Images(mode4flip, &[_]gba.mode4.ImageSourceTarget{
        .{
            .source = "examples/mode4flip/front.bmp",
            .target = "examples/mode4flip/front.agi",
        },
        .{
            .source = "examples/mode4flip/back.bmp",
            .target = "examples/mode4flip/back.agi",
        },
    }, "examples/mode4flip/mode4flip.agp");
    
    // Tests
    
    const test_fixed = std_b.addRunArtifact(std_b.addTest(.{
        .root_source_file = std_b.path("src/gba/fixed.zig"),
    }));
    const test_format = std_b.addRunArtifact(std_b.addTest(.{
        .root_source_file = std_b.path("src/gba/format.zig"),
    }));

    const test_step = std_b.step("test", "Run unit tests");
    test_step.dependOn(&test_fixed.step);
    test_step.dependOn(&test_format.step);
}
