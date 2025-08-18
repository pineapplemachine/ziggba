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
    
    var bgAffine = b.addExecutable("bgAffine", "examples/bgAffine/bgAffine.zig", .{ .text_charsets = .all });
    const bgAffine_pal = gba.color.PalettizerNearest.create(
        b.allocator(),
        &[_]gba.color.ColorRgba32 {
            .transparent,
            .white,
            .red,
            .green,
            .aqua,
        },
    ) catch @panic("OOM");
    _ = bgAffine.addConvertImageTiles8BppStep(.{
        .image_path = "examples/bgAffine/tiles.png",
        .output_path = "examples/bgAffine/tiles.bin",
        .options = .{ .palettizer = bgAffine_pal.pal() },
    });
    
    var jesuMusic = b.addExecutable("jesuMusic", "examples/jesuMusic/jesuMusic.zig", .{});
    const jesuMusic_pal = gba.color.PalettizerNearest.create(
        b.allocator(),
        &[_]gba.color.ColorRgba32 {
            .transparent,
            .white,
            .black,
        },
    ) catch @panic("OOM");
    _ = jesuMusic.addConvertImageTiles4BppStep(.{
        .image_path = "examples/jesuMusic/charset.png",
        .output_path = "examples/jesuMusic/charset.bin",
        .options = .{ .palettizer = jesuMusic_pal.pal() },
    });

    var mode4flip = b.addExecutable("mode4flip", "examples/mode4flip/mode4flip.zig", .{});
    const mode4flip_pal = gba.color.PalettizerNaive.create(
        b.allocator(),
        256,
    ) catch @panic("OOM");
    _ = mode4flip.addConvertImageBitmap8BppStep(.{
        .image_path = "examples/mode4flip/front.bmp",
        .output_path = "examples/mode4flip/front.agi",
        .options = .{ .palettizer = mode4flip_pal.pal() },
    });
    _ = mode4flip.addConvertImageBitmap8BppStep(.{
        .image_path = "examples/mode4flip/back.bmp",
        .output_path = "examples/mode4flip/back.agi",
        .options = .{ .palettizer = mode4flip_pal.pal() },
    });
    _ = mode4flip.addSaveQuantizedPalettizerPaletteStep(.{
        .palettizer = mode4flip_pal.pal(),
        .output_path = "examples/mode4flip/mode4flip.agp",
    });
    
    // Tests
    
    const test_math = std_b.addRunArtifact(std_b.addTest(.{
        .root_source_file = std_b.path("src/gba/math.zig"),
    }));
    const test_format = std_b.addRunArtifact(std_b.addTest(.{
        .root_source_file = std_b.path("src/gba/format.zig"),
    }));

    const test_step = std_b.step("test", "Run unit tests");
    test_step.dependOn(&test_math.step);
    test_step.dependOn(&test_format.step);
}
