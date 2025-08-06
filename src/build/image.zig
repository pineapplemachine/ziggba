//! This file contains helpers for dealing with images, e.g. via the zigimg
//! package.

const zigimg = @import("zigimg/zigimg.zig");

/// Helper to get RGBA8888 color from an image.
pub fn getImagePixelRgba32(image: zigimg.Image, index: usize) zigimg.color.Rgba32 {
    return switch (image.pixels) {
        .invalid => .{ .r = 0, .g = 0, .b = 0 },
        .indexed1 => |px| px.palette[px.indices[index]],
        .indexed2 => |px| px.palette[px.indices[index]],
        .indexed4 => |px| px.palette[px.indices[index]],
        .indexed8 => |px| px.palette[px.indices[index]],
        .indexed16 => |px| px.palette[px.indices[index]],
        .grayscale1 => |px| {
            const i: u8 = if (px[index].value == 0) 0 else 0xff;
            return .{ .r = i, .g = i, .b = i };
        },
        .grayscale2 => |px| {
            const i_table = [4]u8{ 0x00, 0x55, 0xaa, 0xff };
            const i = i_table[px[index].value];
            return .{ .r = i, .g = i, .b = i };
        },
        .grayscale4 => |px| {
            const i = (@as(u8, px[index].value) << 4) | px[index].value;
            return .{ .r = i, .g = i, .b = i };
        },
        .grayscale8 => |px| {
            const i = px[index].value;
            return .{ .r = i, .g = i, .b = i };
        },
        .grayscale8Alpha => |px| {
            const i = px[index].value;
            return .{ .r = i, .g = i, .b = i, .a = px[index].alpha };
        },
        .grayscale16 => |px| {
            const i: u8 = @truncate(px[index].value);
            return .{ .r = i, .g = i, .b = i };
        },
        .grayscale16Alpha => |px| {
            const i: u8 = @truncate(px[index].value);
            const a: u8 = @truncate(px[index].alpha);
            return .{ .r = i, .g = i, .b = i, .a = a };
        },
        .rgb24 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .rgba32 => |px| px[index],
        .rgb332 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .rgb565 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .rgb555 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .bgr555 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .bgr24 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
        },
        .bgra32 => |px| .{
            .r = px[index].r,
            .g = px[index].g,
            .b = px[index].b,
            .a = px[index].a,
        },
        .rgb48 => |px| .{
            .r = @truncate(px[index].r),
            .g = @truncate(px[index].g),
            .b = @truncate(px[index].b),
        },
        .rgba64 => |px| .{
            .r = @truncate(px[index].r),
            .g = @truncate(px[index].g),
            .b = @truncate(px[index].b),
            .a = @truncate(px[index].a),
        },
        .float32 => |px| .{
            .r = @intFromFloat(@round(px[index].r)),
            .g = @intFromFloat(@round(px[index].g)),
            .b = @intFromFloat(@round(px[index].b)),
            .a = @intFromFloat(@round(px[index].a)),
        },
    };
}
