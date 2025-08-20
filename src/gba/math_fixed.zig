//! This module implements fixed-point math helpers.
//!
//! Note that fixed point types, e.g. `FixedI16R8`, are named for their
//! width (16 bits) and radix (2^8).
//!
//! The `FixedI16R8` type is used for the GBA's affine transformation
//! matrix components.
//!
//! The `FixedI16R14` type is used by the GBA BIOS for input to the
//! `ArcTan` BIOS call.
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
const assert = @import("std").debug.assert;
const isGbaTarget = @import("util.zig").isGbaTarget;

extern var FixedI32R8_mul_arm: u8;
extern var FixedI32R16_mul_arm: u8;

test {
    _ = @import("test/math_fixed_format.zig");
    _ = @import("test/math_fixed_math.zig");
    _ = @import("test/math_fixed_trig.zig");
}

/// Returns true when the given type is a fixed point type.
pub fn isFixedPointType(comptime T: type) bool {
    return @hasField(T, "is_fixed_point_type");
}

/// Returns true when the given type is a signed fixed point type.
pub fn isSignedFixedPointType(comptime T: type) bool {
    return (
        @hasField(T, "is_fixed_point_type") and
        @hasField(T, "is_signed_fixed_point_type")
    );
}

/// Returns true when the given type is an unsigned fixed point type.
pub fn isUnsignedFixedPointType(comptime T: type) bool {
    return (
        @hasField(T, "is_fixed_point_type") and
        !@hasField(T, "is_signed_fixed_point_type")
    );
}

pub const FormatDecimalFixedOptions = struct {
    /// Array of decimal digits, e.g. `'0'...'9'`.
    decimal_digits: [10]u8 = gba.format.decimal_digits_ascii,
    /// This character is prepended to negative numbers.
    sign_negative_char: u8 = '-',
    /// This character may be prepended to positive numbers, if `always_sign`
    /// is true.
    sign_positive_char: u8 = '+',
    /// Always prepend a `sign_positive_char` for non-negative numbers,
    /// not only `sign_negative_char` for negative ones.
    always_sign: bool = false,
    /// If the output string would be shorter than this many bytes,
    /// prepend enough `pad_left_char` to match this padded length.
    pad_left_len: u8 = 0,
    /// Padding byte, for use with `pad_left_len`.
    pad_left_char: u8 = ' ',
    /// If true, then padding is applied only to the integer part
    /// of the number string, instead of to the entire thing.
    /// This can be used, for example, to align decimals.
    pad_left_int: bool = false,
    /// Pad the fractional part with zeros to have at least this many
    /// digits.
    min_fraction_digits: u8 = 0,
    /// Truncate the fractional part to not have more than this many
    /// digits.
    max_fraction_digits: u8 = 8,
    /// This character is used for the decimal point.
    decimal_char: u8 = '.',
};

/// Format a FixedI32R8 value as a decimal string.
fn formatDecimalFixedI32R8(
    self: FixedI32R8,
    buffer: [*]volatile u8,
    options: FormatDecimalFixedOptions,
) u32 {
    const int_value: i32 = (self.value >> 8) + @as(i32, (
        if(self.value < 0 and (self.value & 0xff) != 0) 1 else 0
    ));
    const int_len = gba.format.formatDecimalI32(buffer, int_value, .{
        .decimal_digits = options.decimal_digits,
        .sign_negative_char = options.sign_negative_char,
        .sign_positive_char = options.sign_positive_char,
        .always_sign = options.always_sign,
        .pad_left_len = if(options.pad_left_int) options.pad_left_len else 0,
        .pad_left_char = options.pad_left_char,
    });
    // 1/256 == 0.00390625
    const frac_value: i32 = 390625 * @as(i32, (
        if(self.value >= 0) self.value & 0xff
        else (0x100 -% self.value) & 0xff
    ));
    var total_len: u32 = int_len;
    if(frac_value > 0 or options.min_fraction_digits > 0) {
        buffer[int_len] = options.decimal_char;
        const frac_buffer = buffer + int_len + 1;
        var frac_len = gba.format.formatDecimalI32(frac_buffer, frac_value, .{
            .decimal_digits = options.decimal_digits,
            .pad_left_len = 8,
            .pad_left_char = options.decimal_digits[0],
        });
        assert(frac_len == 8);
        total_len += 9; // decimal point plus 8 digits == 9 bytes
        // Truncate to max_fraction_digits
        if(frac_len > options.max_fraction_digits) {
            total_len -= frac_len - options.max_fraction_digits;
            frac_len = options.max_fraction_digits;
        }
        // Trim trailing zeros
        while(buffer[total_len - 1] == options.decimal_digits[0] and (
            frac_len > options.min_fraction_digits
        )) {
            frac_len -= 1;
            total_len -= 1;
        }
        // Pad to min_fraction_digits
        while(frac_len < options.min_fraction_digits) {
            buffer[total_len] = options.decimal_digits[0];
            frac_len += 1;
            total_len += 1;
        }
        // No fraction digits, after all that? Remove the decimal point.
        if(frac_len == 0) {
            total_len -= 1;
        }
    }
    if(total_len < options.pad_left_len and !options.pad_left_int) {
        const pad_len = options.pad_left_len - total_len;
        for(0..total_len) |pad_i| {
            const j = options.pad_left_len - pad_i - 1;
            assert(j >= pad_len);
            buffer[j] = buffer[j - pad_len];
        }
        for(0..pad_len) |pad_i| {
            buffer[pad_i] = options.pad_left_char;
        }
        return options.pad_left_len;
    }
    else {
        return total_len;
    }
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

/// Fixed point number type. Unsigned, width 16 bits, radix 16 bits.
/// Note that this is a particularly suitable type for representing angles
/// of rotation, measured in revolutions.
///
/// The GBA BIOS uses values of this type to represent angle inputs to
/// the `BgAffineSet` and `ObjAffineSet` functions, as well as angle outputs
/// from the `ArcTan` and `ArcTan2` functions.
pub const FixedU16R16 = packed struct(u16) {
    const Self = @This();
    const ValueT = u16;
    const radix_bits: comptime_int = 16;
    const radix_int: comptime_int = 1 << radix_bits;
    
    pub const is_fixed_point_type: bool = true;
    
    pub const zero: FixedU16R16 = .initRaw(0);
    pub const deg_90: FixedU16R16 = .initRaw(0x4000);
    pub const deg_180: FixedU16R16 = .initRaw(0x8000);
    pub const deg_270: FixedU16R16 = .initRaw(0xc000);
    
    /// Raw internal value.
    value: u16 = 0,
    
    /// Initialize from a raw value.
    /// You probably want to use `initDegrees`, `initRadians`, or
    /// `fromFloat` instead!
    pub fn initRaw(raw_value: ValueT) Self {
        return .{ .value = raw_value };
    }
    
    /// Initialize an angle, converting from degrees.
    /// FixedU16R16 internally represents angles as revolutions.
    pub fn initDegrees(comptime deg: f64) FixedU16R16 {
        return FixedU16R16.fromFloat64(@mod(deg / 360.0, 1.0));
    }
    
    /// Initialize an angle, converting from radians.
    /// FixedU16R16 internally represents angles as revolutions.
    pub fn initRadians(comptime rad: f64) FixedU16R16 {
        return FixedU16R16.fromFloat64(@mod(rad / 6.283185307179586, 1.0));
    }
    
    /// Initialize with a floating point value.
    pub fn fromFloat(comptime value: f64) Self {
        return Self.initRaw(@intFromFloat(value * radix_int));
    }
    
    /// Convert to a signed fixed-point type.
    pub fn toFixedI(
        self: Self,
        comptime ToValueT: type,
        comptime to_radix_bits: comptime_int,
    ) FixedI(ToValueT, to_radix_bits) {
        if(to_radix_bits == radix_bits) {
            return .initRaw(@intCast(self.value));
        }
        else if(to_radix_bits > radix_bits) {
            const shift = to_radix_bits - radix_bits;
            return .initRaw(@intCast(@as(i32, self.value) << shift));
        }
        else {
            const shift = radix_bits - to_radix_bits;
            return .initRaw(@intCast(@as(i32, self.value) >> shift));
        }
    }
    
    /// Convert to another numeric type.
    /// Only supports other fixed-point types.
    pub fn to(self: Self, comptime ToT: type) ToT {
        if(isSignedFixedPointType(ToT)) {
            return self.toFixedI(@FieldType(ToT, "value"), @bitSizeOf(
                @TypeOf(ToT.toInt).@"fn".return_type orelse unreachable
            ));
        }
        else if(ToT == Self) {
            return self;
        }
        else {
            @compileError("Cannot convert fixed point value to this type.");
        }
    }
    
    /// Invert this value.
    /// For angles, this is equivalent to adding 180 degrees.
    pub inline fn invert(self: Self) Self {
        return Self.initRaw(self.value +% 0x8000);
    }
    
    /// Add two values.
    pub inline fn add(a: Self, b: Self) Self {
        return Self.initRaw(a.value + b.value);
    }
    
    /// Subtract `b` from `a`.
    pub inline fn sub(a: Self, b: Self) Self {
        return Self.initRaw(a.value - b.value);
    }
    
    /// Multiply two values.
    pub fn mul(a: Self, b: Self) Self {
        return Self.initRaw(@intCast(
            (@as(u32, a.value) * @as(u32, b.value)) >> 16
        ));
    }
    
    // TODO: Compute reciprocal, return a FixedI32R16
    
    /// Returns true when the fixed point value is equal to zero.
    pub inline fn isZero(self: Self) bool {
        return self.value == 0;
    }
    
    /// Returns true when two values are exactly equal.
    pub inline fn eql(a: Self, b: Self) bool {
        return a.value == b.value;
    }
    
    /// Compare two values. Returns true when `a` is less than `b`.
    pub inline fn lessThan(a: Self, b: Self) bool {
        return a.value < b.value;
    }
    
    /// Compare two values. Returns true when `a` is greater than `b`.
    pub inline fn greaterThan(a: Self, b: Self) bool {
        return a.value > b.value;
    }
    
    /// Compare two values. Returns true when `a` is less than or equal to `b`.
    pub inline fn lessOrEqual(a: Self, b: Self) bool {
        return a.value <= b.value;
    }
    
    /// Compare two values. Returns true when `a` is greater than or equal to `b`.
    pub inline fn greaterOrEqual(a: Self, b: Self) bool {
        return a.value <= b.value;
    }
    
    /// Compute the sine of an angle, measured in revolutions.
    ///
    /// This implementation uses a lookup table allowing for 1024 discrete
    /// results from 0 to a full turn. It does not perform interpolation.
    /// This makes it faster than `sinLerp`, but less accurate.
    /// Even so, this should be accurate enough for almost all purposes.
    pub inline fn sin(self: Self) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsStepped(self.value));
    }
    
    /// Compute the cosine of an angle, measured in revolutions.
    ///
    /// This implementation uses a lookup table allowing for 1024 discrete
    /// results from 0 to a full turn. It does not perform interpolation.
    /// This makes it faster than `cosLerp`, but less accurate.
    /// Even so, this should be accurate enough for almost all purposes.
    pub inline fn cos(self: Self) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsStepped(self.value +% 0x4000));
    }
    
    /// Compute the sine of an angle, measured in revolutions.
    /// Produces a very accurate result, but not perfectly so.
    ///
    /// This implementation interpolates between values in a LUT, meaning
    /// it produces a smoother curve with less error compared to `sin_fast`.
    /// However, this extra computation costs a little extra performance.
    pub inline fn sinLerp(self: Self) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsLerp(self.value));
    }
    
    /// Compute the cosine of an angle, measured in revolutions.
    /// Produces a very accurate result, but not perfectly so.
    ///
    /// This implementation interpolates between values in a LUT, meaning
    /// it produces a smoother curve with less error compared to `cos_fast`.
    /// However, this extra computation costs a little extra performance.
    pub inline fn cosLerp(self: Self) FixedI32R16 {
        return FixedI32R16.initRaw(sinRevolutionsLerp(self.value +% 0x4000));
    }
    
    /// Convert an angle to degrees.
    pub fn toDegrees(self: Self) FixedI32R16 {
        return self.toFixedI(i32, 16).mul(.fromInt(360));
    }
    
    /// Convert an angle to radians.
    pub fn toRadians(self: Self) FixedI32R16 {
        const tau: f64 = 6.283185307179586;
        return self.toFixedI(i32, 16).mul(.fromFloat(tau));
    }

    /// Write the fixed point value with ASCII characters in decimal
    /// format to an output buffer.
    /// See `FixedI32R8.formatDecimal`.
    pub fn formatDecimal(
        self: Self,
        buffer: [*]volatile u8,
        options: FormatDecimalFixedOptions,
    ) u32 {
        // TODO: Once there is an implementation for `FixedI32R16`,
        // use that one instead.
        return formatDecimalFixedI32R8(
            self.toFixedI(i32, 8),
            buffer,
            options,
        );
    }
};

/// Parameterized signed fixed point number type.
pub fn FixedI(
    /// Raw storage value type. This should be a signed integer primitive.
    comptime ValueT: type,
    /// Number of bits to use for the fractional part of numbers.
    /// The fixed point scaling factor is equal to `1 << radix_bits`.
    comptime radix_bits: comptime_int,
) type {
    const int_bits = @bitSizeOf(ValueT) - radix_bits;
    const IntT = gba.math.getSignedIntPrimitiveType(int_bits);
    const radix_int: comptime_int = 1 << radix_bits;
    return packed struct(ValueT) {
        const Self = @This();
        
        pub const is_fixed_point_type: bool = true;
        pub const is_signed_fixed_point_type: bool = true;
        
        pub const zero: Self = .initRaw(0);
        pub const one: Self = .fromInt(1);
        pub const negative_one: Self = .fromInt(-1);
        
        /// Raw internal value.
        value: ValueT = 0,
        
        /// Initialize from a raw value.
        /// You probably want to use `fromInt` or `fromFloat` instead!
        pub inline fn initRaw(raw_value: ValueT) Self {
            return .{ .value = raw_value };
        }
        
        /// Initialize with an integer value.
        pub inline fn fromInt(int_value: IntT) Self {
            return Self.initRaw(@as(ValueT, int_value) << radix_bits);
        }
        
        /// Initialize with a floating point value.
        pub fn fromFloat(comptime value: f64) Self {
            return Self.initRaw(@intFromFloat(value * radix_int));
        }
        
        /// Convert to an integer, truncating the value's fractional portion.
        pub fn toInt(self: Self) IntT {
            return @intCast(self.value >> self.radix_bits);
        }
        
        /// Convert to another signed fixed-point type.
        pub fn toFixedI(
            self: Self,
            comptime ToValueT: type,
            comptime to_radix_bits: comptime_int,
        ) FixedI(ToValueT, to_radix_bits) {
            if(to_radix_bits == radix_bits) {
                return .initRaw(@intCast(self.value));
            }
            else if(to_radix_bits > radix_bits) {
                const shift = to_radix_bits - radix_bits;
                return .initRaw(@intCast(@as(i32, self.value) << shift));
            }
            else {
                const shift = radix_bits - to_radix_bits;
                return .initRaw(@intCast(@as(i32, self.value) >> shift));
            }
        }
        
        /// Convert to another numeric type.
        /// Supports integer primitives and other fixed-point types.
        pub fn to(self: Self, comptime ToT: type) ToT {
            if(gba.math.isIntPrimitiveType(ToT)) {
                return @intCast(self.toInt());
            }
            else if(isSignedFixedPointType(ToT)) {
                return self.toFixedI(@FieldType(ToT, "value"), @bitSizeOf(
                    @TypeOf(ToT.toInt).@"fn".return_type orelse unreachable
                ));
            }
            else if(ToT == FixedU16R16) {
                if(radix_bits == 16) {
                    return .initRaw(@intCast(self.value));
                }
                else if(radix_bits < 16) {
                    const shift = 16 - radix_bits;
                    return .initRaw(@intCast(@as(i32, self.value) << shift));
                }
                else {
                    const shift = radix_bits - 16;
                    return .initRaw(@intCast(@as(i32, self.value) >> shift));
                }
            }
            else {
                @compileError("Cannot convert fixed point value to this type.");
            }
        }
        
        /// Get a negated value.
        pub inline fn negate(self: Self) Self {
            return Self.initRaw(-self.value);
        }
        
        /// Get an absolute value.
        pub inline fn abs(self: Self) Self {
            return if(self.value >= 0) self else Self.negate();
        }
        
        /// Add two values.
        pub inline fn add(a: Self, b: Self) Self {
            return Self.initRaw(a.value + b.value);
        }
        
        /// Subtract `b` from `a`.
        pub inline fn sub(a: Self, b: Self) Self {
            return Self.initRaw(a.value - b.value);
        }
        
        /// Multiply two values.
        pub fn mul(a: Self, b: Self) Self {
            if(comptime(@bitSizeOf(ValueT) > 32)) {
                @compileError(
                    "Fixed point multiplication is not supported for " ++
                    "this type."
                );
            }
            // Comptime or tests: Use 64-bit multiplication
            if(comptime(!isGbaTarget())) {
                const product = @as(i64, a.value) * @as(i64, b.value);
                return .initRaw(@intCast(product >> radix_bits));
            }
            // Radix is 16 bits or fewer: Use 32-bit multiplication
            else if(comptime(@bitSizeOf(ValueT) <= 16)) {
                const product = (@as(i32, a.value) * @as(i32, b.value));
                return .initRaw(@intCast(product >> radix_bits));
            }
            // Use optimized IWRAM ARM call for FixedI32R16
            else if(comptime(ValueT == i32 and radix_bits == 16 and isGbaTarget())) {
                const arm_address = &FixedI32R16_mul_arm;
                return asm volatile (
                    "bx r3"
                    : [ret] "={r0}" (-> Self),
                    : [a] "{r0}" (a),
                      [b] "{r1}" (b),
                      [arm_address] "{r3}" (arm_address),
                    : "r0", "r1", "r3"
                );
            }
            // Use optimized IWRAM ARM call for FixedI32R8
            else if(comptime(ValueT == i32 and radix_bits == 8 and isGbaTarget())) {
                const arm_address = &FixedI32R8_mul_arm;
                return asm volatile (
                    "bx r3"
                    : [ret] "={r0}" (-> Self),
                    : [a] "{r0}" (a),
                      [b] "{r1}" (b),
                      [arm_address] "{r3}" (arm_address),
                    : "r0", "r1", "r3"
                );
            }
            // Fallback for other types with a backing int larger than 16 bits
            else if(comptime(gba.math.isSignedIntPrimitiveType(ValueT))) {
                const product = gba.math.signedMulLong(a.value, b.value);
                return .initRaw(@intCast(
                    (product.lo >> radix_bits) |
                    (product.hi << (32 - radix_bits))
                ));
            }
            else {
                @compileError(
                    "Fixed point multiplication is not supported for " ++
                    "this type."
                );
            }
        }
        
        /// Compute the reciprocal, i.e. the result of dividing 1 by this
        /// value.
        pub fn reciprocal(self: Self) Self {
            // TODO: Support for 32-bit types
            // https://blog.segger.com/algorithms-for-division-part-4-using-newtons-method/
            if(@bitSizeOf(ValueT) <= 16) {
                const qr = gba.bios.div(0x10000, @intCast(self.raw_value));
                return .initRaw(@intCast(qr.quotient));
            }
            else {
                @compileError(
                    "Fixed point division is not supported for " ++
                    "this type."
                );
            }
        }
        
        /// Divide two values.
        pub fn div(a: Self, b: Self) Self {
            // Note: `reciprocal` currently has limited support.
            return a.mul(b.reciprocal());
        }
        
        /// Returns true when the fixed point value is equal to zero.
        pub inline fn isZero(self: FixedI32R16) bool {
            return self.value == 0;
        }
        
        /// Returns true when two values are exactly equal.
        pub inline fn eql(a: Self, b: Self) bool {
            return a.value == b.value;
        }
        
        /// Compare two values. Returns true when `a` is less than `b`.
        pub inline fn lessThan(a: Self, b: Self) bool {
            return a.value < b.value;
        }
        
        /// Compare two values. Returns true when `a` is greater than `b`.
        pub inline fn greaterThan(a: Self, b: Self) bool {
            return a.value > b.value;
        }
        
        /// Compare two values. Returns true when `a` is less than or equal to `b`.
        pub inline fn lessOrEqual(a: Self, b: Self) bool {
            return a.value <= b.value;
        }
        
        /// Compare two values. Returns true when `a` is greater than or equal to `b`.
        pub inline fn greaterOrEqual(a: Self, b: Self) bool {
            return a.value <= b.value;
        }
        
        /// Write the fixed point value with ASCII characters in decimal
        /// format to an output buffer.
        ///
        /// Currently, this function converts everything to a `FixedI32R8`
        /// for formatting.
        /// Given this, the longest possible output string under normal
        /// circumstances is 13 characters: 1 for sign, 3 for integer portion,
        /// 1 for decimal point, and 8 after the decimal.
        ///
        /// May write junk in the output buffer past the end of the returned
        /// length, using it as a scratch area. Always provide a buffer with
        /// at least 13 free bytes.
        ///
        /// A longer buffer is required when using a `options.pad_left_len`
        /// longer than 13 or `options.min_fraction_digits` longer than 8.
        pub fn formatDecimal(
            self: Self,
            buffer: [*]volatile u8,
            options: FormatDecimalFixedOptions,
        ) u32 {
            // TODO: Better support for other types
            return formatDecimalFixedI32R8(
                self.toFixedI(i32, 8),
                buffer,
                options,
            );
        }
    };
}

/// Fixed point number type. Signed, width 16 bits, radix 8 bits.
/// The GBA hardware uses values of this type to represent the components
/// of affine transformation matrices.
pub const FixedI16R8 = FixedI(i16, 8);

/// Fixed point number type. Signed, width 16 bits, radix 14 bits.
/// Used by the GBA BIOS for `gba.bios.arctan2`.
pub const FixedI16R14 = FixedI(i16, 14);

/// Fixed point number type. Signed, width 32 bits, radix 8 bits.
/// The GBA hardware uses values of this type to represent the
/// displacement vector components of a background's affine transformation.
pub const FixedI32R8 = FixedI(i32, 8);

/// Fixed point number type. Signed, width 32 bits, radix 16 bits.
pub const FixedI32R16 = FixedI(i32, 16);
