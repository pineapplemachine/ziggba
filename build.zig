const std = @import("std");
const gba = @import("src/build/build.zig");

pub fn build(b: *std.Build) void {
    // TODO: Use tile and palette data created by the build system for demos
    
    // Options
    
    const text_options: gba.Options = .{
        .text_charset_latin = true,
        .text_charset_latin_supplement = true,
        .text_charset_greek = true,
        .text_charset_cyrillic = true,
        .text_charset_arrows = true,
        .text_charset_kana = true,
        .text_charset_fullwidth_punctuation = true,
        .text_charset_fullwidth_latin = true,
        .text_charset_cjk_symbols = true,
    };
    
    // Build font data
    
    const build_font_step = b.step("font", "Build font data for gba.text");
    build_font_step.makeFn = gba.buildFontsStep;
    
    // Examples
    
    _ = gba.addGBAExecutable(b, "charBlock", "examples/charBlock/charBlock.zig", .{});
    _ = gba.addGBAExecutable(b, "debugPrint", "examples/debugPrint/debugPrint.zig", .{});
    _ = gba.addGBAExecutable(b, "first", "examples/first/first.zig", .{});
    _ = gba.addGBAExecutable(b, "helloWorld", "examples/helloWorld/helloWorld.zig", text_options);
    _ = gba.addGBAExecutable(b, "interrupts", "examples/interrupts/interrupts.zig", text_options);
    _ = gba.addGBAExecutable(b, "keydemo", "examples/keydemo/keydemo.zig", .{});
    _ = gba.addGBAExecutable(b, "mode3draw", "examples/mode3draw/mode3draw.zig", .{});
    _ = gba.addGBAExecutable(b, "mode4draw", "examples/mode4draw/mode4draw.zig", .{});
    _ = gba.addGBAExecutable(b, "objAffine", "examples/objAffine/objAffine.zig", .{});
    _ = gba.addGBAExecutable(b, "objDemo", "examples/objDemo/objDemo.zig", .{});
    _ = gba.addGBAExecutable(b, "secondsTimer", "examples/secondsTimer/secondsTimer.zig", .{});
    _ = gba.addGBAExecutable(b, "screenBlock", "examples/screenBlock/screenBlock.zig", .{});
    _ = gba.addGBAExecutable(b, "tileDemo", "examples/tileDemo/tileDemo.zig", .{});
    
    var bgAffine_palette = [_]gba.tiles.ColorRgb24 {
        .{ .r = 0, .g = 0, .b = 0 }, // Transparency
        .{ .r = 255, .g = 255, .b = 255 },
        .{ .r = 255, .g = 0, .b = 0 },
        .{ .r = 0, .g = 255, .b = 0 },
        .{ .r = 0, .g = 128, .b = 255 },
    };
    _ = gba.addGBAExecutable(b, "bgAffine", "examples/bgAffine/bgAffine.zig", text_options);
    gba.tiles.convertSaveImagePath(
        []gba.tiles.ColorRgb24,
        "examples/bgAffine/tiles.png",
        "examples/bgAffine/tiles.bin",
        .{
            .allocator = std.heap.page_allocator,
            .bpp = .bpp_8, // Affine backgrounds require 8bpp tile data
            .palette_fn = gba.tiles.getNearestPaletteColor,
            .palette_ctx = bgAffine_palette[0..],
        },
    ) catch {};
    
    var jesuMusic_palette = [_]gba.tiles.ColorRgb24 {
        .{ .r = 0, .g = 0, .b = 0 }, // Transparency
        .{ .r = 255, .g = 255, .b = 255 },
        .{ .r = 0, .g = 0, .b = 0 },
    };
    _ = gba.addGBAExecutable(b, "jesuMusic", "examples/jesuMusic/jesuMusic.zig", .{});
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

    const mode4flip = gba.addGBAExecutable(b, "mode4flip", "examples/mode4flip/mode4flip.zig", .{});
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
    
    // Tests
    
    const test_fixed = b.addRunArtifact(b.addTest(.{
        .root_source_file = b.path("src/gba/fixed.zig"),
    }));
    const test_format = b.addRunArtifact(b.addTest(.{
        .root_source_file = b.path("src/gba/format.zig"),
    }));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_fixed.step);
    test_step.dependOn(&test_format.step);
}
