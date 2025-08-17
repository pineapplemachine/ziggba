//! This module provides helpers for building Zig code as a GBA ROM.

const std = @import("std");

pub const GbaColor = @import("../gba/color.zig").Color;
pub const font = @import("font.zig");
pub const image = @import("image.zig");
pub const mode4 = @import("mode4.zig");
pub const palettizer = @import("palettizer.zig");
pub const tiles = @import("tiles.zig");

fn libRootPath() []const u8 {
    const build_path = std.fs.path.dirname(@src().file) orelse ".";
    const src_path = std.fs.path.dirname(build_path) orelse ".";
    const root_path = std.fs.path.dirname(src_path) orelse ".";
    return root_path;
}

const lib_root_path = libRootPath();

const gba_linker_script_path = libRootPath() ++ "/src/gba/gba.ld";
const gba_start_zig_file_path = libRootPath() ++ "/src/gba/start.zig";
const gba_lib_file_path = libRootPath() ++ "/src/gba/gba.zig";

const asm_file_paths = [_][]const u8{
    libRootPath() ++ "/src/gba/crt0.s",
    libRootPath() ++ "/src/gba/isr.s",
    libRootPath() ++ "/src/gba/mem.s",
};

pub const GbaBuild = struct {
    pub const CliOptions = struct {
        debug: bool = false,
        gdb: bool = false,
    };
    
    /// These build options control some aspects of how ZigGBA is compiled.
    pub const BuildOptions = struct {
        /// Options relating to `gba.text`.
        /// Each charset flag, e.g. `charset_latin`, controls whether `gba.text`
        /// will embed font data for a certain subset of Unicode code points
        /// into the compiled ROM.
        text_charsets: font.CharsetFlags = .{},
    };
    
    /// `std.Target.Query` object for GBA thumb compilation target.
    pub const thumb_target_query = blk: {
        var target = std.Target.Query{
            .cpu_arch = std.Target.Cpu.Arch.thumb,
            .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm7tdmi },
            .os_tag = .freestanding,
        };
        target.cpu_features_add.addFeature(
            @intFromEnum(std.Target.arm.Feature.thumb_mode)
        );
        break :blk target;
    };
    
    b: *std.Build,
    thumb_target: std.Build.ResolvedTarget,
    optimize_mode: std.builtin.OptimizeMode,
    gdb: bool,
    
    pub fn init(b: *std.Build) GbaBuild {
        const cli_options = GbaBuild.getCliOptions(b);
        return .{
            .b = b,
            .thumb_target = b.resolveTargetQuery(GbaBuild.thumb_target_query),
            .optimize_mode = if(cli_options.debug) .Debug else .ReleaseFast,
            .gdb = cli_options.gdb,
        };
    }
    
    /// Get options passed via compiler arguments.
    /// - -Ddebug - Do a debug build, instead of an optimized release build.
    /// - -Dgdb - Output an ELF containing debug symbols.
    pub fn getCliOptions(b: *std.Build) CliOptions {
        return .{
            .debug = blk: {
                break :blk b.option(
                    bool,
                    "debug",
                    "Build the GBA ROM in debug mode instead of release mode.",
                ) orelse false;
            },
            .gdb = blk: {
                break :blk b.option(
                    bool,
                    "gdb",
                    "Generate an ELF file with debug symbols alongside the GBA ROM.",
                ) orelse false;
            },
        };
    }
    
    /// Get an `std.Build.Step.Options` object corresponding to some given
    /// `BuildOptions`.
    fn getBuildOptions(
        b: *std.Build,
        build_options: BuildOptions,
    ) *std.Build.Step.Options {
        const b_options = b.addOptions();
        inline for(font.charsets) |charset| {
            b_options.addOption(
                bool,
                "text_charset_" ++ charset.name,
                @field(build_options.text_charsets, charset.name),
            );
        }
        return b_options;
    }
    
    /// Add font-related imports to a module.
    /// These files contain glyph data bitmaps used by `gba.text`.
    pub fn addFontImports(self: GbaBuild, module: *std.Build.Module) void {
        inline for(font.charsets) |charset| {
            const png_path = comptime(
                libRootPath() ++ "/assets/font_" ++ charset.name ++ ".bin"
            );
            module.addAnonymousImport(
                "ziggba_font_" ++ charset.name ++ ".bin",
                .{ .root_source_file = self.b.path(png_path) },
            );
        }
    }
    
    /// Add `ziggba_build_options` import to a module.
    pub fn addBuildOptions(
        self: GbaBuild,
        module: *std.Build.Module,
        build_options: BuildOptions,
    ) void {
        const b_options = GbaBuild.getBuildOptions(self.b, build_options);
        module.addOptions("ziggba_build_options", b_options);
    }
    
    /// Add a build step to compile a module.
    pub fn addModule(
        self: GbaBuild,
        name: []const u8,
        source_file_path: []const u8,
        build_options: BuildOptions,
    ) *std.Build.Module {
        const module = self.b.addModule(name, .{
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = .{
                .src_path = .{
                    .owner = self.b,
                    .sub_path = source_file_path,
                },
            },
        });
        self.addFontImports(module);
        self.addBuildOptions(module, build_options);
        return module;
    }
    
    /// Add a build step to compile a static library.
    pub fn addStaticLibrary(
        self: GbaBuild,
        library_name: []const u8,
        root_module: *std.Build.Module,
        build_options: BuildOptions,
    ) *std.Build.Step.Compile {
        const lib = self.b.addLibrary(.{
            .linkage = .static,
            .name = library_name,
            .root_module = root_module,
        });
        lib.setLinkerScript(.{
            .src_path = .{
                .owner = self.b,
                .sub_path = gba_linker_script_path,
            },
        });
        self.addFontImports(lib.root_module);
        self.addBuildOptions(lib.root_module, build_options);
        return lib;
    }
    
    pub fn addObject(
        self: GbaBuild,
        object_name: []const u8,
        source_file_path: []const u8,
        build_options: BuildOptions,
    ) *std.Build.Step.Compile {
        const object = self.b.addObject(.{
            .name = object_name,
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = .{
                .src_path = .{
                    .owner = self.b,
                    .sub_path = source_file_path,
                },
            },
        });
        self.addFontImports(object.root_module);
        self.addBuildOptions(object.root_module, build_options);
        return object;
    }
    
    /// Add a build step to compile an executable, i.e. a GBA ROM.
    pub fn addExecutable(
        self: GbaBuild,
        rom_name: []const u8,
        source_file_path: []const u8,
        build_options: BuildOptions,
    ) *std.Build.Step.Compile {
        const exe = self.b.addExecutable(.{
            .name = rom_name,
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = .{
                .src_path = .{
                    .owner = self.b,
                    .sub_path = source_file_path,
                },
            },
        });
        self.addFontImports(exe.root_module);
        self.addBuildOptions(exe.root_module, build_options);
        self.b.default_step.dependOn(&exe.step);
        // Zig entry point and startup routine
        exe.addObject(self.addObject(
            "gba_start",
            gba_start_zig_file_path,
            build_options,
        ));
        // ZigGBA as a static library
        const gba_module = self.addModule(
            "gba",
            gba_lib_file_path,
            build_options,
        );
        exe.linkLibrary(self.addStaticLibrary(
            "ziggba",
            gba_module,
            build_options,
        ));
        exe.root_module.addImport("gba", gba_module);
        // Linker script
        exe.setLinkerScript(.{
            .src_path = .{
                .owner = self.b,
                .sub_path = gba_linker_script_path,
            },
        });
        // Assembly modules
        for(asm_file_paths) |asm_path| {
            exe.addAssemblyFile(.{
                .src_path = .{
                    .owner = self.b,
                    .sub_path = asm_path,
                },
            });
        }
        // Optionally generate ELF file with debug symbols
        if (self.gdb) {
            _ = self.b.addInstallArtifact(exe, .{
                .dest_sub_path = self.b.fmt("{s}.elf", .{rom_name}),
            });
        }
        // Generate GBA ROM
        const objcopy_step = exe.addObjCopy(.{
            .format = .bin,
        });
        const install_bin_step = self.b.addInstallBinFile(
            objcopy_step.getOutput(),
            self.b.fmt("{s}.gba", .{rom_name}),
        );
        install_bin_step.step.dependOn(&objcopy_step.step);
        self.b.default_step.dependOn(&install_bin_step.step);
        // Fin
        return exe;
    }
    
    pub const BuildFontsDiagnostic = struct {
        charset: font.Charset = .none,
    };
    
    /// Convert font image data from PNGs to an embeddable bitmap format
    /// recognized by `gba.text`.
    pub fn buildFonts(
        make_options: std.Build.Step.MakeOptions,
        diagnostic: ?*BuildFontsDiagnostic,
    ) !void {
        const root_node = make_options.progress_node.start(
            "Building font",
            font.charsets.len,
        );
        defer root_node.end();
        const alloc = std.heap.page_allocator;
        inline for(font.charsets) |charset| {
            const charset_node = make_options.progress_node.start(
                "Building font charset: " ++ charset.name,
                1,
            );
            defer charset_node.end();
            font.packSaveFontPath(
                lib_root_path ++ "/assets/font_" ++ charset.image_name ++ ".png",
                lib_root_path ++ "/assets/font_" ++ charset.name ++ ".bin",
                charset.grid_size,
                charset.image_rect,
                alloc
            ) catch |err| {
                if(diagnostic) |d| {
                    d.charset = charset;
                }
                return err;
            };
            root_node.completeOne();
        }
    }

    /// Wraps `buildFonts` in an interface compatible with
    /// `std.Build.Step.MakeFn`.
    pub fn buildFontsStep(
        b: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        var diagnostic: BuildFontsDiagnostic = .{};
        buildFonts(make_options, &diagnostic) catch |err| {
            try b.addError(
                "Failed to build font {s}: {any}.",
                .{ diagnostic.charset.name, err }
            );
        };
    }
    
    /// Add a build step for building font data for `gba.text`, converting
    /// PNG images to bitmap data in a compact binary format.
    pub fn addBuildFontsStep(self: GbaBuild, name: []const u8) *std.Build.Step {
        const step = self.b.step(name, "Build font data for gba.text");
        step.makeFn = GbaBuild.buildFontsStep;
        return step;
    }
    
    pub fn addConvertImageTilesStep(
        self: GbaBuild,
        options: tiles.ConvertImageTilesStep.InitOptions,
    ) tiles.ConvertImageTilesStep {
        return tiles.ConvertImageTilesStep.init(self.b, options);
    }
};
