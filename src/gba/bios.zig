//! This module provides interfaces for calling the GBA's BIOS-provided
//! functions via software interrupts (SWI).
//! These functions perform common operations using (usually) very
//! optimized code.

const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

// Imports for math-related BIOS calls.
pub const DivResult = @import("bios_math.zig").DivResult;
pub const BgAffineSource = @import("bios_math.zig").BgAffineSource;
pub const ObjAffineSource = @import("bios_math.zig").ObjAffineSource;
pub const div = @import("bios_math.zig").div;
pub const divArm = @import("bios_math.zig").divArm;
pub const sqrt = @import("bios_math.zig").sqrt;
pub const arctan = @import("bios_math.zig").arctan;
pub const arctan2 = @import("bios_math.zig").arctan2;
pub const bgAffineSet = @import("bios_math.zig").bgAffineSet;
pub const objAffineSetOam = @import("bios_math.zig").objAffineSetOam;
pub const objAffineSetStruct = @import("bios_math.zig").objAffineSetStruct;
pub const objAffineSet = @import("bios_math.zig").objAffineSet;

// Imports relating to `CpuSet` and `CpuFastSet` BIOS calls.
pub const CpuSetOptions = @import("bios_cpuset.zig").CpuSetOptions;
pub const CpuFastSetOptions = @import("bios_cpuset.zig").CpuFastSetOptions;
pub const cpuSet = @import("bios_cpuset.zig").cpuSet;
pub const cpuFastSet = @import("bios_cpuset.zig").cpuFastSet;
pub const cpuSetCopy16 = @import("bios_cpuset.zig").cpuSetCopy16;
pub const cpuSetCopy32 = @import("bios_cpuset.zig").cpuSetCopy32;
pub const cpuSetFill16 = @import("bios_cpuset.zig").cpuSetFill16;
pub const cpuSetFill32 = @import("bios_cpuset.zig").cpuSetFill32;
pub const cpuFastSetCopy = @import("bios_cpuset.zig").cpuFastSetCopy;
pub const cpuFastSetFill = @import("bios_cpuset.zig").cpuFastSetFill;

// Imports for BIOS calls which decompress or decode data.
pub const UnCompHeader = @import("bios_decompression.zig").UnCompHeader;
pub const BitUnPackOptions = @import("bios_decompression.zig").BitUnPackOptions;
pub const bitUnPack = @import("bios_decompression.zig").bitUnPack;
pub const lz77UnCompWRAM = @import("bios_decompression.zig").lz77UnCompWRAM;
pub const lz77UnCompVRAM = @import("bios_decompression.zig").lz77UnCompVRAM;
pub const huffUnComp = @import("bios_decompression.zig").huffUnComp;
pub const rlUnCompWRAM = @import("bios_decompression.zig").rlUnCompWRAM;
pub const rlUnCompVRAM = @import("bios_decompression.zig").rlUnCompVRAM;
pub const diff8bitUnFilterWRAM = @import("bios_decompression.zig").diff8bitUnFilterWRAM;
pub const diff8bitUnFilterVRAM = @import("bios_decompression.zig").diff8bitUnFilterVRAM;
pub const diff16bitUnFilter = @import("bios_decompression.zig").diff16bitUnFilter;

// Imports for sound-related BIOS calls.
pub const SoundDriverModeOptions = @import("bios_sound.zig").SoundDriverModeOptions;
pub const WaveData = @import("bios_sound.zig").WaveData;
pub const SoundArea = @import("bios_sound.zig").SoundArea;
pub const soundBiasChange = @import("bios_sound.zig").soundBiasChange;
pub const soundDriverInit = @import("bios_sound.zig").soundDriverInit;
pub const soundDriverMode = @import("bios_sound.zig").soundDriverMode;
pub const soundDriverMain = @import("bios_sound.zig").soundDriverMain;
pub const soundDriverVSync = @import("bios_sound.zig").soundDriverVSync;
pub const soundChannelClear = @import("bios_sound.zig").soundChannelClear;
pub const midiKey2Freq = @import("bios_sound.zig").midiKey2Freq;
pub const soundDriverVSyncOff = @import("bios_sound.zig").soundDriverVSyncOff;
pub const soundDriverVSyncOn = @import("bios_sound.zig").soundDriverVSyncOn;

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
    /// See `gba.math.FixedI16R14` and `gba.math.FixedU16R16`.
    /// This implementation may produce inaccurate values. In most situations,
    /// you should prefer to use the `arctan2` SWI instead.
    /// Named `ArcTan` in both Tonc and GBATEK documentation.
    arctan = 0x09,
    /// Two-argument arctangent.
    /// Accepts two signed 16-bit values representing a Y/X ratio, X in `r0`
    /// and Y in `r1`.
    /// Produces an unsigned 16-bit fixed point value in `r0` with radix 2^16
    /// measuring an angle result in revolutions. (See `gba.math.FixedU16R16`.)
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
    /// Inflates LZ77-compressed data. Writes 8-bit units.
    /// Named `LZ77UnCompWRAM` in Tonc documentation and
    /// `LZ77UnCompReadNormalWrite8bit` in GBATEK documentation.
    lz77_uncomp_wram = 0x11,
    /// Inflates LZ77-compressed data. Writes 16-bit units.
    /// Named `LZ77UnCompVRAM` in Tonc documentation and
    /// `LZ77UnCompReadNormalWrite16bit` in GBATEK documentation.
    lz77_uncomp_vram = 0x12,
    /// Named `HuffUnComp` in Tonc documentation and
    /// `HuffUnCompReadNormal` in GBATEK documentation.
    huff_uncomp = 0x13,
    /// Inflates run-length compressed data (run-length encoding).
    /// Writes 8-bit units.
    /// Named `RLUnCompWRAM` in Tonc documentation and
    /// `RLUnCompReadNormalWrite8bit` in GBATEK documentation.
    rl_uncomp_wram = 0x14,
    /// Inflates run-length compressed data (run-length encoding).
    /// Writes 16-bit units.
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
    /// Named `SoundBiasChange` in Tonc documentation and
    /// `SoundBias` in GBATEK documentation.
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
};

/// Resets the GBA and runs the code at address 0x02000000 or 0x08000000,
/// depending on the contents of a hardware register at 0x03007ffa.
/// (0 means 0x08000000 and anything else means 0x02000000.)
/// Wraps a `SoftReset` BIOS call.
pub fn softReset() void {
    asm volatile (
        "swi 0x00"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

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

/// Wraps a `RegisterRamReset` BIOS call.
pub fn registerRamReset(flags: RegisterRamResetFlags) void {
    asm volatile (
        "swi 0x01"
        :
        : [flags] "{r0}" (flags),
        : "r0", "r1", "r3", "cc"
    );
}

/// Halts the CPU, switching to a low-power mode, until an interrupt
/// request occurs.
/// You probably want to enable some interrupts before using this.
/// Wraps a `Halt` BIOS call.
pub fn halt() void {
    asm volatile (
        "swi 0x02"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Switches the system to a very low power mode.
/// The system can only wake from this state via keypad, gamepak,
/// or serial interrupts, and only if those interrupts were enabled
/// beforehand.
/// You probably want to turn off video and sound before using this.
/// Wraps a `Stop` BIOS call.
pub fn stop() void {
    asm volatile (
        "swi 0x03"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Determines `intrWait` behavior.
pub const IntrWaitType = enum(u1) {
    /// Return immediately if a flag was already set.
    return_immediately = 0,
    /// Discard old flags and wait until a flag is newly set.
    discard_old_wait_new = 1,
};

/// Wait in a halt state until one or more of the specified interrupts
/// occur. This is similar to the `halt` SWI, but it applies only to the
/// specified interrupts.
/// Wraps an `IntrWait` BIOS call.
pub fn intrWait(
    wait_type: IntrWaitType,
    interrupt_flags: gba.interrupt.Flags,
) void {
    asm volatile (
        "swi 0x04"
        :
        : [wait_type] "{r0}" (wait_type),
          [interrupt_flags] "{r1}" (interrupt_flags),
        : "r0", "r1", "r3", "cc"
    );
}

/// Halt execution until a VBlank interrupt triggers.
/// VBlank happens once per frame, after finishing drawing the frame.
/// You probably want to call this function once at the beginning of your
/// main game loop.
/// Note that several flags must be set before this will work as you
/// probably expect.
/// Wraps a `VBlankIntrWait` BIOS call.
///
/// See `gba.display.status.vblank_interrupt`, `gba.interrupt.enable.vblank`,
/// and `gba.interrupt.master.enable`. All three of these flags must be set in
/// order for VBlank interrupts to occur.
pub fn vblankIntrWait() void {
    asm volatile (
        "swi 0x05"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

pub const MultiBootParam = extern struct {
    /// Undocumented bytes.
    _1: [0x14]u8 = @splat(0),
    handshake_data: u8,
    /// Undocumented bytes.
    _2: [4]u8 = 0,
    client_data: [3]u8,
    palette_data: u8,
    /// Undocumented bytes.
    _3: u8 = 0,
    client_bit: u8,
    /// Undocumented bytes.
    _4: u8 = 0,
    /// Typically 0x800000c0.
    boot_src: *u32,
    /// Typically 0x800000c0 plus length.
    boot_end: *u32,
    /// Undocumented bytes.
    _5: [0x24]u8 = @splat(0),
};

pub const MultiBootTransferMode = enum(u32) {
    normal_256_khz = 0,
    multiplay = 1,
    normal_2_mhz = 2,
};

/// Wraps a `MultiBoot` BIOS call.
pub fn multiBoot(
    param: *MultiBootParam,
    transfer_mode: MultiBootTransferMode,
) bool {
    return asm volatile (
        "swi 0x25"
        : [ret] "={r0}" (-> bool),
        : [param] "{r0}" (param),
          [transfer_mode] "{r1}" (transfer_mode),
        : "r0", "r1", "r3", "cc"
    );
}

/// Reboots the GBA, including replaying the Nintendo intro.
/// Wraps a `HardReset` BIOS call.
pub fn hardReset() void {
    asm volatile (
        "swi 0x26"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Unofficial SWI supported by some emulators, including mGBA.
/// Prints UTF-8 encoded text from a buffer to a debug log.
/// See `gba.debug`.
pub fn agbPrintFlush() void {
    asm volatile (
        "swi 0xfa"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}
