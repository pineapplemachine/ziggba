//! This module provides helpers for building Zig code as a GBA ROM.

const std = @import("std");

pub const color = @import("color.zig");
pub const font = @import("font.zig");
pub const image = @import("image.zig");

pub const LoggerInterface = @import("../gba/debug.zig").LoggerInterface;
pub const CharsetFlags = font.CharsetFlags;

const gba_linker_script_path = "src/gba/gba.ld";
const gba_start_zig_file_path = "src/gba/start.zig";
const gba_lib_file_path = "src/gba/gba.zig";

const asm_file_paths = [_][]const u8{
    "src/gba/crt0.s",
    "src/gba/isr.s",
    "src/gba/math.s",
    "src/gba/mem.s",
};

pub const GbaBuild = struct {
    pub const CliOptions = struct {
        debug: bool = false,
        safe: bool = false,
        gdb: bool = false,
    };
    
    /// These build options control some aspects of how ZigGBA is compiled.
    pub const BuildOptions = struct {
        /// Choose default logger for use with `gba.debug.print` and
        /// `gba.debug.write`.
        default_logger: LoggerInterface = .mgba,
        /// Options relating to `gba.text`.
        /// Each charset flag, e.g. `charset_latin`, controls whether `gba.text`
        /// will embed font data for a certain subset of Unicode code points
        /// into the compiled ROM.
        text_charsets: CharsetFlags = .{},
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
    ziggba_dep: ?*std.Build.Dependency,
    thumb_target: std.Build.ResolvedTarget,
    optimize_mode: std.builtin.OptimizeMode,
    gdb: bool,
    
    pub fn create(b: *std.Build) *GbaBuild {
        const gba_b = b.allocator.create(GbaBuild) catch @panic("OOM");
        gba_b.* = GbaBuild.init(b);
        return gba_b;
    }
    
    pub fn init(b: *std.Build) GbaBuild {
        const cli_options = GbaBuild.getCliOptions(b);
        var ziggba_dep: ?*std.Build.Dependency = null;
        for(b.available_deps) |dep| {
            if(std.mem.eql(u8, dep[0], "ziggba")) {
                ziggba_dep = b.dependency("ziggba", .{});
                break;
            }
        }
        var optimize_mode: std.builtin.OptimizeMode = .ReleaseFast;
        if(cli_options.debug) {
            optimize_mode = .Debug;
        }
        else if(cli_options.safe) {
            optimize_mode = .ReleaseSafe;
        }
        return .{
            .b = b,
            .ziggba_dep = ziggba_dep,
            .thumb_target = b.resolveTargetQuery(GbaBuild.thumb_target_query),
            .optimize_mode = optimize_mode,
            .gdb = cli_options.gdb,
        };
    }
    
    /// Get the allocator belonging to the underling `std.Build` instance.
    pub fn allocator(self: GbaBuild) std.mem.Allocator {
        return self.b.allocator;
    }
    
    /// Get a path relative to the build directory.
    pub fn path(self: GbaBuild, sub_path: []const u8) std.Build.LazyPath {
        return self.b.path(sub_path);
    }
    
    /// Get a path relative to the ZigGBA build directory.
    pub fn ziggbaPath(self: GbaBuild, sub_path: []const u8) std.Build.LazyPath {
        if(self.ziggba_dep) |dep| {
            return .{
                .dependency = .{
                    .dependency = dep,
                    .sub_path = sub_path,
                },
            };
        }
        else {
            return self.b.path(sub_path);
        }
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
            .safe = blk: {
                break :blk b.option(
                    bool,
                    "safe",
                    "Build the GBA ROM in ReleaseSafe mode instead of ReleaseFast.",
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
        b_options.addOption(LoggerInterface, "default_logger", build_options.default_logger);
        b_options.addOption(CharsetFlags, "text_charsets", build_options.text_charsets);
        return b_options;
    }
    
    /// Add font-related imports to a module.
    /// These files contain glyph data bitmaps used by `gba.text`.
    pub fn addFontImports(
        self: GbaBuild,
        module: *std.Build.Module,
        build_options: BuildOptions,
    ) void {
        inline for(font.charsets) |charset| {
            if(@field(build_options.text_charsets, charset.name)) {
                const png_path = comptime(
                    "assets/font_" ++ charset.name ++ ".bin"
                );
                module.addAnonymousImport(
                    "ziggba_font_" ++ charset.name ++ ".bin",
                    .{ .root_source_file = self.ziggbaPath(png_path) },
                );
            }
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
        root_source_file: std.Build.LazyPath,
        build_options: BuildOptions,
    ) *std.Build.Module {
        const module = self.b.addModule(name, .{
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = root_source_file,
        });
        self.addFontImports(module, build_options);
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
        lib.setLinkerScript(self.ziggbaPath(gba_linker_script_path));
        self.addFontImports(lib.root_module, build_options);
        self.addBuildOptions(lib.root_module, build_options);
        return lib;
    }
    
    pub fn addObject(
        self: GbaBuild,
        object_name: []const u8,
        root_source_file: std.Build.LazyPath,
        build_options: BuildOptions,
    ) *std.Build.Step.Compile {
        const object = self.b.addObject(.{
            .name = object_name,
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = root_source_file,
        });
        self.addFontImports(object.root_module, build_options);
        self.addBuildOptions(object.root_module, build_options);
        return object;
    }
    
    pub const ExecutableOptions = struct {
        name: []const u8,
        root_source_file: std.Build.LazyPath,
        build_options: BuildOptions = .{},
    };
    
    /// Add a build step to compile an executable, i.e. a GBA ROM.
    pub fn addExecutable(
        self: *GbaBuild,
        options: ExecutableOptions,
    ) *GbaExecutable {
        const exe_module = self.b.createModule(.{
            .target = self.thumb_target,
            .optimize = self.optimize_mode,
            .root_source_file = options.root_source_file,
        });
        const exe = self.b.addExecutable(.{
            .name = options.name,
            .root_module = exe_module,
        });
        self.addFontImports(exe_module, options.build_options);
        self.addBuildOptions(exe_module, options.build_options);
        self.b.default_step.dependOn(&exe.step);
        // Zig entry point and startup routine
        exe.addObject(self.addObject(
            "gba_start",
            self.ziggbaPath(gba_start_zig_file_path),
            options.build_options,
        ));
        // ZigGBA as a static library
        const gba_module = self.addModule(
            "gba",
            self.ziggbaPath(gba_lib_file_path),
            options.build_options,
        );
        exe.linkLibrary(self.addStaticLibrary(
            "ziggba",
            gba_module,
            options.build_options,
        ));
        exe_module.addImport("gba", gba_module);
        // Linker script
        exe.setLinkerScript(self.ziggbaPath(gba_linker_script_path));
        // Assembly modules
        for(asm_file_paths) |asm_path| {
            exe.addAssemblyFile(self.ziggbaPath(asm_path));
        }
        // Generate GBA ROM
        const objcopy_step = exe.addObjCopy(.{
            .format = .bin,
        });
        const install_bin_step = self.b.addInstallBinFile(
            objcopy_step.getOutput(),
            self.b.fmt("{s}.gba", .{ options.name }),
        );
        install_bin_step.step.dependOn(&objcopy_step.step);
        self.b.default_step.dependOn(&install_bin_step.step);
        // Optionally generate ELF file with debug symbols
        if (self.gdb) {
            const install_elf_step = self.b.addInstallArtifact(exe, .{
                // TODO: Why are ELF files still emitting with no extension?
                .dest_sub_path = self.b.fmt("{s}.elf", .{ options.name }),
            });
            self.b.getInstallStep().dependOn(&install_elf_step.step);
        }
        // Fin
        return .create(self, exe);
    }
    
    /// Add a build step for building font data for `gba.text`, converting
    /// PNG images to bitmap data in a compact binary format.
    pub fn addBuildFontsStep(
        self: *GbaBuild,
    ) *font.BuildFontsStep {
        return font.BuildFontsStep.create(self);
    }
    
    pub fn addConvertImageTiles4BppStep(
        self: GbaBuild,
        options: image.ConvertImageTiles4BppStep.Options,
    ) *image.ConvertImageTiles4BppStep {
        return image.ConvertImageTiles4BppStep.create(self.b, options);
    }
    
    pub fn addConvertImageTiles8BppStep(
        self: GbaBuild,
        options: image.ConvertImageTiles8BppStep.Options,
    ) *image.ConvertImageTiles8BppStep {
        return image.ConvertImageTiles8BppStep.create(self.b, options);
    }
    
    pub fn addConvertImageBitmap8BppStep(
        self: GbaBuild,
        options: image.ConvertImageBitmap8BppStep.Options,
    ) *image.ConvertImageBitmap8BppStep {
        return image.ConvertImageBitmap8BppStep.create(self.b, options);
    }
    
    pub fn addConvertImageBitmap16BppStep(
        self: GbaBuild,
        options: image.ConvertImageBitmap16BppStep.Options,
    ) *image.ConvertImageBitmap16BppStep {
        return image.ConvertImageBitmap16BppStep.create(self.b, options);
    }
    
    pub fn addSavePaletteStep(
        self: GbaBuild,
        options: color.SavePaletteStep.Options,
    ) *color.SavePaletteStep {
        return color.SavePaletteStep.create(self.b, options);
    }
    
    pub fn addSaveQuantizedPalettizerPaletteStep(
        self: GbaBuild,
        options: color.SaveQuantizedPalettizerPaletteStep.Options,
    ) *color.SaveQuantizedPalettizerPaletteStep {
        return color.SaveQuantizedPalettizerPaletteStep.create(self.b, options);
    }
};

pub const GbaExecutable = struct {
    b: *GbaBuild,
    step: *std.Build.Step.Compile,
    
    pub fn init(b: *GbaBuild, step: *std.Build.Step.Compile) GbaExecutable {
        return .{ .b = b, .step = step };
    }
    
    pub fn create(b: *GbaBuild, step: *std.Build.Step.Compile) *GbaExecutable {
        const exe = b.allocator().create(GbaExecutable) catch @panic("OOM");
        exe.* = .init(b, step);
        return exe;
    }
    
    pub fn getOwner(self: GbaExecutable) *std.Build {
        return self.step.step.owner;
    }
    
    pub fn dependOn(self: *GbaExecutable, step: *std.Build.Step) void {
        self.step.step.dependOn(step);
    }
    
    /// Add a step that the executable depends on.
    pub fn addBuildFontsStep(
        self: *GbaExecutable,
    ) *font.BuildFontsStep {
        const step = font.BuildFontsStep.create(self.b);
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addConvertImageTiles4BppStep(
        self: *GbaExecutable,
        options: image.ConvertImageTiles4BppStep.Options,
    ) *image.ConvertImageTiles4BppStep {
        const step = image.ConvertImageTiles4BppStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addConvertImageTiles8BppStep(
        self: *GbaExecutable,
        options: image.ConvertImageTiles8BppStep.Options,
    ) *image.ConvertImageTiles8BppStep {
        const step = image.ConvertImageTiles8BppStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addConvertImageBitmap8BppStep(
        self: *GbaExecutable,
        options: image.ConvertImageBitmap8BppStep.Options,
    ) *image.ConvertImageBitmap8BppStep {
        const step = image.ConvertImageBitmap8BppStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addConvertImageBitmap16BppStep(
        self: *GbaExecutable,
        options: image.ConvertImageBitmap16BppStep.Options,
    ) *image.ConvertImageBitmap16BppStep {
        const step = image.ConvertImageBitmap16BppStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addSavePaletteStep(
        self: *GbaExecutable,
        options: color.SavePaletteStep.Options,
    ) *color.SavePaletteStep {
        const step = color.SavePaletteStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
    
    /// Add a step that the executable depends on.
    pub fn addSaveQuantizedPalettizerPaletteStep(
        self: *GbaExecutable,
        options: color.SaveQuantizedPalettizerPaletteStep.Options,
    ) *color.SaveQuantizedPalettizerPaletteStep {
        const step = color.SaveQuantizedPalettizerPaletteStep.create(
            self.getOwner(),
            options,
        );
        self.dependOn(&step.step);
        return step;
    }
};
