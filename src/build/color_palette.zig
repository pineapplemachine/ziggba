const std = @import("std");

const ColorRgb555 = @import("../gba/color.zig").ColorRgb555;

/// Save palette data as a binary file at a given file path.
pub fn savePalette(
    palette: []const ColorRgb555,
    output_path: []const u8,
) !void {
    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(std.mem.sliceAsBytes(palette));
}

/// Save a palette as a build step.
pub const SavePaletteStep = struct {
    pub const Options = struct {
        name: ?[]const u8 = null,
        palette: []const ColorRgb555,
        output_path: []const u8,
    };
    
    step: std.Build.Step,
    palette: []const ColorRgb555,
    output_path: []const u8,
    
    pub fn create(b: *std.Build, options: Options) *SavePaletteStep {
        const step_name = options.name orelse b.fmt(
            "SavePaletteStep {s}",
            .{ options.output_path },
        );
        const save_step = (
            b.allocator.create(SavePaletteStep) catch @panic("OOM")
        );
        save_step.* = .{
            .palette = options.palette,
            .output_path = options.output_path,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .owner = b,
                .makeFn = make,
                .name = step_name,
            }),
        };
        return save_step;
    }
    
    fn make(
        step: *std.Build.Step,
        make_options: std.Build.Step.MakeOptions,
    ) !void {
        const self: *SavePaletteStep = @fieldParentPtr("step", step);
        const node_name = step.owner.fmt(
            "Saving palette: {s}",
            .{ self.output_path },
        );
        var node = make_options.progress_node.start(node_name, 1);
        defer node.end();
        try savePalette(self.palette, self.output_path);
    }
};
