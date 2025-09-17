const gba = @import("gba.zig");

/// Memory used by two surface buffers in graphics modes 4 and 5.
pub const bitmap_buffers: [2]*volatile [0x5000]u16 = .{
    gba.mem.vram[0..0x5000],
    gba.mem.vram[0x5000..0xa000],
};

/// Width of the mode 3 surface, in pixels.
pub const mode3_width = 240;

/// Height of the mode 3 surface, in pixels.
pub const mode3_height = 160;

/// Size of the mode 3 surface in pixels, represented as a vector.
pub const mode3_size: gba.math.Vec2U8 = (
    .init(mode3_width, mode3_height)
);

/// Width of a mode 4 surface, in pixels.
pub const mode4_width = 240;

/// Height of a mode 4 surface, in pixels.
pub const mode4_height = 160;

/// Size of a mode 4 surface in pixels, represented as a vector.
pub const mode4_size: gba.math.Vec2U8 = (
    .init(mode4_width, mode4_height)
);

/// Width of a mode 5 surface, in pixels.
pub const mode5_width = 160;

/// Height of a mode 5 surface, in pixels.
pub const mode5_height = 128;

/// Size of a mode 5 surface in pixels, represented as a vector.
pub const mode5_size: gba.math.Vec2U8 = (
    .init(mode3_width, mode5_height)
);

/// Helper for representing a pair of front and back buffers, as used by
/// graphics modes 4 and 5.
pub fn SurfacePair(comptime SurfaceT: type) type {
    return struct {
        const Self = @This();
        
        /// Refers to the two surface buffers available for a given
        /// graphics mode.
        buffers: [2]SurfaceT,
        /// Indicate which buffer is currently acting as the back buffer,
        /// i.e. the one which is not currently being displayed.
        back: u1 = 0,
        
        pub fn init(back: u1, buffers: [2]SurfaceT) Self {
            return .{ .buffers = buffers, .back = back };
        }
        
        /// Flip the front and back buffers.
        /// Modifies `gba.display.ctrl.surface_select`.
        /// (This corresponds to REG_DISPCNT.)
        /// See `gba.display.Control`.
        pub fn flip(self: *Self) void {
            gba.display.ctrl.surface_select = self.back;
            self.back = ~self.back;
        }
        
        /// Get the surface currently being used as the front buffer.
        /// When the corresponding graphics mode is active, this is the buffer
        /// which is currently being displayed on the screen.
        pub fn getFront(self: Self) SurfaceT {
            return self.buffers[~self.back];
        }
        
        /// Get the surface currently being used as the back buffer.
        pub fn getBack(self: Self) SurfaceT {
            return self.buffers[self.back];
        }
    };
}

/// Parameterized `Surface` type corresponding to the VRAM layout used for
/// graphics mode 3, which uses a single 16bpp buffer.
/// These buffers are sometimes also called "pages" or "frames".
pub const Mode3Surface = gba.image.Surface16Bpp;

/// Parameterized `Surface` type corresponding to the VRAM layout used for
/// graphics mode 4, which uses two 8bpp (256-color) buffers.
pub const Mode4Surface = gba.image.Surface8BppVram;

/// Parameterized `Surface` type corresponding to the VRAM layout used for
/// graphics mode 5, which uses two 16bpp buffers.
/// These buffers are sometimes also called "pages" or "frames".
pub const Mode5Surface = gba.image.Surface16Bpp;

/// Get a helper for accessing bitmap data in graphics mode 3.
pub fn getMode3Surface() Mode3Surface {
    return .init(
        mode3_width,
        mode3_height,
        @ptrCast(gba.mem.vram),
    );
}

/// Get a helper for accessing bitmap data in graphics mode 4.
pub fn getMode4Surface(buffer: u1) Mode4Surface {
    return .init(
        mode4_width,
        mode4_height,
        @ptrCast(bitmap_buffers[buffer]),
    );
}

/// Get a helper for accessing bitmap data in graphics mode 5.
pub fn getMode5Surface(buffer: u1) Mode5Surface {
    return .init(
        mode5_width,
        mode5_height,
        @ptrCast(bitmap_buffers[buffer]),
    );
}

/// Get a helper for accessing bitmap data in graphics mode 4.
/// Which of the two available surfaces the system should currently display on
/// the screen is decided by `gba.display.ctrl.surface_select`.
pub fn getMode4Surfaces() SurfacePair(Mode4Surface) {
    return .init(1, .{
        .init(
            mode4_width,
            mode4_height,
            @ptrCast(bitmap_buffers[0]),
        ),
        .init(
            mode4_width,
            mode4_height,
            @ptrCast(bitmap_buffers[1]),
        ),
    });
}

/// Get a helper for accessing bitmap data in graphics mode 5.
/// Which of the two available surfaces the system should currently display on
/// the screen is decided by `gba.display.ctrl.surface_select`.
pub fn getMode5Surfaces() SurfacePair(Mode5Surface) {
    return .init(1, .{
        .init(
            mode5_width,
            mode5_height,
            @ptrCast(bitmap_buffers[0]),
        ),
        .init(
            mode5_width,
            mode5_height,
            @ptrCast(bitmap_buffers[1]),
        ),
    });
}
