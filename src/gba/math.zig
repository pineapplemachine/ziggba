//! This module contains math-related helpers.

const isGbaTarget = @import("util.zig").isGbaTarget;

test {
    _ = @import("math_fixed.zig");
}

extern fn umull_thumb(x: u32, y: u32) UnsignedMulLongResult;
extern fn smull_thumb(x: i32, y: i32) SignedMulLongResult;

// Affine transformation matrix types.
pub const Affine2x2 = @import("math_affine.zig").Affine2x2;
pub const Affine3x2 = @import("math_affine.zig").Affine3x2;

// Fixed-point math types.
pub const isFixedPointType = @import("math_fixed.zig").isFixedPointType;
pub const isSignedFixedPointType = @import("math_fixed.zig").isSignedFixedPointType;
pub const isUnsignedFixedPointType = @import("math_fixed.zig").isUnsignedFixedPointType;
pub const FormatDecimalFixedOptions = @import("math_fixed.zig").FormatDecimalFixedOptions;
pub const sin_lut = @import("math_fixed.zig").sin_lut;
pub const FixedU16R16 = @import("math_fixed.zig").FixedU16R16;
pub const FixedI = @import("math_fixed.zig").FixedI;
pub const FixedI16R8 = @import("math_fixed.zig").FixedI16R8;
pub const FixedI16R14 = @import("math_fixed.zig").FixedI16R14;
pub const FixedI32R8 = @import("math_fixed.zig").FixedI32R8;
pub const FixedI32R16 = @import("math_fixed.zig").FixedI32R16;

// 2x2 matrix types.
pub const Mat2x2 = @import("math_mat2x2.zig").Mat2x2;
pub const Mat2x2I = @import("math_mat2x2.zig").Mat2x2I;
pub const Mat2x2FixedI16R8 = @import("math_mat2x2.zig").Mat2x2FixedI16R8;
pub const Mat2x2FixedI32R8 = @import("math_mat2x2.zig").Mat2x2FixedI32R8;
pub const Mat2x2FixedI32R16 = @import("math_mat2x2.zig").Mat2x2FixedI32R16;

// 3x3 matrix types.
pub const Mat3x3 = @import("math_mat3x3.zig").Mat3x3;
pub const Mat3x3I = @import("math_mat3x3.zig").Mat3x3I;
pub const Mat3x3FixedI16R8 = @import("math_mat3x3.zig").Mat3x3FixedI16R8;
pub const Mat3x3FixedI32R8 = @import("math_mat3x3.zig").Mat3x3FixedI32R8;
pub const Mat3x3FixedI32R16 = @import("math_mat3x3.zig").Mat3x3FixedI32R16;

// Rectangle types.
pub const Rect = @import("math_rect.zig").Rect;
pub const RectI8 = @import("math_rect.zig").RectI8;
pub const RectU8 = @import("math_rect.zig").RectU8;
pub const RectI16 = @import("math_rect.zig").RectI16;
pub const RectU16 = @import("math_rect.zig").RectU16;
pub const RectI32 = @import("math_rect.zig").RectI32;
pub const RectU32 = @import("math_rect.zig").RectU32;

// 2-vector types.
pub const Vec2 = @import("math_vec2.zig").Vec2;
pub const Vec2B = @import("math_vec2.zig").Vec2B;
pub const Vec2I = @import("math_vec2.zig").Vec2I;
pub const Vec2U = @import("math_vec2.zig").Vec2U;
pub const Vec2I8 = @import("math_vec2.zig").Vec2I8;
pub const Vec2I16 = @import("math_vec2.zig").Vec2I16;
pub const Vec2I32 = @import("math_vec2.zig").Vec2I32;
pub const Vec2U8 = @import("math_vec2.zig").Vec2U8;
pub const Vec2U16 = @import("math_vec2.zig").Vec2U16;
pub const Vec2U32 = @import("math_vec2.zig").Vec2U32;
pub const Vec2FixedI16R8 = @import("math_vec2.zig").Vec2FixedI16R8;
pub const Vec2FixedI32R8 = @import("math_vec2.zig").Vec2FixedI32R8;
pub const Vec2FixedI32R16 = @import("math_vec2.zig").Vec2FixedI32R16;

// 3-vector types
pub const Vec3 = @import("math_vec3.zig").Vec3;
pub const Vec3I = @import("math_vec3.zig").Vec3I;
pub const Vec3I8 = @import("math_vec3.zig").Vec3I8;
pub const Vec3I16 = @import("math_vec3.zig").Vec3I16;
pub const Vec3I32 = @import("math_vec3.zig").Vec3I32;
pub const Vec3FixedI16R8 = @import("math_vec3.zig").Vec3FixedI16R8;
pub const Vec3FixedI32R8 = @import("math_vec3.zig").Vec3FixedI32R8;
pub const Vec3FixedI32R16 = @import("math_vec3.zig").Vec3FixedI32R16;

// TODO: Vec4 types
// TODO: Mat4x4 types
// TODO: Complex type

/// Returns true when the given type is an integer primitive type,
/// signed or unsigned.
pub fn isIntPrimitiveType(comptime T: type) bool {
    return switch(@typeInfo(T)) {
        .int => true,
        else => false,
    };
}

/// Returns true when the given type is a signed integer primitive type.
pub fn isSignedIntPrimitiveType(comptime T: type) bool {
    return comptime(switch(@typeInfo(T)) {
        .int => |int_info| int_info.signedness == .signed,
        else => false,
    });
}

/// Returns true when the given type is an usigned integer primitive type.
pub fn isUnsignedIntPrimitiveType(comptime T: type) bool {
    return comptime(switch(@typeInfo(T)) {
        .int => |int_info| int_info.signedness == .unsigned,
        else => false,
    });
}

/// Get the signed int primitive type with a given number of bits.
/// For example, pass a `bits` value of 32 to get `i32`.
pub fn getSignedIntPrimitiveType(comptime bits: comptime_int) type {
    return @Type(.{
        .int = .{ .signedness = .signed, .bits = bits },
    });
}

/// Get the unsigned int primitive type with a given number of bits.
/// For example, pass a `bits` value of 32 to get `u32`.
pub fn getUnsignedIntPrimitiveType(comptime bits: comptime_int) type {
    return @Type(.{
        .int = .{ .signedness = .signed, .bits = bits },
    });
}

/// Represents the product returned by `unsignedMulLong`.
pub const UnsignedMulLongResult = extern struct {
    /// Low 32 bits of the product.
    lo: u32,
    /// High 32 bits of the product.
    hi: u32,
};

/// Represents the product returned by `signedMulLong`.
pub const SignedMulLongResult = extern struct {
    /// Low 32 bits of the product.
    lo: i32,
    /// High 32 bits of the product.
    hi: i32,
};

/// Unsigned multiply long.
/// Multiply two unsigned integers and get the 64-bit product.
pub inline fn unsignedMulLong(x: u32, y: u32) UnsignedMulLongResult {
    if(comptime(!isGbaTarget())) {
        const product = @as(u64, x) * @as(u64, y);
        return .{
            .lo = @truncate(product),
            .hi = @truncate(product >> 32),
        };
    }
    else {
        return umull_thumb(x, y);
    }
}

/// Signed multiply long.
/// Multiply two unsigned integers and get the 64-bit product.
pub inline fn signedMulLong(x: i32, y: i32) SignedMulLongResult {
    if(comptime(!isGbaTarget())) {
        const product = @as(i64, x) * @as(i64, y);
        return .{
            .lo = @truncate(product),
            .hi = @truncate(product >> 32),
        };
    }
    else {
        return smull_thumb(x, y);
    }
}

/// Generic function that works for both integer primitives
/// and fixed point values.
pub inline fn zero(comptime T: type) T {
    if(comptime(isIntPrimitiveType(T))) {
        return 0;
    }
    else if(comptime(isFixedPointType(T))) {
        return .zero;
    }
    else {
        @compileError(
            "Operation is not supported for this type: " ++ @typeName(T)
        );
    }
}

/// Generic function that works for both integer primitives
/// and fixed point values.
pub inline fn one(comptime T: type) T {
    if(comptime(isIntPrimitiveType(T))) {
        return 1;
    }
    else if(comptime(isFixedPointType(T) and @hasDecl(T, "toInt"))) {
        return .one;
    }
    else {
        @compileError(
            "Operation is not supported for this type: " ++ @typeName(T)
        );
    }
}

/// Generic function that works for both signed integer primitives
/// and signed fixed point values.
pub inline fn negativeOne(comptime T: type) T {
    if(comptime(isSignedIntPrimitiveType(T))) {
        return -1;
    }
    else if(comptime(isSignedFixedPointType(T))) {
        return .negative_one;
    }
    else {
        @compileError(
            "Operation is not supported for this type: " ++ @typeName(T)
        );
    }
}

/// Generic negation function that works on both signed integer primitives
/// and signed fixed point values.
pub inline fn negate(comptime T: type, value: T) T {
    if(comptime(isSignedFixedPointType(T))) {
        return value.negate();
    }
    else {
        return -value;
    }
}

/// Generic logical bit shift left function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift by must be known at comptime.
pub inline fn lsl(comptime T: type, value: T, comptime bits: comptime_int) T {
    if(comptime(isFixedPointType(T))) {
        return value.lsl(bits);
    }
    else {
        return value << bits;
    }
}

/// Generic logical bit shift right function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift by must be known at comptime.
pub inline fn lsr(comptime T: type, value: T, comptime bits: comptime_int) T {
    if(comptime(isFixedPointType(T))) {
        return value.lsr(bits);
    }
    else if(comptime(isUnsignedIntPrimitiveType(T))) {
        return value >> bits;
    }
    else {
        const UnsignedT = getUnsignedIntPrimitiveType(@bitSizeOf(T));
        const i_value: UnsignedT = @bitCast(value);
        return @bitCast(i_value >> bits);
    }
}

/// Generic arithmetic bit shift right function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift by must be known at comptime.
pub inline fn asr(comptime T: type, value: T, comptime bits: comptime_int) T {
    if(comptime(isFixedPointType(T))) {
        return value.lsr(bits);
    }
    else if(comptime(isSignedIntPrimitiveType(T))) {
        return value >> bits;
    }
    else {
        const SignedT = getSignedIntPrimitiveType(@bitSizeOf(T));
        const i_value: SignedT = @bitCast(value);
        return @bitCast(i_value >> bits);
    }
}

/// Generic logical bit shift left function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift can be a variable.
pub inline fn lslVar(comptime T: type, value: T, bits: anytype) T {
    if(comptime(isFixedPointType(T))) {
        return value.lslVar(bits);
    }
    else {
        return value << bits;
    }
}

/// Generic logical bit shift right function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift can be a variable.
pub inline fn lsrVar(comptime T: type, value: T, bits: anytype) T {
    if(comptime(isFixedPointType(T))) {
        return value.lsrVar(bits);
    }
    else if(comptime(isUnsignedIntPrimitiveType(T))) {
        return value >> bits;
    }
    else {
        const UnsignedT = getUnsignedIntPrimitiveType(@bitSizeOf(T));
        const i_value: UnsignedT = @bitCast(value);
        return @bitCast(i_value >> bits);
    }
}

/// Generic arithmetic bit shift right function that works on both
/// integer primitives and fixed point values.
/// The number of bits to shift can be a variable.
pub inline fn asrVar(comptime T: type, value: T, bits: anytype) T {
    if(comptime(isFixedPointType(T))) {
        return value.lsrVar(bits);
    }
    else if(comptime(isSignedIntPrimitiveType(T))) {
        return value >> bits;
    }
    else {
        const SignedT = getSignedIntPrimitiveType(@bitSizeOf(T));
        const i_value: SignedT = @bitCast(value);
        return @bitCast(i_value >> bits);
    }
}

/// Generic addition function that works on both integer primitives
/// and fixed point values.
pub inline fn add(comptime T: type, a: T, b: T) T {
    if(comptime(isFixedPointType(T))) {
        return a.add(b);
    }
    else {
        return a + b;
    }
}

/// Generic subtract function that works on both integer primitives
/// and fixed point values.
pub inline fn sub(comptime T: type, a: T, b: T) T {
    if(comptime(isFixedPointType(T))) {
        return a.sub(b);
    }
    else {
        return a - b;
    }
}

/// Generic multiply function that works on both integer primitives
/// and fixed point values.
pub inline fn mul(comptime T: type, a: T, b: T) T {
    if(comptime(isFixedPointType(T))) {
        return a.mul(b);
    }
    else {
        return a * b;
    }
}

/// Generic comparison function that works on both integer primitives
/// and fixed point values.
pub inline fn eql(comptime T: type, a: T, b: T) T {
    if(comptime(isFixedPointType(T))) {
        return a.eql(b);
    }
    else {
        return a * b;
    }
}
