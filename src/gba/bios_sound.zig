const builtin = @import("builtin");
const std = @import("std");
const gba = @import("gba.zig");

/// Options accepted by `soundDriverMode`.
pub const SoundDriverModeOptions = packed struct(u32) {
    pub const Frequency = enum(u4) {
        hz_5734 = 1,
        hz_7884 = 2,
        hz_10512 = 3,
        hz_13379 = 4,
        hz_15768 = 5,
        hz_18157 = 6,
        hz_21024 = 7,
        hz_26758 = 8,
        hz_31536 = 9,
        hz_36314 = 10,
        hz_40137 = 11,
        hz_42048 = 12,
    };
    
    reverb_value: u7 = 0,
    reverb: bool = false,
    simultaneous_channels: u4 = 8,
    master_volume: u4 = 15,
    frequency: Frequency = .hz_13379,
    // TODO: better representation.
    da_bits: u4,
};

pub const WaveData = extern struct {
    /// Unused bits. GBATEK documents this as an unused data type field.
    _1: u16 = 0,
    /// Unused bits.
    _2: u14 = 0,
    /// Indicates whether the sound should loop or play as a one-shot.
    loop: bool = false,
    /// Unused bits.
    _3: u1 = 0,
    /// This value is used to calculate the frequency.
    /// Frequency is equivalent to `rate * 2^((180-original MIDI key)/12)`.
    rate: u32,
    /// Start of loop.
    loop_start: u32 = 0,
    /// Number of samples.
    size: u32,
    /// Waveform data.
    /// The buffer should have `size + 1` bytes.
    /// The last byte is 0 for a one-shot, or the same as the value at the
    /// `loop` sample for looped playback.
    data: [*]const i8,
};

pub const SoundArea = extern struct {
    pub const Channel = extern struct {
        status: u8,
        /// User access prohibited. Named `r1` in GBATEK documentation.
        _1: u8 = 0,
        volume_left: u8,
        volume_right: u8,
        attack: u8,
        decay: u8,
        sustain: u8,
        release: u8,
        /// User access prohibited. Named `r2` in GBATEK documentation.
        _2: [4]u8 = @splat(0),
        freq: u32,
        wave_data: *WaveData,
        /// User access prohibited. Named `r3` in GBATEK documentation.
        _3: [6]u32,
        /// User access prohibited. Named `r4` in GBATEK documentation.
        _4: [4]u8,
    };
    
    /// Flag the system checks to see whether the work area has been
    /// initialized and whether it is currently being accessed.
    available: bool = false,
    /// Unused bits.
    _1: u31 = 0,
    /// User access prohibited. Named `DmaCount` in GBATEK documentation.
    _2: u8 = 0,
    /// Apply reverb effects to direct sound.
    reverb: u8 = 0,
    /// User access prohibited. Named `d1` in GBATEK documentation.
    _3: u16 = 0,
    /// User access prohibited.
    /// GBATEK documentation identifies this field as a function pointer.
    _4: u32 = 0,
    /// User access prohibited. Named `intp` in GBATEK documentation.
    _5: u32 = 0,
    /// User access prohibited. Named `NoUse` in GBATEK documentation.
    _6: u32 = 0,
    /// Array for controlling the direct sound channels.
    channels: [8]Channel,
    /// Contains sound data.
    pcm_buffer: [0xc60]i8
};

/// Wraps a `SoundBiasChange` BIOS call.
pub fn soundBiasChange(level: bool) void {
    asm volatile (
        "swi 0x19"
        :
        : [level] "{r0}" (level),
        : "r0", "r1", "r3"
    );
}

/// Wraps a `SoundDriverInit` BIOS call.
pub fn soundDriverInit(sound_area: *SoundArea) void {
    asm volatile (
        "swi 0x1a"
        :
        : [sound_area] "{r0}" (sound_area),
        : "r0", "r1", "r3"
    );
}

/// Wraps a `SoundDriverMode` BIOS call.
pub fn soundDriverMode(options: SoundDriverModeOptions) void {
    asm volatile (
        "swi 0x1b"
        :
        : [options] "{r0}" (options),
        : "r0", "r1", "r3"
    );
}

/// Wraps a `SoundDriverMain` BIOS call.
pub fn soundDriverMain() void {
    asm volatile (
        "swi 0x1c"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Wraps a `SoundDriverVSync` BIOS call.
pub fn soundDriverVSync() void {
    asm volatile (
        "swi 0x1d"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Wraps a `SoundChannelClear` BIOS call.
pub fn soundChannelClear() void {
    asm volatile (
        "swi 0x1e"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Wraps a `MidiKey2Freq` BIOS call.
pub fn midiKey2Freq(
    wave_data: *const WaveData,
    midi_key: u8,
    fine_adjustment: u8,
) u32 {
    return asm volatile (
        "swi 0x1f"
        : [ret] "={r0}" (-> u32),
        : [wave_data] "{r0}" (wave_data),
          [midi_key] "{r1}" (midi_key),
          [fine_adjustment] "{r2}" (fine_adjustment),
        : "r0", "r1", "r2", "r3", "cc"
    );
}

/// Wraps a `SoundDriverVSyncOff` BIOS call.
pub fn soundDriverVSyncOff() void {
    asm volatile (
        "swi 0x28"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}

/// Wraps a `SoundDriverVSyncOn` BIOS call.
pub fn soundDriverVSyncOn() void {
    asm volatile (
        "swi 0x29"
        :
        :
        : "r0", "r1", "r3", "cc"
    );
}
