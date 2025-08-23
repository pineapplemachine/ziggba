const gba = @import("gba.zig");
const assert = @import("std").debug.assert;
const isGbaTarget = @import("util.zig").isGbaTarget;

/// Type returned by `div` and `divArm`.
pub const DivResult = packed struct {
    quotient: i32,
    remainder: i32,
    absolute_quotient: u32,
};

/// Divide the numerator by the denominator,
/// using the system's `Div` BIOS call.
///
/// Beware calling this function with a denominator of zero.
/// There is an `assert` to defend against this when possible,
/// but otherwise doing so may result in an endless loop.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn div(numerator: i32, denominator: i32) DivResult {
    assert(denominator != 0);
    if(comptime(!isGbaTarget())) {
        return .{
            .quotient = @divTrunc(numerator, denominator),
            .remainder = @rem(numerator, denominator),
            .absolute_quotient = @abs(numerator) / @abs(denominator),
        };
    }
    else {
        var quotient: i32 = undefined;
        var remainder: i32 = undefined;
        var absolute_quotient: u32 = undefined;
        asm volatile (
            "swi 0x06"
            : [quotient] "={r0}" (quotient),
              [remainder] "={r1}" (remainder),
              [absolute_quotient] "={r3}" (absolute_quotient),
            : [numerator] "{r0}" (numerator),
              [denominator] "{r1}" (denominator),
            : "r0", "r1", "r3", "cc"
        );
        return DivResult{
            .quotient = quotient,
            .remainder = remainder,
            .absolute_quotient = absolute_quotient,
        };
    }
}

/// Divide the numerator by the denominator,
/// using the system's `DivArm` BIOS call.
///
/// This call is 3 cycles slower than `div`.
/// It exists for compatibility with ARM's library.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn divArm(numerator: i32, denominator: i32) DivResult {
    assert(denominator != 0);
    if(comptime(!isGbaTarget())) {
        return .{
            .quotient = @divTrunc(numerator, denominator),
            .remainder = @rem(numerator, denominator),
            .absolute_quotient = @abs(numerator) / @abs(denominator),
        };
    }
    else {
        var quotient: i32 = undefined;
        var remainder: i32 = undefined;
        var absolute_quotient: u32 = undefined;
        asm volatile (
            "swi 0x07"
            : [quotient] "={r0}" (quotient),
              [remainder] "={r1}" (remainder),
              [absolute_quotient] "={r3}" (absolute_quotient),
            : [denominator] "{r0}" (denominator),
              [numerator] "{r1}" (numerator),
            : "r0", "r1", "r3", "cc"
        );
        return DivResult{
            .quotient = quotient,
            .remainder = remainder,
            .absolute_quotient = absolute_quotient,
        };
    }
}

/// Compute the square root of an integer, using the system's `Sqrt` BIOS call.
/// Rounds down.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn sqrt(x: u32) u16 {
    if(comptime(!isGbaTarget())) {
        // Reference: https://github.com/ez-me/gba-bios
        const N_items: [16]u4 = .{
            15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
        };
        var n: u32 = x;
        var root: u32 = 0;
        var t: u32 = undefined;
        for(N_items) |N| {
            t = root + (1 << N);
            if(n >= (t << N)) {
                n -= (t << N);
                root |= (2 << N);
            }
        }
        return root >> 1;
    }
    else {
        return asm volatile (
            "swi 0x08"
            : [ret] "={r0}" (-> u16),
            : [x] "{r0}" (x),
            : "r0", "r1", "r3", "cc"
        );
    }
}

/// Compute the arctangent of `x`, using the system's `ArcTan` BIOS call.
/// GBATEK documents this function as having a problem in accuracy for
/// larger angle results.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn arctan(x: gba.math.FixedU16R14) gba.math.FixedU16R16 {
    if(comptime(!isGbaTarget())) {
        // Reference: https://github.com/ez-me/gba-bios
        const x2 = @as(i32, x.value) * @as(i32, x.value);
        const a: i32 = -(x2 >> 14);
        var b: i32 = ((0xa9 * a) >> 14) + 0x390;
        b = ((b * a) >> 14) + 0x91c;
        b = ((b * a) >> 14) + 0xfb6;
        b = ((b * a) >> 14) + 0x16aa;
        b = ((b * a) >> 14) + 0x2081;
        b = ((b * a) >> 14) + 0x3651;
        b = ((b * a) >> 14) + 0xa2f9;
        return .initRaw((@as(i32, x.value) * b) >> 16);
    }
    else {
        return asm volatile (
            "swi 0x09"
            : [ret] "={r0}" (-> gba.math.FixedU16R16),
            : [x] "{r0}" (x),
            : "r0", "r1", "r3", "cc"
        );
    }
}

/// Compute the two-argument arctangent of `y / x`,
/// using the system's `ArcTan2` BIOS call.
/// Note the unconventional order of arguments, first `x` then `y`.
/// This is the order used by libtonc and reflects the order by which
/// values are passed in registers.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn arctan2(x: i16, y: i16) gba.math.FixedU16R16 {
    if(comptime(!isGbaTarget())) {
        // Reference: https://github.com/ez-me/gba-bios
        if(y == 0) {
            return ((x >> 16) & 0x8000);
        }
        else if(x == 0) {
            return ((y >> 16) & 0x8000) + 0x4000;
        }
        else if(@abs(x) > @abs(y) or (
            (@abs(x) == @abs(y) and !(x < 0 and y < 0))
        )) {
            const atan = arctan(div(@as(i32, y) << 14, x).quotient);
            if(x < 0) {
                return 0x8000 + atan;
            }
            else {
                return (((y >> 16) & 0x8000) << 1) + atan;
            }
        }
        else {
            const atan = arctan(div(@as(i32, x) << 14, y).quotient);
            return (0x4000 + ((y >> 16) & 0x8000)) - atan;
        }
    }
    else {
        return asm volatile (
            "swi 0x0a"
            : [ret] "={r0}" (-> gba.math.FixedU16R16),
            : [x] "{r0}" (x),
              [y] "{r1}" (y),
            : "r0", "r1", "r3", "cc"
        );
    }
}

/// The `bgAffineSet` function expects a pointer argument to this struct.
pub const BgAffineSetOptions = extern struct {
    /// Origin in texture space.
    original: gba.math.Vec2FixedI32R8,
    /// Origin in screen space.
    display: gba.math.Vec2I16,
    /// Scaling on each axis.
    scale: gba.math.Vec2FixedI16R8,
    /// Angle of rotation.
    /// BIOS ignores the low 8 bits.
    angle: gba.math.FixedU16R16,
};

/// Can be used to calculate rotation and scaling parameters
/// for affine backgrounds, using the system's `BgAffineSet` BIOS call.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn bgAffineSet(
    /// Parameters for the affine transformation matrices and displacements
    /// to be computed.
    options: []const volatile BgAffineSetOptions,
    /// Write the computed affine transformations and displacements here.
    destination: [*]volatile gba.math.Affine3x2,
) void {
    if(comptime(!isGbaTarget())) {
        // Reference: https://github.com/ez-me/gba-bios
        const sin_lut: [256]i16 = .{
            0x0000, 0x0192, 0x0323, 0x04b5, 0x0645, 0x07d5, 0x0964, 0x0af1,
            0x0c7c, 0x0e05, 0x0f8c, 0x1111, 0x1294, 0x1413, 0x158f, 0x1708,
            0x187d, 0x19ef, 0x1b5d, 0x1cc6, 0x1e2b, 0x1f8b, 0x20e7, 0x223d,
            0x238e, 0x24da, 0x261f, 0x275f, 0x2899, 0x29cd, 0x2afa, 0x2c21,
            0x2d41, 0x2e5a, 0x2f6b, 0x3076, 0x3179, 0x3274, 0x3367, 0x3453,
            0x3536, 0x3612, 0x36e5, 0x37af, 0x3871, 0x392a, 0x39da, 0x3a82,
            0x3b20, 0x3bb6, 0x3c42, 0x3cc5, 0x3d3e, 0x3dae, 0x3e14, 0x3e71,
            0x3ec5, 0x3f0e, 0x3f4e, 0x3f84, 0x3fb1, 0x3fd3, 0x3fec, 0x3ffb,
            0x4000, 0x3ffb, 0x3fec, 0x3fd3, 0x3fb1, 0x3f84, 0x3f4e, 0x3f0e,
            0x3ec5, 0x3e71, 0x3e14, 0x3dae, 0x3d3e, 0x3cc5, 0x3c42, 0x3bb6,
            0x3b20, 0x3a82, 0x39da, 0x392a, 0x3871, 0x37af, 0x36e5, 0x3612,
            0x3536, 0x3453, 0x3367, 0x3274, 0x3179, 0x3076, 0x2f6b, 0x2e5a,
            0x2d41, 0x2c21, 0x2afa, 0x29cd, 0x2899, 0x275f, 0x261f, 0x24da,
            0x238e, 0x223d, 0x20e7, 0x1f8b, 0x1e2b, 0x1cc6, 0x1b5d, 0x19ef,
            0x187d, 0x1708, 0x158f, 0x1413, 0x1294, 0x1111, 0x0f8c, 0x0e05,
            0x0c7c, 0x0af1, 0x0964, 0x07d5, 0x0645, 0x04b5, 0x0323, 0x0192,
            0x0000, 0xfe6e, 0xfcdd, 0xfb4b, 0xf9bb, 0xf82b, 0xf69c, 0xf50f,
            0xf384, 0xf1fb, 0xf074, 0xeeef, 0xed6c, 0xebed, 0xea71, 0xe8f8,
            0xe783, 0xe611, 0xe4a3, 0xe33a, 0xe1d5, 0xe075, 0xdf19, 0xddc3,
            0xdc72, 0xdb26, 0xd9e1, 0xd8a1, 0xd767, 0xd633, 0xd506, 0xd3df,
            0xd2bf, 0xd1a6, 0xd095, 0xcf8a, 0xce87, 0xcd8c, 0xcc99, 0xcbad,
            0xcaca, 0xc9ee, 0xc91b, 0xc851, 0xc78f, 0xc6d6, 0xc626, 0xc57e,
            0xc4e0, 0xc44a, 0xc3be, 0xc33b, 0xc2c2, 0xc252, 0xc1ec, 0xc18f,
            0xc13b, 0xc0f2, 0xc0b2, 0xc07c, 0xc04f, 0xc02d, 0xc014, 0xc005,
            0xc000, 0xc005, 0xc014, 0xc02d, 0xc04f, 0xc07c, 0xc0b2, 0xc0f2,
            0xc13b, 0xc18f, 0xc1ec, 0xc252, 0xc2c2, 0xc33b, 0xc3be, 0xc44a,
            0xc4e0, 0xc57e, 0xc626, 0xc6d6, 0xc78f, 0xc851, 0xc91b, 0xc9ee,
            0xcaca, 0xcbad, 0xcc99, 0xcd8c, 0xce87, 0xcf8a, 0xd095, 0xd1a6,
            0xd2bf, 0xd3df, 0xd506, 0xd633, 0xd767, 0xd8a1, 0xd9e1, 0xdb26,
            0xdc72, 0xddc3, 0xdf19, 0xe075, 0xe1d5, 0xe33a, 0xe4a3, 0xe611,
            0xe783, 0xe8f8, 0xea71, 0xebed, 0xed6c, 0xeeef, 0xf074, 0xf1fb,
            0xf384, 0xf50f, 0xf69c, 0xf82b, 0xf9bb, 0xfb4b, 0xfcdd, 0xfe6e,
        };
        for(0..options.len) |i| {
            const theta: u16 = options[i].angle >> 8;
            const sin: i32 = sin_lut[theta];
            const cos: i32 = sin_lut[(theta + 0x40) & 0xff];
            const pa = (options[i].scale.x * cos) >> 14;
            const pb = -((options[i].scale.x * sin) >> 14);
            const pc = (options[i].scale.y * sin) >> 14;
            const pd = (options[i].scale.y * cos) >> 14;
            const dx = (
                options[i].original.x -
                (pa * options[i].display.x) +
                (pb * options[i].display.y)
            );
            const dy = (
                options[i].original.y -
                (pc * options[i].display.x) -
                (pd * options[i].display.y)
            );
            destination[i].pa = pa;
            destination[i].pb = pb;
            destination[i].pc = pc;
            destination[i].pd = pd;
            destination[i].dx = dx;
            destination[i].dy = dy;
        }
    }
    else {
        const options_len = options.len;
        asm volatile (
            "swi 0x0e"
            :
            : [options] "{r0}" (options),
              [destination] "{r1}" (destination),
              [options_len] "{r2}" (options_len),
            : "r0", "r1", "r2", "r3", "cc", "memory"
        );
    }
}

/// The `objAffineSet` function expects a pointer argument to this struct.
pub const ObjAffineSetOptions = packed struct {
    /// Scaling on each axis.
    scale: gba.math.Vec2FixedI16R8,
    /// Angle of rotation.
    /// BIOS ignores the low 8 bits.
    angle: gba.math.FixedU16R16,
};

/// Wraps `objAffineSet` to write output values to OAM.
/// See also `gba.obj.setTransform`.
pub fn objAffineSetOam(
    /// Parameters for the affine transformation matrices to be computed.
    options: []const volatile ObjAffineSetOptions,
    /// Write the computed transformation matrices to OAM starting here.
    oam_affine_index: u5,
) void {
    assert(options.len + @as(usize, oam_affine_index) <= 32);
    const value_index = 3 + (@as(u8, oam_affine_index) << 4);
    objAffineSet(options, &gba.obj.oam_affine_values[value_index], 8);
}

/// Wraps `objAffineSet` to write output values to `gba.math.Affine2x2`
/// destinations.
pub fn objAffineSetStruct(
    /// Parameters for the affine transformation matrices to be computed.
    options: []const volatile ObjAffineSetOptions,
    /// Write the computed transformation matrices here.
    destination: [*]volatile gba.math.Affine2x2,
) void {
    objAffineSet(options, destination, 2);
}

/// Can be used to calculate rotation and scaling parameters
/// for affine objects, using the system's `ObjAffineSet` BIOS call.
///
/// If writing to an affine matrix represented in contiguous memory,
/// e.g. with the `gba.math.Affine2x2` struct, `offset` should be 2.
/// If writing directly to OAM, then `offset` should be 8.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn objAffineSet(
    /// Parameters for the affine transformation matrices to be computed.
    options: []const volatile ObjAffineSetOptions,
    /// Write the computed transformation matrices here.
    destination: [*]align(2) volatile u8,
    /// Byte offset in memory from each affine transformation matrix component
    /// to the next, at the destination pointer.
    /// The offset must be a multiple of 2.
    offset: u32,
) void {
    assert((offset & 1) == 0);
    if(comptime(!isGbaTarget())) {
        // Reference: https://github.com/ez-me/gba-bios
        const sin_lut: [256]i16 = .{
            0x0000, 0x0192, 0x0323, 0x04b5, 0x0645, 0x07d5, 0x0964, 0x0af1,
            0x0c7c, 0x0e05, 0x0f8c, 0x1111, 0x1294, 0x1413, 0x158f, 0x1708,
            0x187d, 0x19ef, 0x1b5d, 0x1cc6, 0x1e2b, 0x1f8b, 0x20e7, 0x223d,
            0x238e, 0x24da, 0x261f, 0x275f, 0x2899, 0x29cd, 0x2afa, 0x2c21,
            0x2d41, 0x2e5a, 0x2f6b, 0x3076, 0x3179, 0x3274, 0x3367, 0x3453,
            0x3536, 0x3612, 0x36e5, 0x37af, 0x3871, 0x392a, 0x39da, 0x3a82,
            0x3b20, 0x3bb6, 0x3c42, 0x3cc5, 0x3d3e, 0x3dae, 0x3e14, 0x3e71,
            0x3ec5, 0x3f0e, 0x3f4e, 0x3f84, 0x3fb1, 0x3fd3, 0x3fec, 0x3ffb,
            0x4000, 0x3ffb, 0x3fec, 0x3fd3, 0x3fb1, 0x3f84, 0x3f4e, 0x3f0e,
            0x3ec5, 0x3e71, 0x3e14, 0x3dae, 0x3d3e, 0x3cc5, 0x3c42, 0x3bb6,
            0x3b20, 0x3a82, 0x39da, 0x392a, 0x3871, 0x37af, 0x36e5, 0x3612,
            0x3536, 0x3453, 0x3367, 0x3274, 0x3179, 0x3076, 0x2f6b, 0x2e5a,
            0x2d41, 0x2c21, 0x2afa, 0x29cd, 0x2899, 0x275f, 0x261f, 0x24da,
            0x238e, 0x223d, 0x20e7, 0x1f8b, 0x1e2b, 0x1cc6, 0x1b5d, 0x19ef,
            0x187d, 0x1708, 0x158f, 0x1413, 0x1294, 0x1111, 0x0f8c, 0x0e05,
            0x0c7c, 0x0af1, 0x0964, 0x07d5, 0x0645, 0x04b5, 0x0323, 0x0192,
            0x0000, 0xfe6e, 0xfcdd, 0xfb4b, 0xf9bb, 0xf82b, 0xf69c, 0xf50f,
            0xf384, 0xf1fb, 0xf074, 0xeeef, 0xed6c, 0xebed, 0xea71, 0xe8f8,
            0xe783, 0xe611, 0xe4a3, 0xe33a, 0xe1d5, 0xe075, 0xdf19, 0xddc3,
            0xdc72, 0xdb26, 0xd9e1, 0xd8a1, 0xd767, 0xd633, 0xd506, 0xd3df,
            0xd2bf, 0xd1a6, 0xd095, 0xcf8a, 0xce87, 0xcd8c, 0xcc99, 0xcbad,
            0xcaca, 0xc9ee, 0xc91b, 0xc851, 0xc78f, 0xc6d6, 0xc626, 0xc57e,
            0xc4e0, 0xc44a, 0xc3be, 0xc33b, 0xc2c2, 0xc252, 0xc1ec, 0xc18f,
            0xc13b, 0xc0f2, 0xc0b2, 0xc07c, 0xc04f, 0xc02d, 0xc014, 0xc005,
            0xc000, 0xc005, 0xc014, 0xc02d, 0xc04f, 0xc07c, 0xc0b2, 0xc0f2,
            0xc13b, 0xc18f, 0xc1ec, 0xc252, 0xc2c2, 0xc33b, 0xc3be, 0xc44a,
            0xc4e0, 0xc57e, 0xc626, 0xc6d6, 0xc78f, 0xc851, 0xc91b, 0xc9ee,
            0xcaca, 0xcbad, 0xcc99, 0xcd8c, 0xce87, 0xcf8a, 0xd095, 0xd1a6,
            0xd2bf, 0xd3df, 0xd506, 0xd633, 0xd767, 0xd8a1, 0xd9e1, 0xdb26,
            0xdc72, 0xddc3, 0xdf19, 0xe075, 0xe1d5, 0xe33a, 0xe4a3, 0xe611,
            0xe783, 0xe8f8, 0xea71, 0xebed, 0xed6c, 0xeeef, 0xf074, 0xf1fb,
            0xf384, 0xf50f, 0xf69c, 0xf82b, 0xf9bb, 0xfb4b, 0xfcdd, 0xfe6e,
        };
        const dest: *volatile gba.math.FixedI16R8 = @ptrCast(destination);
        const dest_offset = offset >> 1;
        for(0..options.len) |i| {
            const theta: u16 = options[i].angle >> 8;
            const sin: i32 = sin_lut[theta];
            const cos: i32 = sin_lut[(theta + 0x40) & 0xff];
            dest.* = (options[i].scale.x * cos) >> 14;
            dest += dest_offset;
            dest.* = -((options[i].scale.x * sin) >> 14);
            dest += dest_offset;
            dest.* = (options[i].scale.y * sin) >> 14;
            dest += dest_offset;
            dest.* = (options[i].scale.y * cos) >> 14;
            dest += dest_offset;
        }
    }
    else {
        const options_len = options.len;
        asm volatile (
            "swi 0x0e"
            :
            : [options] "{r0}" (options),
              [destination] "{r1}" (destination),
              [options_len] "{r2}" (options_len),
              [offset] "{r3}" (offset),
            : "r0", "r1", "r2", "r3", "cc", "memory"
        );
    }
}
