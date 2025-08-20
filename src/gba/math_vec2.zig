const gba = @import("gba.zig");

/// Returns either a `Vec2I`, `Vec2U`, or `Vec2FixedI` type depending
/// on the given vector component type.
pub fn Vec2(comptime T: type) type {
    if(comptime(gba.math.isSignedFixedPointType(T))) {
        return Vec2I(T);
    }
    else if(comptime(gba.math.isSignedIntPrimitiveType(T))) {
        return Vec2I(T);
    }
    else if(comptime(gba.math.isUnsignedIntPrimitiveType(T))) {
        return Vec2U(T);
    }
    else {
        @compileError("No Vec2 implementation is available for this type.");
    }
}

/// Represents a vector with two signed components.
pub fn Vec2I(comptime T: type) type {
    const T_zero = gba.math.zero(T);
    const T_one = gba.math.one(T);
    const T_negative_one = gba.math.negativeOne(T);
    return extern struct {
        const Self = @This();
        
        pub const ComponentT: type = T;
        
        pub const zero: Self = .init(T_zero, T_zero);
        pub const one: Self = .init(T_one, T_one);
        pub const left: Self = .init(T_negative_one, T_zero);
        pub const right: Self = .init(T_one, T_zero);
        pub const up: Self = .init(T_zero, T_negative_one);
        pub const down: Self = .init(T_zero, T_one);
        pub const x_1: Self = .init(T_one, T_zero);
        pub const y_1: Self = .init(T_zero, T_one);
        
        x: T,
        y: T,
        
        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }
        
        /// Convert the vector to a different type.
        pub fn toVec2(self: Self, comptime ToComponentT: type) Vec2(ToComponentT) {
            if(comptime(ToComponentT == T)) {
                return self;
            }
            else if(comptime(gba.math.isFixedPointType(T))) {
                return .init(
                    self.x.to(ToComponentT),
                    self.y.to(ToComponentT),
                );
            }
            else if(comptime(gba.math.isFixedPointType(ToComponentT))) {
                return .init(
                    .fromInt(@intCast(self.x)),
                    .fromInt(@intCast(self.y)),
                );
            }
            else {
                return .init(
                    @intCast(self.x),
                    @intCast(self.y),
                );
            }
        }
        
        /// Convert to a three-dimensional vector type.
        pub fn toVec3(
            self: Self,
            /// The component type for the new `Vec3`.
            comptime ToComponentT: type,
            /// The Z component of the new `Vec3`.
            z: ToComponentT,
        ) Vec3(ToComponentT) {
            const v = self.toVec2(ToComponentT);
            return .init(v.x, v.y, z);
        }
        
        /// Subtract this vector from the zero vector.
        pub fn negate(self: Self) Self {
            return .{
                .x = gba.math.negate(self.x),
                .y = gba.math.negate(self.y),
            };
        }
        
        /// Returns true when both components of the vector are zero.
        pub fn isZero(self: Self) bool {
            return (
                gba.math.eql(self.x, T_zero) and
                gba.math.eql(self.y, T_zero)
            );
        }
        
        /// Get the squared magnitude of the vector.
        pub fn hypotSq(self: Self) T {
            return gba.math.add(
                gba.math.mul(self.x, self.x),
                gba.math.mul(self.y, self.y)
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
        
        /// Computes the arctangent of `y / x`.
        /// Calls `gba.bios.arctan2`.
        pub fn atan2(self: Self) gba.math.FixedU16R16 {
            if(comptime(gba.math.isFixedPointType(T))) {
                return gba.bios.arctan2(
                    @intCast(self.x.value),
                    @intCast(self.y.value),
                );
            }
            else {
                return gba.bios.arctan2(
                    @intCast(self.x),
                    @intCast(self.y),
                );
            }
        }
        
        /// Add two vectors.
        pub fn add(a: Self, b: Self) Self {
            return .{
                .x = gba.math.add(a.x, b.x),
                .y = gba.math.add(a.y, b.y),
            };
        }
        
        /// Subtract vector `b` from vector `a`.
        pub fn sub(a: Self, b: Self) Self {
            return .{
                .x = gba.math.sub(a.x, b.x),
                .y = gba.math.sub(a.y, b.y),
            };
        }
        
        /// Multiply both components of a vector by a scalar value.
        pub fn scale(self: Self, scalar: T) Self {
            return .{
                .x = gba.math.mul(self.x, scalar),
                .y = gba.math.mul(self.y, scalar),
            };
        }
        
        /// Check if two vectors are equal.
        pub fn eql(a: Self, b: Self) Self {
            return (
                gba.math.eql(a.x, b.x) and
                gba.math.eql(a.y, b.y)
            );
        }
        
        /// Get the dot product of two vectors.
        pub fn dot(a: Self, b: Self) T {
            return gba.math.add(
                gba.math.mul(a.x, b.x),
                gba.math.mul(a.y, b.y)
            );
        }
    };
}

/// Represents a vector with two unsigned integer primitive components.
pub fn Vec2U(comptime T: type) type {
    return extern struct {
        const Self = @This();
        
        pub const ComponentT: type = T;
        
        pub const zero: Self = .init(0, 0);
        pub const one: Self = .init(1, 1);
        pub const x_1: Self = .init(1, 0);
        pub const y_1: Self = .init(0, 1);
        
        x: T,
        y: T,
        
        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }
        
        /// Convert the vector to a different type.
        pub fn toVec2(self: Self, comptime ToComponentT: type) Vec2(ToComponentT) {
            if(comptime(ToComponentT == T)) {
                return self;
            }
            else if(comptime(gba.math.isFixedPointType(ToComponentT))) {
                return .init(
                    .fromInt(@intCast(self.x)),
                    .fromInt(@intCast(self.y)),
                );
            }
            else {
                return .init(
                    @intCast(self.x),
                    @intCast(self.y),
                );
            }
        }
        
        /// Returns true when both components of the vector are zero.
        pub fn isZero(self: Self) bool {
            return self.x == 0 and self.y == 0;
        }
        
        /// Get the squared magnitude of the vector, i.e. the length of
        /// the hypotenuse of the triangle formed by this vector.
        pub fn hypotSq(self: Self) T {
            return self.x * self.x + self.y * self.y;
        }
        
        /// Computes the arctangent of `y / x`.
        /// Calls `gba.bios.arctan2`.
        pub fn atan2(self: Self) gba.math.FixedU16R16 {
            return gba.bios.arctan2(@intCast(self.x), @intCast(self.y));
        }
        
        /// Add two vectors.
        pub fn add(a: Self, b: Self) Self {
            return .{ .x = a.x + b.x, .y = a.y + b.y };
        }
        
        /// Subtract vector `b` from vector `a`.
        pub fn sub(a: Self, b: Self) Self {
            return .{ .x = a.x - b.x, .y = a.y - b.y };
        }
        
        /// Multiply both components of a vector by a scalar value.
        pub fn scale(self: Self, scalar: T) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar };
        }
        
        /// Check if two vectors are equal.
        pub fn eql(a: Self, b: Self) Self {
            return a.x == b.x and a.y == b.y;
        }
    };
}

/// Two-dimensional vector with signed 8-bit integer components.
pub const Vec2I8 = Vec2I(i8);

/// Two-dimensional vector with signed 16-bit integer components.
pub const Vec2I16 = Vec2I(i16);

/// Two-dimensional vector with signed 32-bit integer components.
pub const Vec2I32 = Vec2I(i32);

/// Two-dimensional vector with unsigned 8-bit integer components.
pub const Vec2U8 = Vec2U(u8);

/// Two-dimensional vector with unsigned 16-bit integer components.
pub const Vec2U16 = Vec2U(u16);

/// Two-dimensional vector with unsigned 32-bit integer components.
pub const Vec2U32 = Vec2U(u32);

/// Two-dimensional vector with fixed point components.
pub const Vec2FixedI16R8 = Vec2FixedI(gba.math.FixedI16R8);

/// Two-dimensional vector with fixed point components.
pub const Vec2FixedI32R8 = Vec2FixedI(gba.math.FixedI32R8);

/// Two-dimensional vector with fixed point components.
pub const Vec2FixedI32R16 = Vec2FixedI(gba.math.FixedI32R16);
