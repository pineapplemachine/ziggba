//! This module implements a 2x2 matrix.

const gba = @import("gba.zig");

/// Returns either a `Mat2x2I` or `Mat2x2FixedI` type depending
/// on the given vector component type.
pub fn Mat2x2(comptime T: type) type {
    if(comptime(gba.math.isSignedFixedPointType(T))) {
        return Mat2x2I(T);
    }
    else if(comptime(gba.math.isSignedIntPrimitiveType(T))) {
        return Mat2x2I(T);
    }
    else {
        @compileError("No Mat2x2 implementation is available for this type.");
    }
}

/// Represents a 2x2 matrix with signed components.
pub fn Mat2x2I(comptime T: type) type {
    return extern struct {
        const Self = @This();
        const Vec2T = gba.math.Vec2(T);
        
        pub const ComponentT: type = T;
        
        pub const zero: Self = .initColumns(.zero, .zero);
        pub const one: Self = .initColumns(.one, .one);
        pub const identity: Self = .initColumns(.x_1, .y_1);
        
        /// Column vectors for this matrix.
        cols: [2]Vec2T = .{ .zero, .zero },
        
        /// Components are given in row-major order.
        pub fn initRowMajor(x1y1: T, x2y1: T, x1y2: T, x2y2: T) Self {
            return .{ .cols = .{ .init(x1y1, x1y2), .init(x2y1, x2y2) } };
        }
        
        /// Components are given in column-major order.
        pub fn initColumnMajor(x1y1: T, x1y2: T, x2y1: T, x2y2: T) Self {
            return .{ .cols = .{ .init(x1y1, x1y2), .init(x2y1, x2y2) } };
        }
        
        /// Initialize with row vectors.
        pub fn initRows(a: [2]Vec2T, b: [2]Vec2T) Self {
            return .{ .cols = .{ .init(a.x, b.x), .init(a.y, b.y) } };
        }
        
        /// Initialize with column vectors.
        pub fn initColumns(a: [2]Vec2T, b: [2]Vec2T) Self {
            return .{ .cols = .{ a, b } };
        }
        
        /// Initialize a rotation matrix.
        /// Uses `gba.math.FixedU16R16.sin` and
        /// `gba.math.FixedU16R16.cos`.
        /// This makes it faster than `initRotationLerp`, but less accurate.
        /// But it should still be accurate enough for almost all purposes.
        pub fn initRotation(angle: gba.math.FixedU16R16) Self {
            const sin = angle.sin().to(T);
            const cos = angle.cos().to(T);
            return Self.initColumnMajor(
                cos,
                sin,
                sin.negate(),
                cos,
            );
        }
        
        /// Initialize a rotation matrix.
        /// Uses `gba.math.FixedU16R16.sinLerp` and
        /// `gba.math.FixedU16R16.cosLerp`.
        /// Slower than `initRotation`, but gives more accurate results.
        pub fn initRotationLerp(angle: gba.math.FixedU16R16) Self {
            const sin = angle.sinLerp().to(T);
            const cos = angle.cosLerp().to(T);
            return Self.initColumnMajor(
                cos,
                sin,
                sin.negate(),
                cos,
            );
        }
        
        /// Initialize a scaling matrix.
        pub fn initScale(x: T, y: T) Self {
            return .initColumnMajor(x, .zero, .zero, y);
        }
        
        /// Initialize with an array of values, listed in row-major order.
        pub fn fromArrayRowMajor(values: [4]T) Self {
            return .initColumns(
                .init(values[0], values[2]),
                .init(values[1], values[3]),
            );
        }
        
        /// Initialize with an array of values, listed in column-major order.
        pub fn fromArrayColumnMajor(values: [4]T) Self {
            return @bitCast(values);
        }
        
        /// Convert to an affine transform.
        /// The `gba.math.Affine2x2` type is suitable for affine transforms
        /// for objects/sprites.
        pub fn toAffine2x2(self: Self) gba.math.Affine2x2 {
            return .initRows(
                self.cols[0].to(gba.math.FixedI16R8),
                self.cols[1].to(gba.math.FixedI16R8),
            );
        }
        
        /// Convert to an affine transform.
        /// The `gba.math.Affine3x2` type is suitable for affine transforms
        /// for backgrounds.
        pub fn toAffine3x2(self: Self) gba.math.Affine3x2 {
            return .fromAffine2x2(self.toAffine2x2());
        }
        
        /// Convert to a different 2x2 matrix type.
        pub fn toMat2x2(
            self: Self,
            comptime ToComponentT: type,
        ) Mat2x2(ToComponentT) {
            if(ToComponentT == T) {
                return self;
            }
            return .initColumns(
                self.cols[0].to(ToComponentT),
                self.cols[1].to(ToComponentT),
            );
        }
        
        /// Convert to a 3x3 matrix type.
        pub fn toMat3x3(
            self: Self,
            comptime ToComponentT: type,
        ) gba.math.Mat3x3(ToComponentT) {
            return .initColumns(
                self.cols[0].toVec3(ToComponentT),
                self.cols[1].toVec3(ToComponentT),
                .z_1,
            );
        }
        
        /// Multiply two matrices.
        pub fn mul(a: Self, b: Self) Self {
            return .initColumns(
                a.mulVec2(b.cols[0]),
                a.mulVec2(b.cols[1]),
            );
        }
        
        /// Multiply a matrix and a vector.
        pub fn mulVec2(self: Self, vec: Vec2T) Vec2T {
            const x = (
                gba.math.mul(self.cols[0].x, vec.x) +
                gba.math.mul(self.cols[1].x, vec.x)
            );
            const y = (
                gba.math.mul(self.cols[0].y, vec.y) +
                gba.math.mul(self.cols[1].y, vec.y)
            );
            return .init(x, y);
        }
    };
}

/// 2x2 matrix with fixed point components.
///
/// Differs from `gba.math.Affine2x2` in that components are stored
/// in column-major order in memory, instead of in row-major order.
pub const Mat2x2FixedI16R8 = Mat2x2I(gba.math.FixedI16R8);

/// 2x2 matrix with fixed point components.
pub const Mat2x2FixedI32R8 = Mat2x2I(gba.math.FixedI32R8);

/// 2x2 matrix with fixed point components.
pub const Mat2x2FixedI32R16 = Mat2x2I(gba.math.FixedI32R16);
