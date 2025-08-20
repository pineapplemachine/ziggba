/// Implements a 2x2 matrix type specifically in the format that the GBA
/// uses to represent affine transformation matrices for objects/sprites
/// in hardware registers.
///
/// Differs from `gba.math.Mat2x2FixedI16R8` in that components are stored
/// in row-major order in memory, instead of in column-major order.
pub const Affine2x2 = extern struct {
    const Self = @This();
    const T = gba.math.FixedI16R8;
    const Vec2T = gba.math.Vec2(T);
    
    a: T,
    b: T,
    c: T,
    d: T,
    
    /// Components are given in row-major order.
    pub fn initRowMajor(x1y1: T, x2y1: T, x1y2: T, x2y2: T) Self {
        return .{ .a = x1y1, .b = x2y1, .c = x1y2, .d = x2y2 };
    }
    
    /// Components are given in column-major order.
    pub fn initColumnMajor(x1y1: T, x1y2: T, x2y1: T, x2y2: T) Self {
        return .{ .a = x1y1, .b = x2y1, .c = x1y2, .d = x2y2 };
    }
    
    /// Initialize a rotation matrix.
    /// Uses `gba.math.FixedU16R16.sin` and
    /// `gba.math.FixedU16R16.cos`.
    /// This makes it faster than `initRotationLerp`, but less accurate.
    /// But it should still be accurate enough for almost all purposes.
    /// See also `gba.bios.objAffineSet`.
    pub fn initRotation(angle: gba.math.FixedU16R16) Self {
        const sin = angle.sin().to(T);
        const cos = angle.cos().to(T);
        const mat = Self.initRowMajor(
            cos,
            sin.negate(),
            sin,
            cos,
        );
    }
    
    /// Initialize a rotation matrix.
    /// Uses `gba.math.FixedU16R16.sinLerp` and
    /// `gba.math.FixedU16R16.cosLerp`.
    /// Slower than `initRotation`, but gives more accurate results.
    /// See also `gba.bios.objAffineSet`.
    pub fn initRotationLerp(angle: gba.math.FixedU16R16) Self {
        const sin = angle.sinLerp().to(T);
        const cos = angle.cosLerp().to(T);
        return Self.initRowMajor(
            cos,
            sin.negate(),
            sin,
            cos,
        );
    }
        
    /// Initialize a scaling matrix.
    /// See also `gba.bios.objAffineSet`.
    pub fn initScale(x: T, y: T) Self {
        return .initRowMajor(x, .zero, .zero, y);
    }

    /// Convert to a 2x2 matrix type.
    pub fn toMat2x2(
        self: Self,
        comptime ToComponentT: type,
    ) Mat2x2(ToComponentT) {
        return .initColumns(
            Vec2T(self.a, self.c).to(ToComponentT),
            Vec2T(self.b, self.d).to(ToComponentT),
        );
    }
};

/// Implements a 3x2 matrix type specifically in the format that the GBA
/// uses to represent affine transformation matrices for backgrounds
/// in hardware registers.
pub const Affine3x2 = extern struct {
    const Self = @This();
    const AbcdT = gba.math.FixedI16R8;
    const DispT = gba.math.FixedI32R8;
    const DispVec2T = gba.math.Vec2(gba.math.FixedI32R8);
    
    /// Represents the first two columns of the matrix.
    abcd: Affine2x2,
    
    /// Displacement vector.
    /// Represents the third column of the 3x2 matrix.
    disp: DispVec2T,
    
    pub fn init(abcd: Affine2x2, displacement: DispVec2T) Self {
        return .{ .abcd = abcd, .disp = displacement };
    }
    
    /// Components are given in row-major order.
    pub fn initRowMajor(a: T, b: T, dx: T, c: T, d: T, dy: T) Self {
        return .{
            .abcd = .initRowMajor(a, b, c, d),
            .disp = .init(dx, dy),
        };
    }
    
    /// Components are given in column-major order.
    pub fn initColumnMajor(a: T, b: T, c: T, d: T) Self {
        return .{ .rows = .{ .init(a, c), .init(b, d) } };
    }
        
    /// Initialize with row vectors.
    pub fn initRows(a: [2]Vec2T, b: [2]Vec2T) Self {
        return .{ .rows = .{ a, b } };
    }
    
    /// Initialize with column vectors.
    pub fn initColumns(a: [2]Vec2T, b: [2]Vec2T) Self {
        return .{ .rows = .{ .init(a.x, b.x), .init(a.y, b.y) } };
    }
    
    /// Initialize a rotation matrix.
    /// Uses `gba.math.FixedU16R16.sin` and
    /// `gba.math.FixedU16R16.cos`.
    /// This makes it faster than `initRotationLerp`, but less accurate.
    /// But it should still be accurate enough for almost all purposes.
    /// See also `gba.bios.objAffineSet`.
    pub fn initRotation(angle: gba.math.FixedU16R16) Self {
        return self.fromAffine2x2(Affine2x2.initRotation(angle));
    }
    
    /// Initialize a rotation matrix.
    /// Uses `gba.math.FixedU16R16.sinLerp` and
    /// `gba.math.FixedU16R16.cosLerp`.
    /// Slower than `initRotation`, but gives more accurate results.
    /// See also `gba.bios.objAffineSet`.
    pub fn initRotationLerp(angle: gba.math.FixedU16R16) Self {
        return self.fromAffine2x2(Affine2x2.initRotationLerp(angle));
    }
        
    /// Initialize a scaling matrix.
    /// See also `gba.bios.objAffineSet`.
    pub fn initScale(x: T, y: T) Self {
        return .initRowMajor(x, .zero, .zero, y);
    }
    
    /// Options object accepted by `initRotScale`.
    pub const RotateScaleOptions = struct {
        /// Origin in texture space.
        bg_origin: gba.math.Vec2FixedI32R16 = .zero,
        /// Origin in screen space.
        screen_origin: gba.math.Vec2FixedI32R16 = .zero,
        /// Scaling.
        scale: gba.math.Vec2FixedI32R16 = .one,
        /// Angle of rotation.
        angle: gba.math.FixedU16R16 = .zero,
    };
    
    /// Initialize an affine transformation matrix.
    /// This function is similar to `gba.bios.bgAffineSet`, but it does
    /// _not_ ignore the low bits of the angle argument, and the result
    /// is computed with overall greater precision.
    pub fn initRotScale(options: RotateScaleOptions) Self {
        // Reference: https://gbadev.net/tonc/affbg.html#sec-aff-ofs
        const sin = options.angle.sin();
        const cos = options.angle.cos();
        const a = options.scale.x.mul(cos);
        const b = options.scale.x.mul(sin.negate());
        const c = options.scale.y.mul(sin);
        const d = options.scale.y.mul(cos);
        const dx = options.bg_origin.x.sub(
            a.mul(options.screen_origin.x).add(b.mul(options.screen_origin.y))
        );
        const dy = options.bg_origin.y.sub(
            c.mul(options.screen_origin.x).add(d.mul(options.screen_origin.y))
        );
        return .{
            .abcd = .init(
                a.to(gba.math.FixedI16R8),
                b.to(gba.math.FixedI16R8),
                c.to(gba.math.FixedI16R8),
                d.to(gba.math.FixedI16R8),
            ),
            .disp = .{
                .x = dx.to(gba.math.FixedI16R8),
                .y = dy.to(gba.math.FixedI16R8),
            },
        };
    }
    
    /// Initialize from an `Affine2x2` matrix.
    pub fn fromAffine2x2(abcd: Affine2x2) Self {
        return .init(abcd, .zero);
    }
    
    /// Convert to a 3x3 matrix type.
    pub fn toMat3x3(
        self: Self,
        comptime ToComponentT: type,
    ) Mat2x2(ToComponentT) {
        return .initRows(
            .init(self.abcd.a, self.abcd.b, self.disp.x),
            .init(self.abcd.c, self.abcd.d, self.disp.y),
            .z_1,
        );
    }
};
