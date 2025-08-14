const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

// TODO: use extern asm like mem.zig?

/// Enumeration of software interrupt codes (SWI) recognized by the GBA BIOS.
///
/// GBATEK categorizes SWI codes 0x00 through 0x0f as "Basic Functions",
/// 0x10 through 0x18 as "Decompression Functions", 0x19 through 0x2a as
/// "Sound (and Multiboot/HardReset/CustomHalt)".
pub const Swi = enum(u8) {
    /// Clears 0x200 bytes of RAM, from addresses 0x3007e00 through 0x3007fff,
    /// which contains stacks and BIOS IRQ vector/flags.
    /// Initializes the system, supervisor, and IRQ stack pointers.
    /// Sets `r0` through `r12`, `LR_svc`, `SPSR_svc`, `LR_irq`,
    /// and `SPSR_irq` to zero.
    /// Enters system mode. Does not return to the caller.
    /// Named `SoftReset` in both Tonc and GBATEK documentation.
    soft_reset = 0x00,
    /// Resets I/O hardware registers and RAM as specified using flags passed
    /// via `r0`. See `RegisterRamResetFlags`.
    /// Named `RegisterRamReset` in both Tonc and GBATEK documentation.
    register_ram_reset = 0x01,
    /// Halts the CPU, switching to a low-power mode, until an interrupt
    /// request occurs.
    /// You probably want to enable some interrupts before using this SWI.
    /// Named `Halt` in both Tonc and GBATEK documentation.
    halt = 0x02,
    /// Switches the system to a very low power mode.
    /// The system can only wake from this state via keypad, gamepak,
    /// or serial interrupts, and only if those interrupts were enabled
    /// beforehand.
    /// You probably want to turn off video and sound before using this SWI.
    /// Named `Stop` in both Tonc and GBATEK documentation.
    stop = 0x03,
    /// Wait in a halt state until one or more of the specified interrupts
    /// occur. This is similar to the `halt` SWI, but it applies only to the
    /// specified interrupts.
    /// Reads `r0` to determine behavior with already-set interrupt flags.
    /// Which flags to wait for are passed via `r1`.
    /// Named `IntrWait` in both Tonc and GBATEK documentation.
    intr_wait = 0x04,
    /// Wait in a halt state until a VBlank interrupt occurs.
    /// This BIOS call internally calls `intr_wait` with `r0 = 1` and `r1 = 1`.
    /// You probably want to enable VBlank interrupts before using this SWI.
    /// Named `VBlankIntrWait` in both Tonc and GBATEK documentation.
    vblank_intr_wait = 0x05,
    /// Signed division, `r0 / r1`.
    /// Writes quotient to `r0`, remainder to `r1`, and the absolute value
    /// of the quotient as an unsigned integer to `r3`.
    /// Usually gets caught in an endless loop upon division by zero.
    /// Named `Div` in both Tonc and GBATEK documentation.
    div = 0x06,
    /// Signed division, `r1 / r0`.
    /// Writes quotient to `r0`, remainder to `r1`, and the absolute value
    /// of the quotient as an unsigned integer to `r3`.
    /// Slower than `div`. Exists for compatibility reasons.
    /// Named `DivArm` in both Tonc and GBATEK documentation.
    div_arm = 0x07,
    /// Integer square root.
    /// Accepts an unsigned 32-bit number in `r0` and to compute the square
    /// root of and writes the result back to `r0`.
    /// Named `Sqrt` in both Tonc and GBATEK documentation.
    sqrt = 0x08,
    /// Arctangent.
    /// Accepts a signed 16-bit fixed point value in `r0` with radix 2^14. 
    /// Produces an unsigned 16-bit fixed point value in `r0` with radix 2^16
    /// measuring an angle result in revolutions.
    /// See `gba.FixedI16R14` and `gba.FixedU16R16`.
    /// This implementation may produce inaccurate values. In most situations,
    /// you should prefer to use the `arctan2` SWI instead.
    /// Named `ArcTan` in both Tonc and GBATEK documentation.
    arctan = 0x09,
    /// Two-argument arctangent.
    /// Accepts two signed 16-bit values representing a Y/X ratio, X in `r0`
    /// and Y in `r1`.
    /// Produces an unsigned 16-bit fixed point value in `r0` with radix 2^16
    /// measuring an angle result in revolutions. (See `gba.FixedU16R16`.)
    /// Named `ArcTan2` in both Tonc and GBATEK documentation.
    arctan2 = 0x0a,
    /// Named `CpuSet` in both Tonc and GBATEK documentation.
    cpu_set = 0x0b,
    /// Named `CpuFastSet` in both Tonc and GBATEK documentation.
    cpu_fast_set = 0x0c,
    /// Named `GetBiosChecksum` in Tonc documentation and
    /// `BiosChecksum` in GBATEK documentation.
    bios_checksum = 0x0d,
    /// Can be used to calculate rotation and scaling parameters
    /// for affine backgrounds.
    /// Named `BgAffineSet` in both Tonc and GBATEK documentation.
    bg_affine_set = 0x0e,
    /// Can be used to calculate rotation and scaling parameters
    /// for affine objects/sprites.
    /// Named `ObjAffineSet` in both Tonc and GBATEK documentation.
    obj_affine_set = 0x0f,
    /// Copy data while changing bit depth.
    /// Named `BitUnPack` in both Tonc and GBATEK documentation.
    bit_unpack = 0x10,
    /// Expands LZ77-compressed data. Writes 8-bit units.
    /// Named `LZ77UnCompWRAM` in Tonc documentation and
    /// `LZ77UnCompReadNormalWrite8bit` in GBATEK documentation.
    lz77_uncomp_wram = 0x11,
    /// Expands LZ77-compressed data. Writes 16-bit units.
    /// Named `LZ77UnCompVRAM` in Tonc documentation and
    /// `LZ77UnCompReadNormalWrite16bit` in GBATEK documentation.
    lz77_uncomp_vram = 0x12,
    /// Named `HuffUnComp` in Tonc documentation and
    /// `HuffUnCompReadNormal` in GBATEK documentation.
    huff_uncomp = 0x13,
    /// Expands RLE-compressed data (run-length encoding). Writes 8-bit units.
    /// Named `RLUnCompWRAM` in Tonc documentation and
    /// `RLUnCompReadNormalWrite8bit` in GBATEK documentation.
    rl_uncomp_wram = 0x14,
    /// Expands RLE-compressed data (run-length encoding). Writes 16-bit units.
    /// Named `RLUnCompVRAM` in Tonc documentation and
    /// `RLUnCompReadNormalWrite16bit` in GBATEK documentation.
    rl_uncomp_vram = 0x15,
    /// Named `Diff8bitUnFilterWRAM` in Tonc documentation and
    /// `Diff8bitUnFilterWrite8bit` in GBATEK documentation.
    diff_8bit_unfilter_wram = 0x16,
    /// Named `Diff8bitUnFilterVRAM` in Tonc documentation and
    /// `Diff8bitUnFilterWrite16bit` in GBATEK documentation.
    diff_8bit_unfilter_vram = 0x17,
    /// Named `Diff16bitUnFilter` in both Tonc and GBATEK documentation.
    diff_16bit_unfilter = 0x18,
    /// Named `SoundBias` in Tonc documentation and
    /// `SoundBiasChange` in GBATEK documentation.
    sound_bias_change = 0x19,
    /// Named `SoundDriverInit` in both Tonc and GBATEK documentation.
    sound_driver_init = 0x1a,
    /// Named `SoundDriverMode` in both Tonc and GBATEK documentation.
    sound_driver_mode = 0x1b,
    /// Named `SoundDriverMain` in both Tonc and GBATEK documentation.
    sound_driver_main = 0x1c,
    /// A short system call that resets the sound DMA.
    /// This function should normally be called immediately after a
    /// VBlank interrupt.
    /// Named `SoundDriverVSync` in both Tonc and GBATEK documentation.
    sound_driver_vsync = 0x1d,
    /// Named `SoundChannelClear` in both Tonc and GBATEK documentation.
    sound_channel_clear = 0x1e,
    /// Named `MidiKey2Freq` in both Tonc and GBATEK documentation.
    midi_key_2_freq = 0x1f,
    /// Undocumented.
    /// Named `MusicPlayerOpen` in both Tonc and GBATEK documentation.
    music_player_open = 0x20,
    /// Undocumented.
    /// Named `MusicPlayerStart` in both Tonc and GBATEK documentation.
    music_player_start = 0x21,
    /// Undocumented.
    /// Named `MusicPlayerStop` in both Tonc and GBATEK documentation.
    music_player_stop = 0x22,
    /// Undocumented.
    /// Named `MusicPlayerContinue` in both Tonc and GBATEK documentation.
    music_player_continue = 0x23,
    /// Undocumented.
    /// Named `MusicPlayerFadeOut` in both Tonc and GBATEK documentation.
    music_player_fade_out = 0x24,
    /// Named `MultiBoot` in both Tonc and GBATEK documentation.
    multi_boot = 0x25,
    /// Undocumented.
    /// Reboots the GBA, including replaying the Nintendo intro.
    /// Named `HardReset` in both Tonc and GBATEK documentation.
    hard_reset = 0x26,
    /// Undocumented.
    /// Named `CustomHalt` in both Tonc and GBATEK documentation.
    custom_halt = 0x27,
    /// This function is used to stop sound DMA.
    /// Named `SoundDriverVSyncOff` in both Tonc and GBATEK documentation.
    sound_driver_vsync_off = 0x28,
    /// This function restarts the sound DMA after a prior
    /// `sound_driver_vsync_off` SWI.
    /// Named `SoundDriverVSyncOn` in both Tonc and GBATEK documentation.
    sound_driver_vsync_on = 0x29,
    /// Undocumented.
    /// Named `SoundGetJumpList` in both Tonc and GBATEK documentation.
    get_jump_list = 0x2a,
    /// Unofficial SWI supported by some emulators, including mGBA.
    /// Prints UTF-8 encoded text from a buffer to a debug log.
    /// See `gba.debug`.
    agb_print_flush = 0xfa,

    // TODO: add a way to use ARM versions rather than just thumb
    fn getAsm(comptime code: Swi) []const u8 {
        var buffer: [16]u8 = undefined;
        return std.fmt.bufPrint(
            &buffer,
            "swi 0x{X}",
            .{@intFromEnum(code)},
        ) catch unreachable;
    }

    fn ReturnType(comptime self: Swi) type {
        return switch (self) {
            .div, .div_arm => DivResult,
            .bios_checksum, .sqrt => u16,
            .midi_key_2_freq => u32,
            .arctan, .arctan2 => gba.FixedU16R16,
            .multi_boot => bool,
            else => void,
        };
    }
};

/// Flags accepted by the `registerRamReset` BIOS call.
pub const RegisterRamResetFlags = packed struct(u8) {
    pub const none: RegisterRamResetFlags = .{};
    pub const all: RegisterRamResetFlags = @bitCast(@as(u8, 0xff));
    
    /// Clear on-board WRAM (EWRAM).
    ewram: bool = false,
    /// Clear on-chip WRAM (IWRAM), excluding the last 0x200 bytes.
    iwram: bool = false,
    /// Clear palette memory.
    palette: bool = false,
    /// Clear VRAM.
    vram: bool = false,
    /// Clear OAM. (Zero-filled; does not disable objects.)
    oam: bool = false,
    /// Reset SIO registers.
    /// Also switch to general-purpose mode.
    /// Least-significant bits of SIODATA32 are always destroyed, even if this
    /// flag is set to false.
    sio_registers: bool = false,
    /// Reset sound registers.
    sound_registers: bool = false,
    /// Reset all other registers besides SIO and sound.
    other_registers: bool = false,
};

/// Type returned by the `div` and `divArm` BIOS calls.
pub const DivResult = packed struct {
    quotient: i32,
    remainder: i32,
    absolute_quotient: u32,
};

pub const CpuSetOptions = packed struct(u32) {
    pub const Size = enum(u1) {
        bits_16 = 0,
        bits_32 = 1,
    };
    
    /// The number of words or half-words to write, depending on `size`.
    count: u21,
    /// Unused bits.
    _1: u3 = 0,
    /// Whether the write pointer should move with the read pointer,
    /// or whether the destination space should be filled with the value
    /// at `source[0]`.
    fixed: bool,
    /// Indicates whether to operate on 16-bit or 32-bit units.
    size: Size,
    /// Unused bits.
    _2: u6 = 0,
};

pub const CpuFastSetOptions = packed struct(u32) {
    /// The number of words to write.
    count: u21,
    /// Unused bits.
    _1: u3 = 0,
    /// Whether the write pointer should move with the read pointer,
    /// or whether the destination space should be filled with the value
    /// at `source[0]`.
    fixed: bool,
    /// Unused bits.
    _2: u7 = 0,
};

pub const CompressionType = enum(u4) {
    lz77 = 1,
    huffman = 2,
    run_length = 3,
    diff_filtered = 8,
};

pub const DecompressionHeader = packed struct(u32) {
    size: u4 = 0,
    type: CompressionType,
    decompressed_size: u24,
};

pub const SoundDriverModeArgs = packed struct(u32) {
    reverb_value: u7 = 0,
    reverb: bool = false,
    simultaneous_channels: u4 = 8,
    master_volume: u4 = 15,
    frequency: enum(u4) {
        @"5734_hz" = 1,
        @"7884_hz" = 2,
        @"10512_hz" = 3,
        @"13379_hz" = 4,
        @"15768_hz" = 5,
        @"18157_hz" = 6,
        @"21024_hz" = 7,
        @"26758_hz" = 8,
        @"31536_hz" = 9,
        @"36314_hz" = 10,
        @"40137_hz" = 11,
        @"42048_hz" = 12,
    } = .@"13379_hz",
    /// TODO: better representation
    da_bits: u4,
};

pub const TransferMode = enum(u32) {
    normal_256_khz,
    multiplay,
    normal_2_mhz,
};

pub const BgAffineSource = extern struct {
    original_x: gba.FixedI32R8 align(4),
    original_y: gba.FixedI32R8 align(4),
    display_x: i16,
    display_y: i16,
    scale_x: gba.FixedI16R8,
    scale_y: gba.FixedI16R8,
    /// BIOS ignores the low 8 bits.
    angle: gba.FixedU16R16,
};

pub const ObjAffineSource = packed struct {
    scale_x: gba.FixedI16R8,
    scale_y: gba.FixedI16R8,
    /// BIOS ignores the low 8 bits.
    angle: gba.FixedU16R16,
};

pub const BitUnpackArgs = packed struct {
    src_len_bytes: u16,
    src_bit_width: enum(u8) {
        @"1" = 1,
        @"2" = 2,
        @"4" = 4,
        @"8" = 8,
    },
    dest_bit_width: enum(u8) {
        @"1" = 1,
        @"2" = 2,
        @"4" = 4,
        @"8" = 8,
        @"16" = 16,
        @"32" = 32,
    },
    data_offset: u31,
    zero_data: bool,
};

/// Resets the GBA and runs the code at address 0x02000000 or 0x08000000,
/// depending on the contents of 0x03007ffa.
/// (0 means 0x08000000 and anything else means 0x02000000.)
pub fn softReset() void {
    call0Return0(.register_soft_reset);
}

pub fn registerRamReset(flags: RegisterRamResetFlags) void {
    call1Return0(.register_ram_reset, flags);
}

pub const WaitInterruptReturnType = enum(u1) {
    return_immediately,
    discard_old_wait_new,
};

pub fn waitInterrupt(
    return_type: WaitInterruptReturnType,
    flags: gba.interrupt.Flags,
) void {
    call2Return0(.intr_wait, return_type, flags);
}

/// Halt execution until a VBlank interrupt triggers.
/// VBlank happens once per frame, after finishing drawing the frame.
/// You probably want to call this function once at the beginning of your
/// main game loop.
/// Note that several flags must be set before this will work as you
/// probably expect.
///
/// See `gba.display.status.vblank_interrupt`, `gba.interrupt.enable.vblank`,
/// and `gba.interrupt.master.enable`. All three of these flags must be set in
/// order for VBlank interrupts to occur.
pub fn waitVBlank() void {
    call0Return0(.vblank_intr_wait);
}

/// Divide the numerator by the denominator.
///
/// Beware calling this function with a denominator of zero.
/// Doing so may result in an endless loop.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn div(numerator: i32, denominator: i32) DivResult {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        return .{
            .quotient = @divTrunc(numerator, denominator),
            .remainder = @rem(numerator, denominator),
            .absolute_quotient = @abs(numerator) / @abs(denominator),
        };
    }
    else {
        return call2Return3(.div, numerator, denominator);
    }
}

/// Divide the numerator by the denominator.
///
/// This call is 3 cycles slower than `div`.
/// It exists for compatibility with ARM's library.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn divArm(numerator: i32, denominator: i32) DivResult {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        return .{
            .quotient = @divTrunc(numerator, denominator),
            .remainder = @rem(numerator, denominator),
            .absolute_quotient = @abs(numerator) / @abs(denominator),
        };
    }
    else {
        return call2Return3(.div_arm, denominator, numerator);
    }
}

/// Compute the square root of an integer. Rounds down.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn sqrt(x: u32) u16 {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        const fx: f64 = @floatFromInt(x);
        return @intFromFloat(@sqrt(fx));
    }
    else {
        return call1Return1(.sqrt, x);
    }
}

/// Compute the arctangent of `x`.
/// This BIOS call may produce inaccurate values. In most situations,
/// you should prefer to use `arctan2` instead.
pub fn arctan(x: gba.FixedU16R14) gba.FixedU16R16 {
    return call1Return1(.arctan, x);
}

/// Compute the two-argument arctangent of `y / x`.
///
/// Note the unconventional order of arguments, first `x` then `y`.
/// This is the order used by libtonc and reflects the order by which
/// values are passed in registers.
pub fn arctan2(x: i16, y: i16) gba.FixedU16R16 {
    return call2Return1(.arctan2, x, y);
}

/// Wraps the system's `CpuSet` BIOS call.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn cpuSet(
    source: [*]const volatile u16,
    destination: [*]volatile u16,
    options: CpuSetOptions,
) void {
    assert(options.size == .bits_16 or (@intFromPtr(source) & 0x3 == 0));
    assert(options.size == .bits_16 or (@intFromPtr(destination) & 0x3 == 0));
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        const count = options.count << @intFromEnum(options.size);
        if(options.fixed) {
            @memset(destination[0..count], source[0]);
        }
        else {
            @memcpy(destination[0..count], source[0..count]);
        }
    }
    else {
        asm volatile (
            "swi 0x0b"
            :
            : [source] "{r0}" (source),
              [destination] "{r1}" (destination),
              [options] "{r2}" (options),
            : "r0", "r1", "r2", "cc", "memory"
        );
    }
}

/// Wraps the system's `CpuFastSet` BIOS call.
///
/// Normally uses a GBA BIOS function, but also implements a fallback to run
/// as you would expect in tests and at comptime where the GBA BIOS is not
/// available.
pub fn cpuFastSet(
    source: [*]const volatile u32,
    destination: [*]volatile u32,
    options: CpuFastSetOptions,
) void {
    if(@inComptime() or comptime(builtin.cpu.model != &std.Target.arm.cpu.arm7tdmi)) {
        // CpuFastSet rounds up to a multiple of 8 words.
        const count_lsb = options.count & 0x7;
        const count = (options.count & 0x1ffff8) + @intFromBool(count_lsb != 0);
        if(options.fixed) {
            @memset(destination[0..count], source[0]);
        }
        else {
            @memcpy(destination[0..count], source[0..count]);
        }
    }
    else {
        asm volatile (
            "swi 0x0c"
            :
            : [source] "{r0}" (source),
              [destination] "{r1}" (destination),
              [options] "{r2}" (options),
            : "r0", "r1", "r2", "cc", "memory"
        );
    }
}

/// Copies all 16-bit half-words from `source` into `dest`.
pub inline fn cpuSetCopy16(
    source: [*]const volatile u16,
    destination: [*]volatile u16,
    count: u21,
) void {
    cpuSet(source, destination, .{
        .count = count,
        .size = .bits_16,
        .fixed = false,
    });
}

/// Copies all 32-bit words from `source` into `dest`.
pub inline fn cpuSetCopy32(
    source: [*]const volatile u32,
    destination: [*]volatile u32,
    count: u21,
) void {
    cpuSet(@ptrCast(source), @ptrCast(destination), .{
        .count = count,
        .size = .bits_32,
        .fixed = false,
    });
}

/// Fills `dest` with the value at `source`.
pub inline fn cpuSetFill16(
    source: *const volatile u16,
    destination: [*]volatile u16,
    count: u21,
) void {
    cpuSet(source, destination, .{
        .count = count,
        .size = .bits_16,
        .fixed = true,
    });
}

/// Fills `destination` with the value at `source`.
pub inline fn cpuSetFill32(
    source: *const volatile u32,
    destination: [*]volatile u32,
    count: u21,
) void {
    cpuSet(@ptrCast(source), @ptrCast(destination), .{
        .count = count,
        .size = .bits_32,
        .fixed = true,
    });
}

/// Copies data in chunks of 8 words/32 bytes from `source` into `destination`.
pub inline fn cpuFastCopy32(
    source: [*]const volatile u32,
    destination: [*]volatile u32,
    count: u21,
) void {
    // If you really want to use `CpuFastSet` with its rounding-up behavior,
    // then call `gba.bios.cpuFastCopy` instead to bypass this check.
    assert((count & 0x7) == 0);
    call3Return0(.cpu_fast_set, source, destination, CpuFastSetOptions{
        .count = count,
        .fixed = false,
    });
}

/// Copies the value at `source` into `destination`, in chunks of
/// 8 words/32 bytes.
pub fn cpuFastSet32(
    source: *const volatile u32,
    destination: [*]volatile u32,
    count: u21,
) void {
    // If you really want to use `CpuFastSet` with its rounding-up behavior,
    // then call `gba.bios.cpuFastCopy` instead to bypass this check.
    assert((count & 0x7) == 0);
    call3Return0(.cpu_fast_set, source, destination, CpuFastSetOptions{
        .count = count,
        .fixed = true,
    });
}

pub fn bgAffineSet(
    source: []align(4) const volatile BgAffineSource,
    dest: *volatile gba.bg.Affine,
) void {
    call3Return0(.bg_affine_set, source, dest, source.len);
}

/// Takes a slice of affine calculation parameters and a pointer to the `pa` field of
/// the first `obj.Affine` to perform them on.
pub fn objAffineSet(
    source: []align(4) const volatile ObjAffineSource,
    dest: *volatile gba.obj.AffineTransform,
) void {
    call4Return0(.obj_affine_set, source, dest, source.len, 8);
}

pub fn bitUnpack(
    source: []const u8,
    dest: *align(4) const anyopaque,
    args: *const BitUnpackArgs,
) void {
    call3Return0(.bit_unpack, source, dest, args);
}

pub fn lz77UnCompWRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.lz77_uncomp_wram, source, dest);
}

pub fn lz77UnCompVRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.lz77_uncomp_vram, source, dest);
}

pub fn huffUnComp(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.huff_uncomp, source, dest);
}

pub fn rlUnCompWRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.rl_uncomp_wram, source, dest);
}

pub fn rlUnCompVRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.rl_uncomp_vram, source, dest);
}

pub fn diff8bitUnFilterWRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.diff_8bit_unfilter_wram, source, dest);
}

pub fn diff8bitUnFilterVRAM(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.diff_8bit_unfilter_vram, source, dest);
}

pub fn diff16bitUnFilter(
    source: *const DecompressionHeader,
    dest: *anyopaque,
) void {
    call2Return0(.diff_16bit_unfilter, source, dest);
}

// // TODO: define actual sound driver struct
// .SoundDriverInit => .{ *const volatile anyopaque },
// .SoundDriverMode => .{ SoundDriverModeArgs },
// // TODO: WaveData*, Midi stuff
// .MIDIKey2Freq => .{ *const anyopaque, u8, u8 },
// .MultiBoot => .{ *const volatile anyopaque, TransferMode },

pub fn agbPrintFlush() void {
    call0Return0(.agb_print_flush);
}

fn call0Return0(comptime swi: Swi) void {
    const assembly = comptime swi.getAsm();
    asm volatile (assembly);
}

fn call0Return1(comptime swi: Swi) swi.ReturnType() {
    const assembly = comptime swi.getAsm();
    const ret: swi.ReturnType() = undefined;
    asm volatile (assembly
        : [ret] "={r0}" (ret),
        :
        : "r0"
    );
    return ret;
}

inline fn call1Return0(comptime swi: Swi, r0: anytype) void {
    const assembly = comptime swi.getAsm();
    return asm volatile (assembly
        :
        : [r0] "{r0}" (r0),
        : "r0"
    );
}

fn call1Return1(comptime swi: Swi, r0: anytype) swi.ReturnType() {
    const assembly = comptime swi.getAsm();
    var ret: swi.ReturnType() = undefined;
    asm volatile (assembly
        : [ret] "={r0}" (ret),
        : [r0] "{r0}" (r0),
        : "r0"
    );
    return ret;
}

fn call2Return0(comptime swi: Swi, r0: anytype, r1: anytype) void {
    const assembly = comptime swi.getAsm();
    asm volatile (assembly
        :
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
        : "r0", "r1"
    );
}

fn call2Return1(comptime swi: Swi, r0: anytype, r1: anytype) swi.ReturnType() {
    const assembly = comptime swi.getAsm();
    var ret: swi.ReturnType() = undefined;
    asm volatile (assembly
        : [ret] "={r0}" (ret),
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
        : "r0", "r1"
    );
    return ret;
}

// Specialized code for division, as it uses multiple return registers.
fn call2Return3(comptime swi: Swi, r0: i32, r1: i32) DivResult {
    const assembly = comptime swi.getAsm();
    var quo: i32 = undefined;
    var rem: i32 = undefined;
    var abs: u32 = undefined;
    asm volatile (assembly
        : [quo] "={r0}" (quo),
          [rem] "={r1}" (rem),
          [abs] "={r3}" (abs),
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
    );

    return .{
        .quotient = quo,
        .remainder = rem,
        .absolute_quotient = abs,
    };
}

fn call3Return0(comptime swi: Swi, r0: anytype, r1: anytype, r2: anytype) void {
    const assembly = comptime swi.getAsm();
    asm volatile (assembly
        :
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
          [r2] "{r2}" (r2),
        : "r0", "r1", "r2"
    );
}

fn call3Return1(comptime swi: Swi, r0: anytype, r1: anytype, r2: anytype) swi.ReturnType() {
    const assembly = comptime swi.getAsm();
    var ret: swi.ReturnType() = undefined;
    asm volatile (assembly
        : [ret] "={r0}" (ret),
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
          [r2] "{r2}" (r2),
        : "r0", "r1", "r2"
    );
    return ret;
}

fn call4Return0(comptime swi: Swi, r0: anytype, r1: anytype, r2: anytype, r3: anytype) void {
    const assembly = comptime swi.getAsm();
    asm volatile (assembly
        :
        : [r0] "{r0}" (r0),
          [r1] "{r1}" (r1),
          [r2] "{r2}" (r2),
          [r3] "{r3}" (r3),
        : "r0", "r1", "r2", "r3"
    );
}
