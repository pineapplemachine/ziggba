const gba = @import("gba.zig");

/// Stores `sine(x) * 0x10000` in 256 steps over the range `[0, pi/2)` radians.
/// This can be used to trivially compute sine and cosine for arbitary inputs.
const sin_lut: [256]u16 = blk: {
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

fn sinRevolutions(value: u16) FixedI32R16 {
    if(value <= 0) { // Zero
        return FixedI32R16.initRaw(0);
    }
    else if(value < 0x4000) { // Less than a quarter turn
        return FixedI32R16.initRaw(sin_lut[value >> 6]);
    }
    else if(value == 0x4000) { // Exactly a quarter turn
        return FixedI32R16.initInt(1);
    }
    else if(value < 0x8000) { // Less than a half turn
        const v2 = 0x8000 - value;
        return FixedI32R16.initRaw(sin_lut[v2 >> 6]);
    }
    else if(value == 0x8000) { // Exactly a half turn
        return FixedI32R16.initRaw(0);
    }
    else if(value < 0xc000) { // Less than three quarters turn
        const v2 = value - 0x8000;
        return FixedI32R16.initRaw(-@as(i32, sin_lut[v2 >> 6]));
    }
    else if(value == 0xc000) { // Exactly three quarters turn
        return FixedI32R16.initInt(-1);
    }
    else { // Less than a full turn
        const v2 = 0x10000 - @as(u32, value);
        return FixedI32R16.initRaw(-@as(i32, sin_lut[v2 >> 6]));
    }
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

/// Fixed point number type. Unsigned, width 16 bits, radix 16 bits.
/// Note that this is a particularly suitable type for representing angles
/// of rotation, measured in revolutions.
///
/// The GBA BIOS uses values of this type to represent angle inputs to
/// the `BgAffineSet` and `ObjAffineSet` functions.
pub const FixedU16R16 = packed struct(u16) {
    value: u16 = 0,
    
    pub inline fn initRaw(raw_value: u16) FixedU16R16 {
        return FixedU16R16{ .value = raw_value };
    }
    
    pub fn initFloat32(comptime value: f32) FixedU16R16 {
        return FixedU16R16.initRaw(@intFromFloat(value * 0x10000));
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
    
    pub inline fn invert(self: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(self.value +% 0x8000);
    }
    
    pub inline fn add(a: FixedU16R16, b: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(a.value + b.value);
    }
    
    pub inline fn sub(a: FixedU16R16, b: FixedU16R16) FixedU16R16 {
        return FixedU16R16.initRaw(a.value - b.value);
    }
    
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
    /// results from 0 to a full turn, and does not interpolate between values.
    pub inline fn sin(self: FixedU16R16) FixedI32R16 {
        return sinRevolutions(self.value);
    }
    
    /// Compute the cosine of an angle, measured in revolutions.
    ///
    /// This implementation uses a lookup table allowing for 1024 discrete
    /// results from 0 to a full turn, and does not interpolate between values.
    pub inline fn cos(self: FixedU16R16) FixedI32R16 {
        return sinRevolutions(self.value -% 0x4000);
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
