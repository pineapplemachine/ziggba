//! Module for operations related to Object/Sprite memory.

const gba = @import("gba.zig");

/// Refers to object attributes data in OAM.
/// Affine transformation matrices are interleaved with object attributes.
/// OAM should only be updated during VBlank, to avoid graphical glitches.
/// (See `gba.bios.vblankIntrWait`.)
pub const objects: *align(8) volatile [128]Object = @ptrCast(gba.mem.oam);

/// Set all objects to hidden.
/// You likely want to do this upon initialization, if you're enabling objects.
/// Otherwise, all 128 objects in OAM are initialized as visible 8x8 objects
/// in the top-left corner using tile index 0.
pub fn hideAllObjects() void {
    for(objects) |*obj| {
        obj.mode = .hidden;
    }
}

/// Refers to affine transformation matrix components in OAM.
/// You probably want to use `gba.display.setObjectTransform` or
/// `gba.bios.objAffineSetOam` rather than accessing this directly, since
/// affine transformation matrices are interleaved with object attributes.
/// Should only be updated during VBlank, to avoid graphical glitches.
///
/// Values start at index 3, and only every 4th value after that is really
/// an affine value. Other values belong to object attributes.
pub const oam_affine_values: [*]volatile gba.math.FixedI16R8 = @ptrCast(gba.mem.oam);

/// Write an affine transformation matrix to OAM, for use with objects.
/// Should only be updated during VBlank, to avoid graphical glitches.
pub fn setObjectTransform(index: u5, transform: gba.math.Affine2x2) void {
    var value_index = 3 + (@as(u8, index) << 4);
    oam_affine_values[value_index] = transform.a;
    value_index += 4;
    oam_affine_values[value_index] = transform.b;
    value_index += 4;
    oam_affine_values[value_index] = transform.c;
    value_index += 4;
    oam_affine_values[value_index] = transform.d;
}

/// Represents the structure of an object/sprite entry in OAM.
pub const Object = packed struct(u48) {
    /// Enumeration of rendering modes for objects/sprites.
    const Mode = enum(u2) {
        /// Normal rendering.
        /// The sprite's `transform` field can be used to apply a horizontal
        /// or vertical flip.
        normal = 0,
        /// The sprite is rendered with an affine transformation.
        /// The sprite's `transform` field is used to specify which affine
        /// matrix in OAM should be used for the affine tranform.
        /// See also `setObjectTransform`.
        affine = 1,
        /// Disables rendering, making the sprite not visible.
        hidden = 2,
        /// The sprite is rendered with an affine transformation,
        /// similar to `Mode.affine`, but expands the clipping box to
        /// twice the sprite's normal dimensions.
        /// If you're wondering why the corners of your sprite are being
        /// clipped off when rotating it, it's probably because you want
        /// to be using `Mode.affine_double` instead of `Mode.affine`.
        affine_double = 3,
    };
    
    /// Enumeration of supported special graphics effect options for
    /// objects/sprites.
    pub const Effect = enum(u2) {
        /// Normal rendering, with no special effect.
        normal,
        /// Enable blending.
        /// See `gba.display.blend`.
        blend,
        /// The object is not displayed. Instead, the sprite is used for a
        /// masking/stencil effect for the object window, based on zero (shown)
        /// or non-zero (not shown) palette indices for each pixel.
        /// See `gba.display.window`.
        window,
    };
    
    /// Enumeration of possible values for the `shape` attribute.
    /// Determines width and height in combination with `shape_size`.
    pub const Shape = enum(u2) {
        /// Corresponding sizes are 8x8, 16x16, 32x32, and 64x64.
        square = 0,
        /// Corresponding sizes are 16x8, 32x8, 32x16, and 64x32.
        wide = 1,
        /// Corresponding sizes are 8x16, 8x32, 16x32, and 32x64.
        tall = 2,
    };
    
    /// Enumeration of possible values for the `shape_size` attribute.
    /// Determines width and height in combination with `shape`.
    pub const ShapeSize = enum(u2) {
        /// The sprite uses either 1 or 2 tiles, depending on `Object.shape`.
        /// - 8x8 pixels (1x1 tiles) with `Shape.square`.
        /// - 16x8 pixels (2x1 tiles) with `Shape.wide`.
        /// - 8x16 pixels (1x2 tiles) with `Shape.tall`.
        size_2 = 0,
        /// The sprite uses a total of 4 tiles.
        /// - 16x16 pixels (2x2 tiles) with `Shape.square`.
        /// - 32x8 pixels (4x1 tiles) with `Shape.wide`.
        /// - 8x32 pixels (1x4 tiles) with `Shape.tall`.
        size_4 = 1,
        /// The sprite uses a total of 8 or 16 tiles, depending on `Object.shape`.
        /// - 32x32 pixels (4x4 tiles) with `Shape.square`.
        /// - 32x16 pixels (4x2 tiles) with `Shape.wide`.
        /// - 16x32 pixels (2x4 tiles) with `Shape.tall`.
        size_16 = 2,
        /// The sprite uses a total of 32 or 64 tiles, depending on `Object.shape`.
        /// - 64x64 pixels (8x8 tiles) with `Shape.square`.
        /// - 64x32 pixels (8x4 tiles) with `Shape.wide`.
        /// - 32x64 pixels (4x8 tiles) with `Shape.tall`.
        size_64 = 3,
    };

    /// Represents a combination of `Shape` and `ShapeSize`.
    pub const Size = packed struct(u4) {
        /// Represents an object size of 8x8 pixels (1x1 tiles).
        pub const size_8x8: Size = .init(.square, .size_2);
        /// Represents an object size of 16x16 pixels (2x2 tiles).
        pub const size_16x16: Size = .init(.square, .size_4);
        /// Represents an object size of 32x32 pixels (4x4 tiles).
        pub const size_32x32: Size = .init(.square, .size_16);
        /// Represents an object size of 64x64 pixels (8x8 tiles).
        pub const size_64x64: Size = .init(.square, .size_64);
        /// Represents an object size of 16x8 pixels (2x1 tiles).
        pub const size_16x8: Size = .init(.wide, .size_2);
        /// Represents an object size of 32x8 pixels (4x1 tiles).
        pub const size_32x8: Size = .init(.wide, .size_4);
        /// Represents an object size of 32x16 pixels (4x2 tiles).
        pub const size_32x16: Size = .init(.wide, .size_16);
        /// Represents an object size of 64x32 pixels (8x4 tiles).
        pub const size_64x32: Size = .init(.wide, .size_64);
        /// Represents an object size of 8x16 pixels (1x2 tiles).
        pub const size_8x16: Size = .init(.tall, .size_2);
        /// Represents an object size of 8x32 pixels (1x4 tiles).
        pub const size_8x32: Size = .init(.tall, .size_4);
        /// Represents an object size of 16x32 pixels (2x4 tiles).
        pub const size_16x32: Size = .init(.tall, .size_16);
        /// Represents an object size of 32x64 pixels (4x8 tiles).
        pub const size_32x64: Size = .init(.tall, .size_64);
        
        shape: Shape = .square,
        shape_size: ShapeSize = .size_2,
        
        pub fn init(shape: Shape, shape_size: ShapeSize) Size {
            return .{ .shape = shape, .shape_size = shape_size };
        }
    };

    /// Used to set transformation effects on an object.
    const Transform = packed union {
        pub const Flip = packed struct(u5) {
            /// Unused bits.
            _: u3 = 0,
            /// Flip the sprite horizontally, when set.
            x: bool = false,
            /// Flip the sprite vertically, when set.
            y: bool = false,
        };
        
        /// Sprite flipping flags. Applies to normal (not affine) objects.
        flip: Flip,
        /// Index of an affine transformation matrix in OAM.
        /// Applies to affine objects.
        /// See `setObjectTransform`.
        affine_index: u5,
        
        /// Initialize horizontal and vertical flip.
        pub fn initFlip(x: bool, y: bool) Transform {
            return .{ .flip = .{ .x = x, .y = y } };
        }
        
        /// Initialize horizontal and vertical flip with a vector.
        pub fn initFlipVec(vec: gba.math.Vec2B) Transform {
            return .initFlip(vec.x, vec.y);
        }
        
        /// Initialize with an affine matrix index.
        pub fn initAffine(affine_index: u5) Transform {
            return .{ .affine_index = affine_index };
        }
    };

    /// Represents the Y position of the object on the screen.
    /// For normal sprites, `x` and `y` indicate the object's top-left corner.
    /// For affine sprites, they indicate the object's center.
    y: u8 = 0,
    /// Determines whether to display the sprite normally, hide it, use an
    /// affine transform, or use a double-size affine transform.
    mode: Mode = .normal,
    /// Enables special rendering effects.
    effect: Effect = .normal,
    /// Enables mosaic effects on this object.
    /// See `gba.display.mosaic`.
    mosaic: bool = false,
    /// Indicates whether tile data for this object is in a 4 bits per pixel
    /// (16-color) or 8 bits per pixel (256-color) format.
    /// When using 4-bit color, `palette` indicates the which 16-color
    /// palette bank to use.
    bpp: gba.display.TileBpp = .bpp_4,
    /// Used in combination with size. See `Object.setSize`.
    shape: Shape = .square,
    /// Represents the X position of the object on the screen.
    /// For normal sprites, `x` and `y` indicate the object's top-left corner.
    /// For affine sprites, they indicate the object's center.
    x: u9 = 0,
    /// For normal sprites:
    /// Contains bits indicating whether to flip horizontally and/or vertically.
    /// For affine sprites:
    /// Contains a 5-bit index indicating which affine transformation matrix
    /// should be used for this object.
    transform: Transform = .{ .flip = .{} },
    /// Used in combination with shape. See `Object.setSize`.
    shape_size: ShapeSize = .size_2,
    /// Base tile index for the sprite.
    /// This is always multiplied by 32 bytes (the size of a 4bpp tile) to
    /// determine offset in VRAM.
    /// This means that the index counts half-tiles for 8bpp objects,
    /// and should be multiplied by 2 to count full tiles.
    ///
    /// Specifically how this decides the appearance of a sprite depends on
    /// `gba.display.ctrl.obj_mapping`.
    /// With 1D mapping, the object's tiles are represented flat in VRAM,
    /// in a contiguous line of tiles in row-major order.
    /// With 2D mapping, the charblock is treated as a 256 pixel wide bitmap,
    /// and each row of the object is stored with a linear offset which lines
    /// it up in the bitmap in this way.
    ///
    /// Note that graphics modes 3, 4, and 5 (bitmap modes) use the lower 512
    /// object tiles for screen bitmap data.
    /// This means that, in these modes, you probably want this value to be
    /// 512 or higher.
    base_tile: u10 = 0,
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
    
    /// Options accepted by `init`.
    /// These options relate to initializing an object with `Mode.normal`.
    pub const InitOptions = struct {
        /// X position on the screen.
        /// Relative to the top-left corner of the object.
        x: u9 = 0,
        /// Y position on the screen.
        /// Relative to the top-left corner of the object.
        y: u8 = 0,
        /// Special rendering effects for this sprite.
        effect: Effect = .normal,
        /// Whether to use a mosaic effect.
        mosaic: bool = false,
        /// Whether the object uses 4-bit or 8-bit color.
        bpp: gba.display.TileBpp = .bpp_4,
        /// Indicates the size of the object/sprite.
        size: Size = .size_8x8,
        /// Flip the object horizontally or vertically when drawing.
        flip: gba.math.Vec2B = .neither,
        /// Base tile index for the sprite.
        base_tile: u10 = 0,
        /// Higher-priority objects render on top of lower-priority ones.
        priority: gba.display.Priority = .highest,
        /// Palette bank index for 4bpp objects.
        palette: u4 = 0,
    };
    
    /// Options accepted by `initAffine`.
    /// These options relate to initializing an object with `Mode.affine`
    /// or `Mode.affine_double`.
    pub const InitAffineOptions = struct {
        /// X position on the screen.
        /// Relative to the center of the object.
        x: u9 = 0,
        /// Y position on the screen.
        /// Relative to the center of the object.
        y: u8 = 0,
        /// Choose between `Mode.affine` and `Mode.affine_double`.
        double: bool = false,
        /// Special rendering effects for this sprite.
        effect: Effect = .normal,
        /// Whether to use a mosaic effect.
        mosaic: bool = false,
        /// Whether the object uses 4-bit or 8-bit color.
        bpp: gba.display.TileBpp = .bpp_4,
        /// Indicates the size of the object/sprite.
        size: Size = .size_8x8,
        /// Specify an affine transformation matrix in OAM.
        /// See `setObjectTransform`.
        affine_index: u5 = 0,
        /// Base tile index for the sprite.
        base_tile: u10 = 0,
        /// Higher-priority objects render on top of lower-priority ones.
        priority: gba.display.Priority = .highest,
        /// Palette bank index for 4bpp objects.
        palette: u4 = 0,
    };
    
    /// Helper to initialize a normal object.
    pub fn init(options: InitOptions) Object {
        return .{
            .y = options.y,
            .mode = .normal,
            .effect = options.effect,
            .mosaic = options.mosaic,
            .bpp = options.bpp,
            .shape = options.size.shape,
            .x = options.x,
            .transform = .initFlipVec(options.flip),
            .shape_size = options.size.shape_size,
            .base_tile = options.base_tile,
            .priority = options.priority,
            .palette = options.palette,
        };
    }
    
    /// Helper to initialize an affine object.
    pub fn initAffine(options: InitAffineOptions) Object {
        return .{
            .y = options.y,
            .mode = if(options.double) Mode.affine_double else Mode.affine,
            .effect = options.effect,
            .mosaic = options.mosaic,
            .bpp = options.bpp,
            .shape = options.size.shape,
            .x = options.x,
            .transform = .initAffine(options.affine_index),
            .shape_size = options.size.shape_size,
            .base_tile = options.base_tile,
            .priority = options.priority,
            .palette = options.palette,
        };
    }

    /// Set the size of the object.
    /// This may be more convenient than separately assigning `shape`
    /// and `shape_size`.
    pub fn setSize(self: *Object, size: Size) void {
        self.shape = size.shape;
        self.shape_size = size.shape_size;
    }

    /// Assign the X and Y position of the object.
    pub inline fn setPosition(self: *Object, x: u9, y: u8) void {
        self.x = x;
        self.y = y;
    }

    /// Assign the X and Y position of the object using a vector.
    pub inline fn setPositionVec(self: *Object, vec: anytype) void {
        if(comptime(!@hasField(vec, "x") or !@hasField(vec, "y"))) {
            @compileError("Position value is not a valid vector type.");
        }
        self.x = @intCast(vec.x);
        self.y = @intCast(vec.y);
    }
};
