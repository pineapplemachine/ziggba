const std = @import("std");
const ImageConverter = @import("image_converter.zig").ImageConverter;

pub const ImageSourceTarget = @import("image_converter.zig").ImageSourceTarget;

const Mode4ConvertStep = struct {
    step: std.Build.Step,
    images: []const ImageSourceTarget,
    target_palette_path: []const u8,

    pub fn init(
        b: *std.Build,
        images: []const ImageSourceTarget,
        target_palette_path: []const u8,
    ) Mode4ConvertStep {
        return Mode4ConvertStep{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("ConvertMode4Image {s}", .{target_palette_path}),
                .owner = b,
                .makeFn = make,
            }),
            .images = images,
            .target_palette_path = target_palette_path,
        };
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
        const self: *Mode4ConvertStep = @fieldParentPtr("step", step);
        const ImageSourceTargetList = std.ArrayList(ImageSourceTarget);

        var full_images = ImageSourceTargetList.init(step.owner.allocator);
        defer full_images.deinit();

        var node = options.progress_node.start("Converting mode4 images", 1);
        defer node.end();

        for (self.images) |image| {
            try full_images.append(ImageSourceTarget{
                .source = self.step.owner.pathFromRoot(image.source),
                .target = self.step.owner.pathFromRoot(image.target),
            });
        }

        const full_target_palette_path = self.step.owner.pathFromRoot(self.target_palette_path);
        try ImageConverter.convertMode4Image(self.step.owner.allocator, full_images.items, full_target_palette_path);
    }
};

pub fn convertMode4Images(compile_step: *std.Build.Step.Compile, images: []const ImageSourceTarget, target_palette_path: []const u8) void {
    const convert_image_step = compile_step.step.owner.allocator.create(Mode4ConvertStep) catch unreachable;
    convert_image_step.* = Mode4ConvertStep.init(compile_step.step.owner, images, target_palette_path);
    compile_step.step.dependOn(&convert_image_step.step);
}
