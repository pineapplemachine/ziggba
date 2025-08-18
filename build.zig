const std = @import("std");

pub const gba = @import("src/build/build.zig");

/// Build example ROMs.
pub fn build(std_b: *std.Build) void {
    const b = gba.GbaBuild.create(std_b);
    
    // TODO: Use tile and palette data created by the build system for demos
    
    // Build font data
    
    const font_step = std_b.step("font", "Build fonts for gba.text");
    font_step.dependOn(&b.addBuildFontsStep().step);
    
    // Examples
    
    _ = b.addExecutable(.{
        .name = "charBlock",
        .root_source_file = b.path("examples/charBlock/charBlock.zig"),
    });
    _ = b.addExecutable(.{
        .name = "debugPrint",
        .root_source_file = b.path("examples/debugPrint/debugPrint.zig"),
    });
    _ = b.addExecutable(.{
        .name = "first",
        .root_source_file = b.path("examples/first/first.zig"),
    });
    _ = b.addExecutable(.{
        .name = "helloWorld",
        .root_source_file = b.path("examples/helloWorld/helloWorld.zig"),
        .build_options = .{ .text_charsets = .all },
    });
    _ = b.addExecutable(.{
        .name = "interrupts",
        .root_source_file = b.path("examples/interrupts/interrupts.zig"),
        .build_options = .{ .text_charsets = .all },
    });
    _ = b.addExecutable(.{
        .name = "keydemo",
        .root_source_file = b.path("examples/keydemo/keydemo.zig"),
    });
    _ = b.addExecutable(.{
        .name = "memory",
        .root_source_file = b.path("examples/memory/memory.zig"),
        .build_options = .{ .text_charsets = .all },
    });
    _ = b.addExecutable(.{
        .name = "mode3draw",
        .root_source_file = b.path("examples/mode3draw/mode3draw.zig"),
    });
    _ = b.addExecutable(.{
        .name = "mode4draw",
        .root_source_file = b.path("examples/mode4draw/mode4draw.zig"),
    });
    _ = b.addExecutable(.{
        .name = "objAffine",
        .root_source_file = b.path("examples/objAffine/objAffine.zig"),
    });
    _ = b.addExecutable(.{
        .name = "objDemo",
        .root_source_file = b.path("examples/objDemo/objDemo.zig"),
    });
    _ = b.addExecutable(.{
        .name = "secondsTimer",
        .root_source_file = b.path("examples/secondsTimer/secondsTimer.zig"),
    });
    _ = b.addExecutable(.{
        .name = "screenBlock",
        .root_source_file = b.path("examples/screenBlock/screenBlock.zig"),
    });
    _ = b.addExecutable(.{
        .name = "tileDemo",
        .root_source_file = b.path("examples/tileDemo/tileDemo.zig"),
    });
    
    
    var bgAffine = b.addExecutable(.{
        .name = "bgAffine",
        .root_source_file = b.path("examples/bgAffine/bgAffine.zig"),
        .build_options = .{ .text_charsets = .all },
    });
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
    
    var jesuMusic = b.addExecutable(.{
        .name = "jesuMusic",
        .root_source_file = b.path("examples/jesuMusic/jesuMusic.zig"),
    });
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

    var mode4flip = b.addExecutable(.{
        .name = "mode4flip",
        .root_source_file = b.path("examples/mode4flip/mode4flip.zig"),
    });
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
