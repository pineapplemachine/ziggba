//! This module implements a 3x3 matrix.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

/// Returns either a `Mat3x3I` or `Mat3x3FixedI` type depending
/// on the given vector component type.
pub fn Mat3x3(comptime T: type) type {
    if(gba.math.isSignedFixedPointType(T)) {
        return Mat3x3I(T);
    }
    else if(gba.math.isSignedIntPrimitiveType(T)) {
        return Mat3x3I(T);
    }
    else {
        @compileError("No Mat3x3 implementation is available for this type.");
    }
}

/// Represents a 3x3 matrix with signed components.
pub fn Mat3x3I(comptime T: type) type {
    return extern struct {
        const Self = @This();
        const Vec3T = gba.math.Vec3(T);
        
        pub const ComponentT: type = T;
        
        pub const zero: Self = .initColumns(.zero, .zero, .zero);
        pub const one: Self = .initColumns(.one, .one, .one);
        pub const identity: Self = .initColumns(.x_1, .y_1, .z_1);
        
        /// Column vectors for this matrix.
        cols: [3]Vec3T = .{ .zero, .zero, .zero },
        
        /// Components are given in row-major order.
        pub fn initRowMajor(
            x1y1: T, x2y1: T, x3y1: T,
            x1y2: T, x2y2: T, x3y2: T,
            x1y3: T, x2y3: T, x3y3: T,
        ) Self {
            return .initColumns(
                .init(x1y1, x1y2, x1y3),
                .init(x2y1, x2y2, x2y3),
                .init(x3y1, x3y2, x3y3),
            );
        }
        
        /// Components are given in column-major order.
        pub fn initColumnMajor(
            x1y1: T, x1y2: T, x1y3: T,
            x2y1: T, x2y2: T, x2y3: T,
            x3y1: T, x3y2: T, x3y3: T,
        ) Self {
            return .initColumns(
                .init(x1y1, x1y2, x1y3),
                .init(x2y1, x2y2, x2y3),
                .init(x3y1, x3y2, x3y3),
            );
        }
        
        /// Initialize with row vectors.
        pub fn initRows(a: [3]Vec3T, b: [3]Vec3T, c: [3]Vec3T) Self {
            return .initColumns(
                .init(a.x, b.x, c.x),
                .init(a.y, b.y, c.y),
                .init(a.z, b.z, c.z),
            );
        }
        
        /// Initialize with column vectors.
        pub fn initColumns(a: [3]Vec3T, b: [3]Vec3T, c: [3]Vec3T) Self {
            return .{ .cols = .{ a, b, c } };
        }
        
        /// Initialize a scaling matrix.
        /// See also `gba.bios.objAffineSet`.
        pub fn initScale(x: T, y: T, z: T) Self {
            return .initColumnMajor(
                x, .zero, .zero,
                .zero, y, .zero,
                .zero, .zero, z,
            );
        }
        
        /// Initialize with an array of values, listed in row-major order.
        pub fn fromArrayRowMajor(values: [9]T) Self {
            return .initColumns(
                .init(values[0], values[3], values[6]),
                .init(values[1], values[4], values[7]),
                .init(values[2], values[5], values[8]),
            );
        }
        
        /// Initialize with an array of values, listed in column-major order.
        pub fn fromArrayColumnMajor(values: [9]T) Self {
            return @bitCast(values);
        }
        
        /// Convert to an affine transform.
        pub fn toAffine2x2(self: Self) gba.math.Affine3x2 {
            return .init(
                self.cols[0].x.to(gba.math.FixedI32R8),
                self.cols[1].x.to(gba.math.FixedI32R8),
                self.cols[0].y.to(gba.math.FixedI32R8),
                self.cols[1].y.to(gba.math.FixedI32R8),
            );
        }
        
        /// Convert to an affine transform.
        pub fn toAffine3x2(self: Self) gba.math.Affine3x2 {
            return .init(
                self.toAffine2x2(),
                .init(
                    self.cols[2].x.to(gba.math.FixedI32R8),
                    self.cols[2].x.to(gba.math.FixedI32R8),
                ),
            );
        }
        
        /// Convert to a different 3x3 matrix type.
        pub fn toMat3x3(
            self: Self,
            comptime ToComponentT: type,
        ) Mat3x3(ToComponentT) {
            if(ToComponentT == T) {
                return self;
            }
            return .initColumns(
                self.cols[0].to(ToComponentT),
                self.cols[1].to(ToComponentT),
                self.cols[2].to(ToComponentT),
            );
        }
        
        /// Multiply two matrices.
        pub fn mul(a: Self, b: Self) Self {
            return .initColumns(
                a.mulVec3(b.cols[0]),
                a.mulVec3(b.cols[1]),
                a.mulVec3(b.cols[2]),
            );
        }
        
        /// Multiply a matrix and a vector.
        pub fn mulVec3(self: Self, vec: Vec3T) Vec3T {
            const x = (
                gba.math.mul(self.cols[0].x, vec.x) +
                gba.math.mul(self.cols[1].x, vec.x) +
                gba.math.mul(self.cols[2].x, vec.x)
            );
            const y = (
                gba.math.mul(self.cols[0].y, vec.y) +
                gba.math.mul(self.cols[1].y, vec.y) +
                gba.math.mul(self.cols[2].y, vec.y)
            );
            const z = (
                gba.math.mul(self.cols[0].z, vec.z) +
                gba.math.mul(self.cols[1].z, vec.z) +
                gba.math.mul(self.cols[2].z, vec.z)
            );
            return .init(x, y, z);
        }
    };
}

/// 3x3 matrix with fixed point components.
pub const Mat3x3FixedI16R8 = Mat3x3I(gba.math.FixedI16R8);

/// 3x3 matrix with fixed point components.
pub const Mat3x3FixedI32R8 = Mat3x3I(gba.math.FixedI32R8);

/// 3x3 matrix with fixed point components.
pub const Mat3x3FixedI32R16 = Mat3x3I(gba.math.FixedI32R16);
