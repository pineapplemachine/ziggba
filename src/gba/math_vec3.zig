//! This module implements a three-dimensional vector.

const gba = @import("gba.zig");

pub fn Vec3(comptime T: type) type {
    if(comptime(gba.math.isSignedFixedPointType(T))) {
        return Vec3I(T);
    }
    else if(comptime(gba.math.isSignedIntPrimitiveType(T))) {
        return Vec3I(T);
    }
    else {
        @compileError("No Vec3 implementation is available for this type.");
    }
}

/// Represents a vector with three signed components.
pub fn Vec3I(comptime T: type) type {
    const T_zero = gba.math.zero(T);
    const T_one = gba.math.one(T);
    const T_negative_one = gba.math.negativeOne(T);
    return extern struct {
        const Self = @This();
        
        pub const ComponentT: type = T;
        
        pub const zero: Self = .init(T_zero, T_zero, T_zero);
        pub const one: Self = .init(T_one, T_one, T_one);
        pub const left: Self = .init(T_negative_one, T_zero, T_zero);
        pub const right: Self = .init(T_one, T_zero, T_zero);
        pub const up: Self = .init(T_zero, T_negative_one, T_zero);
        pub const down: Self = .init(T_zero, T_one, T_zero);
        pub const forward: Self = .init(T_zero, T_zero, T_negative_one);
        pub const back: Self = .init(T_zero, T_zero, T_one);
        pub const x_1: Self = .init(T_one, T_zero, T_zero);
        pub const y_1: Self = .init(T_zero, T_one, T_zero);
        pub const z_1: Self = .init(T_zero, T_zero, T_one);
        
        x: T = T_zero,
        y: T = T_zero,
        z: T = T_zero,
        
        pub fn init(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }
        
        /// Convert the vector to a different type.
        pub fn toVec3(self: Self, comptime ToComponentT: type) Vec3(ToComponentT) {
            if(comptime(ToComponentT == T)) {
                return self;
            }
            else if(comptime(gba.math.isFixedPointType(T))) {
                return .init(
                    self.x.to(ToComponentT),
                    self.y.to(ToComponentT),
                    self.z.to(ToComponentT),
                );
            }
            else if(comptime(gba.math.isFixedPointType(ToComponentT))) {
                return .init(
                    .fromInt(@intCast(self.x)),
                    .fromInt(@intCast(self.y)),
                    .fromInt(@intCast(self.z)),
                );
            }
            else {
                return .init(
                    @intCast(self.x),
                    @intCast(self.y),
                    @intCast(self.z),
                );
            }
        }
        
        /// Subtract this vector from the zero vector.
        pub fn negate(self: Self) Self {
            return .{
                .x = gba.math.negate(T, self.x),
                .y = gba.math.negate(T, self.y),
                .z = gba.math.negate(T, self.z),
            };
        }
        
        /// Logical bit shift left on both components,
        /// with the number of bits known at comptime.
        pub fn lsl(self: Self, comptime bits: comptime_int) Self {
            return .{
                .x = gba.math.lsl(T, self.x, bits),
                .y = gba.math.lsl(T, self.y, bits),
                .z = gba.math.lsl(T, self.z, bits),
            };
        }
        
        /// Logical bit shift right on both components,
        /// with the number of bits known at comptime.
        pub fn lsr(self: Self, comptime bits: comptime_int) Self {
            return .{
                .x = gba.math.lsr(T, self.x, bits),
                .y = gba.math.lsr(T, self.y, bits),
                .z = gba.math.lsr(T, self.z, bits),
            };
        }
        
        /// Arithmetic bit shift right on both components,
        /// with the number of bits known at comptime.
        pub fn asr(self: Self, comptime bits: comptime_int) Self {
            return .{
                .x = gba.math.asr(T, self.x, bits),
                .y = gba.math.asr(T, self.y, bits),
                .z = gba.math.asr(T, self.z, bits),
            };
        }
        
        /// Logical bit shift left on both components,
        /// accepting a variable number of bits.
        pub fn lslVar(self: Self, bits: anytype) Self {
            return .{
                .x = gba.math.lslVar(T, self.x, bits),
                .y = gba.math.lslVar(T, self.y, bits),
                .z = gba.math.lslVar(T, self.z, bits),
            };
        }
        
        /// Logical bit shift right on both components,
        /// accepting a variable number of bits.
        pub fn lsrVar(self: Self, bits: anytype) Self {
            return .{
                .x = gba.math.lsrVar(T, self.x, bits),
                .y = gba.math.lsrVar(T, self.y, bits),
                .z = gba.math.lsrVar(T, self.z, bits),
            };
        }
        
        /// Arithmetic bit shift right on both components,
        /// accepting a variable number of bits.
        pub fn asrVar(self: Self, bits: anytype) Self {
            return .{
                .x = gba.math.asrVar(T, self.x, bits),
                .y = gba.math.asrVar(T, self.y, bits),
                .z = gba.math.asrVar(T, self.z, bits),
            };
        }
        
        /// Returns true when all components of the vector are zero.
        pub fn isZero(self: Self) bool {
            return (
                gba.math.eql(T, self.x, T_zero) and
                gba.math.eql(T, self.y, T_zero) and
                gba.math.eql(T, self.z, T_zero)
            );
        }
        
        /// Get the squared magnitude of the vector.
        pub fn hypotSq(self: Self) T {
            return gba.math.add(
                T,
                gba.math.mul(T, self.x, self.x),
                gba.math.add(
                    T,
                    gba.math.mul(self.y, self.y),
                    gba.math.mul(self.z, self.z),
                ),
            );
        }
        
        /// Get the magnitude of the vector, i.e. the length of
        /// the hypotenuse of the triangle formed by this vector.
        pub fn hypot(self: Self) T {
            const sq = self.hypotSq();
            if(comptime(gba.math.isFixedPointType(T))) {
                return .initRaw(gba.bios.sqrt(sq.value));
            }
            else {
                return gba.bios.sqrt(sq);
            }
        }
        
        /// Add two vectors.
        pub fn add(a: Self, b: Self) Self {
            return .{
                .x = gba.math.add(T, a.x, b.x),
                .y = gba.math.add(T, a.y, b.y),
                .z = gba.math.add(T, a.z, b.z),
            };
        }
        
        /// Subtract vector `b` from vector `a`.
        pub fn sub(a: Self, b: Self) Self {
            return .{
                .x = gba.math.sub(T, a.x, b.x),
                .y = gba.math.sub(T, a.y, b.y),
                .z = gba.math.sub(T, a.z, b.z),
            };
        }
        
        /// Multiply both components of a vector by a scalar value.
        pub fn scale(self: Self, scalar: T) Self {
            return .{
                .x = gba.math.mul(T, self.x, scalar),
                .y = gba.math.mul(T, self.y, scalar),
                .z = gba.math.mul(T, self.z, scalar),
            };
        }
        
        /// Check if two vectors are equal.
        pub fn eql(a: Self, b: Self) Self {
            return (
                gba.math.eql(T, a.x, b.x) and
                gba.math.eql(T, a.y, b.y) and
                gba.math.eql(T, a.z, b.z)
            );
        }
        
        /// Get the dot product of two vectors.
        pub fn dot(a: Self, b: Self) T {
            return gba.math.add(
                T,
                gba.math.mul(T, a.x, b.x),
                gba.math.add(
                    T,
                    gba.math.mul(T, a.y, b.y),
                    gba.math.mul(T, a.z, b.z),
                ),
            );
        }
        
        /// Compute the cross product of two vectors.
        pub fn cross(a: Self, b: Self) Self {
            return .{
                .x = gba.math.sub(
                    T,
                    gba.math.mul(T, a.y, b.z),
                    gba.math.mul(T, a.z, b.y),
                ),
                .y = gba.math.sub(
                    T,
                    gba.math.mul(T, a.z, b.x),
                    gba.math.mul(T, a.x, b.z),
                ),
                .z = gba.math.sub(
                    T,
                    gba.math.mul(T, a.x, b.y),
                    gba.math.mul(T, a.y, b.x),
                ),
            };
        }
    };
}

/// Three-dimensional vector with signed 8-bit integer components.
pub const Vec3I8 = Vec3I(i8);

/// Three-dimensional vector with signed 16-bit integer components.
pub const Vec3I16 = Vec3I(i16);

/// Three-dimensional vector with signed 32-bit integer components.
pub const Vec3I32 = Vec3I(i32);

/// Three-dimensional vector with fixed point components.
pub const Vec3FixedI16R8 = Vec3I(gba.math.FixedI16R8);

/// Three-dimensional vector with fixed point components.
pub const Vec3FixedI32R8 = Vec3I(gba.math.FixedI32R8);

/// Three-dimensional vector with fixed point components.
pub const Vec3FixedI32R16 = Vec3I(gba.math.FixedI32R16);
