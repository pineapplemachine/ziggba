//! This module implements fixed-point math helpers.
//!
//! Note that fixed point types, e.g. `FixedI16R8`, are named for their
//! width (16 bits) and radix (2^8).
//!
//! The `FixedI16R8` type is used for the GBA's affine transformation
//! matrix components.
//!
//! The `FixedI16R14` type is used by the GBA BIOS for inputs to the
//! `ArcTan` and `ArcTan2` BIOS calls.
//!
//! The `FixedU16R16` type is used by the GBA BIOS to represent angles
//! in the `BgAffineSet` and `ObjAffineSet` BIOS calls. In most cases,
//! it is an ideal choice to represent angles of rotation.
//! Accordingly, it comes with an easy API for computing trigonometric
//! functions.
//!
//! The `FixedI32R8` type is used for the GBA's displacement vector for
//! background affine transformations, and is also used to represent
//! displacement for the `BgAffineSet` BIOS call.
//!
//! The `FixedI32R16` type is not used by the GBA hardware or BIOS.
//! It is provided for convenience, as a good general purpose fixed point
//! data type, especially for intermediate computations in constructing
//! affine transformation matrices.

const gba = @import("gba.zig");

test {
    _ = @import("test/fixed_trig.zig");
}

/// Stores `sine(x) * 0x10000` in 256 steps over the range `[0, pi/2)` radians.
/// This can be used to trivially compute sine and cosine for arbitary inputs.
pub const sin_lut: [256]u16 = blk: {
    // TODO: It would be nice if there were a build option to specify the
    // size of this LUT, or to omit it entirely.
    @setEvalBranchQuota(10000);
    var lut: [256]u16 = undefined;
    for (0..lut.len) |i| {
        const sin_value = @sin(
            (@as(f64, @floatFromInt(i)) / 256.0) *
            (1.5707963267948966) // half pi
        );
        lut[i] = @intFromFloat(sin_value * 0x10000);
    }
    break :blk lut;
};

/// Helper for retrieving a value from the `sin_lut` trig lookup table.
/// Uses trivial trigonometric identities to map all angles onto the
/// `[0, pi/2)` range covered by the LUT.
/// Simply returns one of the two nearest LUT values, without interpolation.
/// Returns a value in the range `[-0x10000, +0x10000]`.
fn sinRevolutionsStepped(value: u16) i32 {
    if(value <= 0) { // Zero
        // sin(0) == 0
        return 0;
    }
    else if(value < 0x4000) { // Less than a quarter turn
        return sin_lut[value >> 6];
    }
    else if(value == 0x4000) { // Exactly a quarter turn
        // sin(pi/2) == +1
        return 0x10000;
    }
    else if(value < 0x8000) { // Less than a half turn
        // sin(x) == sin(pi - x)
        const v2 = 0x8000 - value;
        return sin_lut[v2 >> 6];
    }
    else if(value == 0x8000) { // Exactly a half turn
        // sin(pi) == 0
        return 0;
    }
    else if(value < 0xc000) { // Less than three quarters turn
        // sin(x) == -sin(x - pi)
        const v2 = value - 0x8000;
        return -@as(i32, sin_lut[v2 >> 6]);
    }
    else if(value == 0xc000) { // Exactly three quarters turn
        // sin(3*pi/4) == -1
        return -0x10000;
    }
    else { // Less than a full turn
        // sin(x) == -sin(2*pi - x)
        const v2 = 0x10000 - @as(u32, value);
        return -@as(i32, sin_lut[v2 >> 6]);
    }
}

/// This helper encapsulates the `sinRevolutionsStepped` helper to return a
/// result interpolated between the nearest two LUT values. (Uses lerp.)
fn sinRevolutionsLerp(value: u16) i32 {
    const t = value & 0x3f;
    const val_lo = value & 0xffc0;
    const sin_lo = sinRevolutionsStepped(val_lo);
    if(t == 0) {
        return sin_lo;
    }
    const sin_hi = sinRevolutionsStepped(val_lo +% 0x40);
    const sin_delta = sin_hi - sin_lo;
    return sin_lo + ((sin_delta * t) >> 6);
}

/// Fixed point number type. Signed, width 16 bits, radix 8 bits.
/// The GBA hardware uses values of this type to represent the components
/// of affine transformation matrices.
pub const FixedI16R8 = packed struct(i16) {
    value: i16 = 0,
    
    pub inline fn initRaw(raw_value: i16) FixedI16R8 {
        return FixedI16R8{ .value = raw_value };
    }
    
    pub inline fn initInt(int_value: i8) FixedI16R8 {
        return FixedI16R8.initRaw(@as(i16, int_value) << 8);
    }
    
    pub fn initFloat32(comptime value: f32) FixedI16R8 {
        return FixedI16R8.initRaw(@intFromFloat(value * 0x100));
    }
    
    pub inline fn toInt(self: FixedI16R8) i8 {
        return @intCast(self.value >> 8);
    }
    
    pub inline fn toI32R16(self: FixedI32R16) FixedI32R16 {
        return FixedI32R16.initRaw(@as(i32, self.value) << 8);
    }
    
    pub inline fn toU16R16(self: FixedI16R8) FixedU16R16 {
        return FixedU16R16.initRaw(self.value << 8);
    }
    
    pub inline fn toI32R8(self: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(@intCast(self.value));
    }
    
    pub inline fn negate(self: FixedI16R8) FixedI16R8 {
        return FixedI16R8.initRaw(-self.value);
    }
    
    pub inline fn abs(self: FixedI16R8) FixedI16R8 {
        return if(self.value >= 0) self else FixedI16R8.initRaw(-self.value);
    }
    
    pub inline fn add(a: FixedI16R8, b: FixedI16R8) FixedI16R8 {
        return FixedI16R8.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedI16R8, b: FixedI16R8) FixedI16R8 {
        return FixedI16R8.initRaw(a.value - b.value);
    }
    
    pub fn mul(a: FixedI16R8, b: FixedI16R8) FixedI16R8 {
        return FixedI16R8.initRaw(@truncate(
            (@as(i32, a.value) * @as(i32, b.value)) >> 16
        ));
    }
    
    pub fn div(a: FixedI16R8, b: FixedI16R8) FixedI16R8 {
        const qr = gba.bios.div(@as(i32, a.value) << 8, b.value);
        return FixedI16R8.initRaw(qr.quotient);
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: FixedI16R8, b: FixedI16R8) bool {
        return a.value == b.value;
    }
    
    pub inline fn lessThan(a: FixedI16R8, b: FixedI16R8) bool {
        return a.value < b.value;
    }
    
    pub inline fn greaterThan(a: FixedI16R8, b: FixedI16R8) bool {
        return a.value > b.value;
    }
    
    pub inline fn lessOrEqual(a: FixedI16R8, b: FixedI16R8) bool {
        return a.value <= b.value;
    }
    
    pub inline fn greaterOrEqual(a: FixedI16R8, b: FixedI16R8) bool {
        return a.value <= b.value;
    }
};

/// Fixed point number type. Signed, width 16 bits, radix 14 bits.
/// The GBA BIOS uses this type in arctangent calculations.
pub const FixedI16R14 = packed struct(i16) {
    value: i16 = 0,
    
    pub inline fn initRaw(raw_value: i16) FixedI16R14 {
        return FixedI16R14{ .value = raw_value };
    }
    
    pub inline fn initInt(int_value: i2) FixedI16R14 {
        return FixedI16R14.initRaw(@as(i16, int_value) << 14);
    }
    
    pub fn initFloat32(comptime value: f32) FixedI16R14 {
        return FixedI16R14.initRaw(@intFromFloat(value * 0x4000));
    }
    
    pub fn initFloat64(comptime value: f64) FixedI16R14 {
        return FixedI16R14.initRaw(@intFromFloat(value * 0x4000));
    }
    
    pub inline fn toInt(self: FixedI16R14) i2 {
        return @intCast(self.value >> 14);
    }
    
    pub inline fn toI16R8(self: FixedI16R14) FixedI16R8 {
        return FixedI16R8.initRaw(self.value >> 6);
    }
    
    pub inline fn toI32R16(self: FixedI16R14) FixedI32R16 {
        return FixedI32R16.initRaw(@as(i32, self.value) << 2);
    }
    
    pub inline fn toU16R16(self: FixedI16R14) FixedU16R16 {
        return FixedU16R16.initRaw(self.value << 2);
    }
    
    pub inline fn toI32R8(self: FixedI16R14) FixedI32R8 {
        return FixedI32R8.initRaw(@as(i32, self.value) >> 6);
    }
    
    pub inline fn negate(self: FixedI16R14) FixedI16R14 {
        return FixedI16R14.initRaw(-self.value);
    }
    
    pub inline fn abs(self: FixedI16R14) FixedI16R14 {
        return if(self.value >= 0) self else FixedI16R14.initRaw(-self.value);
    }
    
    pub inline fn add(a: FixedI16R14, b: FixedI16R14) FixedI16R14 {
        return FixedI16R14.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedI16R14, b: FixedI16R14) FixedI16R14 {
        return FixedI16R14.initRaw(a.value - b.value);
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: FixedI16R14, b: FixedI16R14) bool {
        return a.value == b.value;
    }
    
    pub inline fn lessThan(a: FixedI16R14, b: FixedI16R14) bool {
        return a.value < b.value;
    }
    
    pub inline fn greaterThan(a: FixedI16R14, b: FixedI16R14) bool {
        return a.value > b.value;
    }
    
    pub inline fn lessOrEqual(a: FixedI16R14, b: FixedI16R14) bool {
        return a.value <= b.value;
    }
    
    pub inline fn greaterOrEqual(a: FixedI16R14, b: FixedI16R14) bool {
        return a.value <= b.value;
    }
};

/// Fixed point number type. Unsigned, width 16 bits, radix 16 bits.
/// Note that this is a particularly suitable type for representing angles
/// of rotation, measured in revolutions.
///
/// The GBA BIOS uses values of this type to represent angle inputs to
/// the `BgAffineSet` and `ObjAffineSet` functions, as well as angle outputs
/// from the `ArcTan` and `ArcTan2` functions.
pub const FixedU16R16 = packed struct(u16) {
    value: u16 = 0,
    
    pub inline fn initRaw(raw_value: u16) FixedU16R16 {
        return FixedU16R16{ .value = raw_value };
    }
    
    pub fn initFloat32(comptime value: f32) FixedU16R16 {
        return FixedU16R16.initRaw(@intFromFloat(value * 0x10000));
    }
    
    pub fn initFloat64(comptime value: f64) FixedU16R16 {
        return FixedU16R16.initRaw(@intFromFloat(value * 0x10000));
    }
    
    /// Initialize an angle, converting from degrees.
    /// FixedU16R16 internally represents angles as revolutions.
    pub fn initDegrees(comptime deg: f64) FixedU16R16 {
        return FixedU16R16.initFloat64(@mod(deg / 360.0, 1.0));
    }
    
    /// Initialize an angle, converting from radians.
    /// FixedU16R16 internally represents angles as revolutions.
    pub fn initRadians(comptime rad: f64) FixedU16R16 {
        return FixedU16R16.initFloat64(@mod(rad / 6.283185307179586, 1.0));
    }
    
    pub inline fn toI16R8(self: FixedU16R16) FixedU16R16 {
        return FixedI16R8.initRaw(self.value >> 8);
    }
    
    pub inline fn toI32R8(self: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(self.value >> 8);
    }
    
    pub inline fn toI32R16(self: FixedI32R8) FixedI32R16 {
        return FixedI32R16.initRaw(self.value);
    }
    
    /// Invert this value.
    /// For angles, this is equivalent to adding 180 degrees.
    pub inline fn invert(self: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(self.value +% 0x8000);
    }
    
    pub inline fn add(a: FixedU16R16, b: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedU16R16, b: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(a.value - b.value);
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: FixedU16R16, b: FixedU16R16) bool {
        return a.value == b.value;
    }
    
    pub inline fn lessThan(a: FixedU16R16, b: FixedU16R16) bool {
        return a.value < b.value;
    }
    
    pub inline fn greaterThan(a: FixedU16R16, b: FixedU16R16) bool {
        return a.value > b.value;
    }
    
    pub inline fn lessOrEqual(a: FixedU16R16, b: FixedU16R16) bool {
        return a.value <= b.value;
    }
    
    pub inline fn greaterOrEqual(a: FixedU16R16, b: FixedU16R16) bool {
        return a.value <= b.value;
    }
    
    /// Compute the sine of an angle, measured in revolutions.
    ///
    /// This implementation uses a lookup table allowing for 1024 discrete
    /// results from 0 to a full turn. It does not perform interpolation.
    pub inline fn sinFast(self: FixedU16R16) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsStepped(self.value));
    }
    
    /// Compute the cosine of an angle, measured in revolutions.
    ///
    /// This implementation uses a lookup table allowing for 1024 discrete
    /// results from 0 to a full turn. It does not perform interpolation.
    pub inline fn cosFast(self: FixedU16R16) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsStepped(self.value +% 0x4000));
    }
    
    /// Compute the sine of an angle, measured in revolutions.
    ///
    /// This implementation interpolates between values in a LUT, meaning
    /// it produces a smoother curve with less error compared to `sin_fast`.
    /// However, this extra computation costs a little extra performance.
    pub inline fn sinLerp(self: FixedU16R16) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsLerp(self.value));
    }
    
    /// Compute the cosine of an angle, measured in revolutions.
    ///
    /// This implementation interpolates between values in a LUT, meaning
    /// it produces a smoother curve with less error compared to `cos_fast`.
    /// However, this extra computation costs a little extra performance.
    pub inline fn cosLerp(self: FixedU16R16) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsLerp(self.value +% 0x4000));
    }
    
    /// Convert an angle to degrees.
    pub fn degrees(self: FixedU16R16) FixedI32R16 {
        return FixedI32R16.initRaw(360 * @as(i32, self.value));
    }
};

/// Fixed point number type. Signed, width 32 bits, radix 8 bits.
/// The GBA hardware uses values of this type to represent the
/// displacement vector components of a background's affine transformation.
pub const FixedI32R8 = packed struct(i32) {
    value: i32 = 0,
    
    pub inline fn initRaw(raw_value: i32) FixedI32R8 {
        return FixedI32R8{ .value = raw_value };
    }
    
    pub inline fn initInt(int_value: i16) FixedI32R8 {
        return FixedI32R8.initRaw(@as(i32, int_value) << 8);
    }
    
    pub fn initFloat32(comptime value: f32) FixedI32R8 {
        return FixedI32R8.initRaw(@intFromFloat(value * 0x100));
    }
    
    pub fn initFloat64(comptime value: f64) FixedI32R8 {
        return FixedI32R8.initRaw(@intFromFloat(value * 0x100));
    }
    
    pub inline fn toInt(self: FixedI32R8) i16 {
        return @intCast(self.value >> 16);
    }
    
    pub inline fn toI16R8(self: FixedI32R8) FixedI16R8 {
        return FixedI16R8.initRaw(@intCast(self.value));
    }
    
    pub inline fn toU16R16(self: FixedI32R8) FixedU16R16 {
        return FixedU16R16.initRaw(@intCast((self.value & 0xff) << 8));
    }
    
    pub inline fn toI32R16(self: FixedI32R8) FixedI32R16 {
        return FixedI16R8.initRaw(@intCast(self.value << 8));
    }
    
    pub inline fn negate(self: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(-self.value);
    }
    
    pub inline fn abs(self: FixedI32R8) FixedI32R8 {
        return if(self.value >= 0) self else FixedI32R8.initRaw(-self.value);
    }
    
    pub inline fn add(a: FixedI32R8, b: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedI32R8, b: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(a.value - b.value);
    }
    
    pub fn mul(a: FixedI32R8, b: FixedI32R8) FixedI32R8 {
        // https://stackoverflow.com/a/1815371
        var x: i32 = (a.value & 0xffff) * (b.value & 0xffff);
        x = (a.value >> 16) * (b.value & 0xffff) + (x >> 16);
        const s1 = x & 0xffff;
        const s2 = x >> 16;
        x = s1 + (a.value & 0xffff) * (b.value >> 16);
        x = s2 + (a.value >> 16) * (b.value >> 16) + (x >> 16);
        return FixedI32R8.initRaw((x << 16) | s1);
        // TODO: Sometime figure out how to make this work using the
        // very likely more performant `smull` ARM instruction.
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: FixedI32R8, b: FixedI32R8) bool {
        return a.value == b.value;
    }
    
    pub inline fn lessThan(a: FixedI32R8, b: FixedI32R8) bool {
        return a.value < b.value;
    }
    
    pub inline fn greaterThan(a: FixedI32R8, b: FixedI32R8) bool {
        return a.value > b.value;
    }
    
    pub inline fn lessOrEqual(a: FixedI32R8, b: FixedI32R8) bool {
        return a.value <= b.value;
    }
    
    pub inline fn greaterOrEqual(a: FixedI32R8, b: FixedI32R8) bool {
        return a.value <= b.value;
    }
};

/// Fixed point number type. Signed, width 32 bits, radix 16 bits.
pub const FixedI32R16 = packed struct(i32) {
    value: i32 = 0,
    
    pub inline fn initRaw(raw_value: i32) FixedI32R16 {
        return FixedI32R16{ .value = raw_value };
    }
    
    pub inline fn initInt(int_value: i16) FixedI32R16 {
        return FixedI32R16.initRaw(@as(i32, int_value) << 16);
    }
    
    pub fn initFloat32(comptime value: f32) FixedI32R16 {
        return FixedI32R16.initRaw(@intFromFloat(value * 0x10000));
    }
    
    pub fn initFloat64(comptime value: f64) FixedI32R16 {
        return FixedI32R16.initRaw(@intFromFloat(value * 0x10000));
    }
    
    pub inline fn toInt(self: FixedI32R16) i16 {
        return @intCast(self.value >> 16);
    }
    
    pub inline fn toI16R8(self: FixedI32R16) FixedI16R8 {
        return FixedI16R8.initRaw(@intCast(self.value >> 8));
    }
    
    pub inline fn toU16R16(self: FixedI32R16) FixedU16R16 {
        return FixedU16R16.initRaw(@intCast(self.value & 0xffff));
    }
    
    pub inline fn toI32R8(self: FixedI32R8) FixedI32R8 {
        return FixedI32R8.initRaw(@intCast(self.value >> 8));
    }
    
    pub inline fn negate(self: FixedI32R16) FixedI32R16 {
        return FixedI32R16.initRaw(-self.value);
    }
    
    pub inline fn abs(self: FixedI32R16) FixedI32R16 {
        return if(self.value >= 0) self else FixedI32R16.initRaw(-self.value);
    }
    
    pub inline fn add(a: FixedI32R16, b: FixedI32R16) FixedI32R16 {
        return FixedI32R16.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedI32R16, b: FixedI32R16) FixedI32R16 {
        return FixedI32R16.initRaw(a.value - b.value);
    }
    
    pub fn mul(a: FixedI32R16, b: FixedI32R16) FixedI32R16 {
        // https://stackoverflow.com/a/1815371
        var x: i32 = (a.value & 0xffff) * (b.value & 0xffff);
        x = (a.value >> 16) * (b.value & 0xffff) + (x >> 16);
        const s1 = x & 0xffff;
        const s2 = x >> 16;
        x = s1 + (a.value & 0xffff) * (b.value >> 16);
        x = s2 + (a.value >> 16) * (b.value >> 16) + (x >> 16);
        return FixedI32R16.initRaw(x);
        // TODO: Sometime figure out how to make this work using the
        // very likely more performant `smull` ARM instruction.
        // var product_lo: i32 = undefined;
        // var product_hi: i32 = undefined;
        // asm volatile (
        //     \\ .arm
        //     \\ smull r2, r3, r0, r1
        //     : [product_lo] "={r2}" (product_lo),
        //       [product_hi] "={r3}" (product_hi),
        //     : [a.value] "={r0}" (a.value),
        //       [b.value] "={r1}" (b.value),
        // );
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: FixedI32R16, b: FixedI32R16) bool {
        return a.value == b.value;
    }
    
    pub inline fn lessThan(a: FixedI32R16, b: FixedI32R16) bool {
        return a.value < b.value;
    }
    
    pub inline fn greaterThan(a: FixedI32R16, b: FixedI32R16) bool {
        return a.value > b.value;
    }
    
    pub inline fn lessOrEqual(a: FixedI32R16, b: FixedI32R16) bool {
        return a.value <= b.value;
    }
    
    pub inline fn greaterOrEqual(a: FixedI32R16, b: FixedI32R16) bool {
        return a.value <= b.value;
    }
};
