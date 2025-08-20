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
