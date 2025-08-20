//! Module for operations related to Object/Sprite memory.

const gba = @import("gba.zig");

/// Refers to object attributes data in OAM.
/// Affine transformation matrices are interleaved with object attributes.
/// Should only be updated during VBlank, to avoid graphical glitches.
pub const objects: *align(8) volatile [128]Obj = @ptrFromInt(gba.mem.oam);

/// Set all objects to hidden.
///
/// You likely want to do this upon initialization, if you're enabling objects.
/// Otherwise, all 128 objects in OAM are initialized as visible 8x8 objects
/// in the top-left corner using tile index 0.
pub fn hideAllObjects() void {
    for(objects) |*obj| {
        obj.mode = .hidden;
    }
}

/// Refers to affine transformation matrix components in OAM.
/// You probably want to use `gba.obj.setOamTransform` or
/// `gba.bios.objAffineSetOam` rather than accessing this directly, since
/// affine transformation matrices are interleaved with object attributes.
/// Should only be updated during VBlank, to avoid graphical glitches.
///
/// Values start at index 3, and only every 4th value after that is really
/// an affine value. Other values belong to object attributes.
pub const affine_values: [*]gba.math.FixedI16R8 = @ptrFromInt(gba.mem.oam);

/// Represents an affine transformation matrix.
pub const AffineTransform = extern struct {
    // TODO: Replace with gba.math.Mat2x2FixedI16R8
    
    /// Identity matrix. Applies no rotation, scaling, or shearing.
    pub const Identity: AffineTransform = (
        .init(gba.math.FixedI16R8.fromInt(1), .{}, .{}, gba.math.FixedI16R8.fromInt(1))
    );
    
    /// Affine transformation matrix components, in row-major order.
    values: [4]gba.math.FixedI16R8 = @splat(.{}),
    
    /// Initialize an `AffineTransform` matrix with the given components.
    pub fn init(
        a: gba.math.FixedI16R8,
        b: gba.math.FixedI16R8,
        c: gba.math.FixedI16R8,
        d: gba.math.FixedI16R8,
    ) AffineTransform {
        return AffineTransform{ .values = .{ a, b, c, d } };
    }
    
    /// Multiply one transformation matrix by another, and return the product.
    /// The new matrix produces the same transform as applying one transform
    /// and then the other.
    pub fn mul(a: AffineTransform, b: AffineTransform) AffineTransform {
        return .init(
            a.values[0].mul(b.values[0]).add(a.values[1].mul(b.values[2])),
            a.values[0].mul(b.values[1]).add(a.values[1].mul(b.values[3])),
            a.values[2].mul(b.values[0]).add(a.values[3].mul(b.values[1])),
            a.values[2].mul(b.values[1]).add(a.values[3].mul(b.values[3])),
        );
    }
    
    /// Return a transformation matrix that will scale an object by the
    /// given amount on each axis.
    pub fn scale(
        x: gba.math.FixedI16R8,
        y: gba.math.FixedI16R8,
    ) AffineTransform {
        return .init(x, .{}, .{}, y);
    }
    
    /// Return a rotation matrix that will scale an object by the
    /// given amount on each axis.
    /// Uses `gba.math.FixedU16R16.sin` and `gba.math.FixedU16R16.cos`.
    /// See also `gba.bios.objAffineSet`.
    pub fn rotate(angle: gba.math.FixedU16R16) AffineTransform {
        const sin_theta = angle.sin().toI16R8();
        const cos_theta = angle.cos().toI16R8();
        return .init(cos_theta, sin_theta, sin_theta.negate(), cos_theta);
    }
    
    /// Return a rotation matrix that will scale an object by the
    /// given amount on each axis.
    /// Uses `gba.math.FixedU16R16.sinLerp` and `gba.math.FixedU16R16.cosLerp`.
    /// See also `gba.bios.objAffineSet`.
    pub fn rotateLerp(angle: gba.math.FixedU16R16) AffineTransform {
        const sin_theta = angle.sinLerp().toI16R8();
        const cos_theta = angle.cosLerp().toI16R8();
        return .init(cos_theta, sin_theta, sin_theta.negate(), cos_theta);
    }
};

pub const Obj = packed struct(u48) {
    pub const Effect = enum(u2) {
        normal,
        alpha_blend,
        obj_window,
    };

    pub const Shape = enum(u2) {
        square,
        wide,
        tall,
    };

    /// Enumeration of recognized sizes for objects.
    /// Sizes are represented here as WIDTHxHEIGHT in pixels.
    pub const Size = enum(u4) {
        // Square
        @"8x8",
        @"16x16",
        @"32x32",
        @"64x64",
        // Wide
        @"16x8",
        @"32x8",
        @"32x16",
        @"64x32",
        // Tall
        @"8x16",
        @"8x32",
        @"16x32",
        @"32x64",

        const Parts = packed struct(u4) {
            size: u2,
            shape: Shape,
        };

        fn parts(self: Size) Parts {
            return @bitCast(@intFromEnum(self));
        }
    };

    const Mode = enum(u2) {
        /// Normal rendering, uses `normal` transform controls
        normal,
        /// Uses `affine` transform controls
        affine,
        /// Disables rendering
        hidden,
        /// Uses `affine` transform controls, and also allows affine
        /// transformations to use twice the sprite's dimensions.
        affine_double,
    };

    /// Used to set transformation effects on an object.
    const Transform = packed union {
        /// Sprite flipping flags. Applies to normal (not affine) objects.
        flip: packed struct(u5) {
            /// Unused bits.
            _: u3 = 0,
            /// Flip the sprite horizontally, when set.
            h: bool = false,
            /// Flip the sprite vertically, when set.
            v: bool = false,
        },
        /// Affine transformation index. Applies to affine object.
        affine_index: u5,
    };

    /// Many docs treat this as a single 10 bit number, but the most significant bit
    /// corresponds to which of the last two charblocks the index is into.
    ///
    /// It can still be assigned to with a u10 via `@bitCast`
    pub const TileInfo = packed struct(u10) {
        /// The index into tile memory in VRAM. Indexing is always based on 4bpp tiles
        ///
        /// (for 8bpp tiles, only even indices are used, so `logical_index << 1` works)
        index: u9 = 0,
        /// Selects between the low and high block of obj VRAM
        ///
        /// In bitmap modes, this must be 1, since the lower block is occupied by the bitmap.
        block: u1 = 0,
    };
    // TODO: just make it a u10

    /// Represents the Y position of the object on the screen.
    /// For normal sprites, marks the top.
    /// For affine sprites, marks the center
    y_pos: u8 = 0,
    /// Determines whether to display the sprite normally, hide it, use an
    /// affine transform, or use a double-size affine transform.
    mode: Mode = .normal,
    /// Enables special rendering effects.
    effect: Effect = .normal,
    /// Enables mosaic effects on this object.
    mosaic: bool = false,
    /// Whether to use a 16-color or 256-color palette for this object.
    /// When using 4-bit color, the `Obj.palette` value indicates the
    /// which 16-color palette to use.
    bpp: gba.display.TileBpp = .bpp_4,
    /// Used in combination with size. See `Obj.setSize`.
    shape: Shape = .square,
    /// For normal sprites, the left side; for affine sprites, the center
    x_pos: u9 = 0,
    /// For normal sprites:
    /// Contains bits indicating whether to flip horizontally and/or vertically.
    ///
    /// For affine sprites:
    /// Contains a 5-bit index indicating which affine transformation matrix
    /// should be used for this object.
    transform: Transform = .{ .flip = .{} },
    /// Used in combination with shape. See `Obj.setSize`.
    size: u2 = 0,
    /// Base tile index of sprite.
    /// In bitmap modes, this must be 512 or higher.
    tile: TileInfo = .{},
    /// Higher priorities are drawn first, and therefore are covered up
    /// by later sprites and backgrounds.
    /// Sprites cover backgrounds of the same priority.
    /// For sprites of the same priority, the higher-numbered objects are
    /// drawn first.
    priority: gba.display.Priority = .highest,
    /// When the object is using 4-bit color, this value indicates which
    /// 16-color sprite palette bank should be used.
    /// Otherwise, for 8-bit color, this value is ignored.
    palette: u4 = 0,

    /// Sets size and shape to the appropriate values for the given object size.
    pub fn setSize(self: *Obj, size: Size) void {
        const parts = size.parts();
        self.size = parts.size;
        self.shape = parts.shape;
    }

    /// Assign the X and Y position of the object.
    pub inline fn setPosition(self: *Obj, x: u9, y: u8) void {
        self.x_pos = x;
        self.y_pos = y;
    }
};

/// Write an affine transformation matrix to OAM, for use with objects.
/// Should only be updated during VBlank, to avoid graphical glitches.
pub fn setOamTransform(index: u5, transform: AffineTransform) void {
    var value_index = 3 + (@as(u8, index) << 4);
    affine_values[value_index] = transform.values[0];
    value_index += 4;
    affine_values[value_index] = transform.values[1];
    value_index += 4;
    affine_values[value_index] = transform.values[2];
    value_index += 4;
    affine_values[value_index] = transform.values[3];
}
