//! This module provides an interface for dealing with the GBA's sound-related
//! features.

const gba = @import("gba.zig");

/// Contains a flag corresponding to each of the PSG audio channels.
pub const ChannelFlags = packed struct(u4) {
    pub const all: ChannelFlags = @bitCast(0xf);
    pub const none: ChannelFlags = .{};
    
    /// PSG channel 1.
    pulse_1: bool = false,
    /// PSG channel 2.
    pulse_2: bool = false,
    /// PSG channel 3.
    wave: bool = false,
    /// PSG channel 4.
    noise: bool = false,
};

/// Enumeration of direction options for channel volume envelopes.
/// This is used by both the pulse and noise channel control registers.
pub const VolumeEnvelopeDirection = enum(u1) {
    /// Volume decreases over time.
    decrease = 0,
    /// Volume increases over time.
    increase = 1,
};

/// Represents the contents of the REG_SND1SWEEP register.
pub const PulseChannelSweep = packed struct(u16) {
    pub const Direction = enum(u1) {
        /// Rate, and therefore also pitch/frequency, increases over time.
        increase = 0,
        /// Rate, and therefore also pitch/frequency, decreases over time.
        decrease = 1,
    };

    /// The higher the shift, the slower the sweep.
    /// At each step, the new rate becomes rate ± rate/2^shift.
    shift: u3 = 0,
    /// Whether the sweep takes the rate up or down.
    dir: Direction = .increase,
    /// Sweep step-time. The time between sweeps is measured
    /// in increments of 128 Hz. Time is step/128 milliseconds.
    /// Range of [7.8, 54.7] milliseconds.
    /// Set to zero to disable sweep.
    step: u3 = 0,
    /// Unused bits.
    _: u9 = 0,
};

/// Represents the contents of REG_SND1CNT and REG_SND2CNT registers.
pub const PulseChannelControl = packed struct(u16) {
    /// Enumeration of possible square wave duty cycles.
    pub const Duty = enum(u2) {
        /// Waveform looks like `-_______`.
        /// Also called a 1/8 cycle.
        hi_1_lo_7 = 0,
        /// Waveform looks like `-___-___`.
        /// Also called a 1/4 cycle.
        hi_1_lo_3 = 1,
        /// Waveform looks like `-_-_-_-_`.
        /// Also called a 1/2 cycle.
        hi_1_lo_1 = 2,
        /// Waveform looks like `---_---_`.
        /// Also called a 3/4 cycle.
        /// Sounds the same as hi_1_lo_3.
        hi_3_lo_1 = 3,
    };

    /// Sound length. This is a write-only field and only works
    /// if the channel is timed.
    /// Length is equal to (64-len)/256 seconds, for a range of
    /// [3.9, 250] milliseconds.
    len: u6 = 0,
    /// Pulse wave duty cycle, as a ratio between on and off
    /// times of the square wave.
    duty: Duty = .hi_1_lo_7,
    /// Envelope step-time. Time between envelope changes is
    /// step/64 seconds.
    /// Set to zero to disable changing volume over time.
    step: u3 = 0,
    /// Whether the envelope increases or decreases with each step.
    dir: VolumeEnvelopeDirection = .decrease,
    /// Envelope initial volume.
    /// 0 means silent and 15 means full volume.
    volume: u4 = 0,
};

/// Represents the contents of REG_SND1FREQ, REG_SND2FREQ, and
/// REG_SND3FREQ registers.
/// This includes frequency control for the pulse and wave channels.
/// Differs from and does not accurately represent the contents of
/// REG_SND4FREQ. For REG_SND4FREQ, see `NoiseChannelFrequency`.
pub const PsgChannelFrequency = packed struct(u16) {
    /// Initial sound rate. Write-only. Frequency is 2^17/(2048-rate).
    rate: u11 = 0,
    /// Unused bits.
    _: u3 = 0,
    /// Timed flag. If set, the sound plays for a duration determined
    /// by the channel's ctrl.len field. If clear, it plays indefinitely,
    /// although it may become inaudible depending on the volume envelope.
    timed: bool = false,
    /// Sound reset. Resets sound to the initial volume and sweep
    /// settings, when set to true.
    reset: bool = false,
};

/// Frequency control for the pulse channels.
/// Represents the contents of REG_SND1FREQ and REG_SND2FREQ registers.
pub const PulseChannelFrequency = PsgChannelFrequency;

/// Represents the contents of the REG_SND3SEL register.
pub const WaveChannelSelect = packed struct(u16) {
    pub const Dimension = enum(u1) {
        /// Use one 32-sample bank for the wave channel.
        single = 0,
        /// Use both banks for the wave channel, for a total of 64 samples.
        /// Note that while both banks are in use in this way, it is unsafe
        /// to write to the REG_WAVE_RAMx registers at all during playback.
        double = 1,
    };

    /// Unused bits.
    _1: u5 = 0,
    /// Wave RAM dimension. Determines whether to play a single 32-sample
    /// waveform from the selected bank, or whether to combine both banks
    /// into a double-long 64-sample waveform.
    dimension: Dimension = .single,
    /// Selected wave RAM bank number.
    /// Whichever bank is not selected here is the one that can be written
    /// to via the REG_WAVE_RAMx registers.
    bank: u1 = 0,
    /// Whether the channel is stopped or playing.
    playback: bool = false,
    /// Unused bits.
    _2: u8 = 0,
};

/// Represents the contents of the REG_SND3CNT register.
pub const WaveChannelControl = packed struct(u16) {
    /// Enumeration of volume options.
    /// Note that enabling force_volume_75 overrides the volume setting.
    pub const Volume = enum(u2) {
        /// Volume at 0% (Silent)
        percent_0 = 0,
        /// Volume at 100% (Full)
        percent_100 = 1,
        /// Volume at 50% (Half)
        percent_50 = 2,
        /// Volume at 25% (Quarter)
        percent_25 = 3,
    };

    /// Length is equal to (256-len)/256 seconds.
    len: u8 = 0,
    /// Unused bits.
    _: u5 = 0,
    /// Playback volume.
    /// This is overridden when force_volume_75 is set.
    volume: Volume = .percent_0,
    /// When true, overrides the previous volume setting and
    /// sets volume to 75% instead.
    force_volume_75: bool = false,
};

/// Represents the contents of the REG_SND3FREQ register.
/// The rate value determines sample rate, measured in sample
/// digits per second.
pub const WaveChannelFrequency = PsgChannelFrequency;

/// Represents the contents of the REG_SND4CNT register.
/// Same as PulseChannelControl except that the duty bits are unused.
pub const NoiseChannelControl = packed struct(u16) {
    /// Sound length. This is a write-only field and only works
    /// if the channel is timed.
    /// Length is equal to (64-len)/256 seconds, for a range of
    /// [3.9, 250] milliseconds.
    len: u6 = 0,
    /// Unused bits.
    _: u2 = 0,
    /// Envelope step-time. Time between envelope changes is
    /// step/64 seconds.
    /// Set to zero to disable changing volume over time.
    step: u3 = 0,
    /// Whether the envelope increases or decreases with each step.
    dir: VolumeEnvelopeDirection = .decrease,
    /// Envelope initial volume.
    /// 0 means silent and 15 means full volume.
    volume: u4 = 0,
};

/// Represents the contents of the REG_SND4FREQ register.
/// Actual sample rate of the LFSR random bits is
/// 262114 / (divisor << shift).
pub const NoiseChannelFrequency = packed struct(u16) {
    /// Enumeration of divisor values used to determine the sample rate
    /// of the noise channel's LSFR PRNG.
    pub const Divisor = enum(u3) {
        div_8 = 0,
        div_16 = 1,
        div_32 = 2,
        div_48 = 3,
        div_64 = 4,
        div_80 = 5,
        div_96 = 6,
        div_112 = 7,
    };

    /// Enumeration of possible modes for the LSFR PRNG for noise generation.
    pub const Mode = enum(u1) {
        /// Noise LSFR repeats over a longer interval. Noise sounds smoother.
        bits_15 = 0,
        /// Noise LSFR repeats over a shorter interval. Noise sounds harsher.
        bits_7 = 1,
    };

    /// Dividing ratio of frequencies.
    /// Affects frequency timer period.
    divisor: Divisor = .div_8,
    /// Determines whether the linear feedback shift register (LSFR)
    /// used to generate noise has an effective width of 15 or 7 bits.
    /// This determines the length of period before the noise waveform
    /// is repeated.
    mode: Mode = .bits_15,
    /// Frequency timer period is set by the divisor shifted left
    /// by this many bits.
    shift: u4 = 0,
    /// Unused bits.
    _: u6 = 0,
    /// Timed flag. If set, the sound plays for a duration determined
    /// by the channel's ctrl.len field. If clear, it plays indefinitely,
    /// although it may become inaudible depending on the volume envelope.
    timed: bool = false,
    /// Sound reset. Resets sound to the initial volume and sweep
    /// settings.
    reset: bool = false,
};

/// Represents the contents of REG_SNDCNT, which contains REG_SNDDMGCNT and
/// REG_SNDDSCNT.
pub const Control = packed struct(u32) {
    /// Represents the contents of the REG_SNDDMGCNT sound control register.
    pub const Dmg = packed struct(u16) {
        /// Master volume for left speaker.
        volume_left: u3 = 0,
        /// Unused bits.
        _1: u1 = 0,
        /// Master volume for right speaker.
        volume_right: u3 = 0,
        /// Unused bits.
        _2: u1 = 0,
        /// Enable pulse 1 channel for left speaker.
        left_pulse_1: bool = false,
        /// Enable pulse 2 channel for left speaker.
        left_pulse_2: bool = false,
        /// Enable wave channel for left speaker.
        left_wave: bool = false,
        /// Enable noise channel for left speaker.
        left_noise: bool = false,
        /// Enable pulse 1 channel for right speaker.
        right_pulse_1: bool = false,
        /// Enable pulse 2 channel for right speaker.
        right_pulse_2: bool = false,
        /// Enable wave channel for right speaker.
        right_wave: bool = false,
        /// Enable noise channel for right speaker.
        right_noise: bool = false,
        
        pub fn init(
            volume_left: u3,
            volume_right: u3,
            enable_left: ChannelFlags,
            enable_right: ChannelFlags,
        ) Dmg {
            return .{
                .volume_left = volume_left,
                .volume_right = volume_right,
                .left_pulse_1 = enable_left.pulse_1,
                .left_pulse_2 = enable_left.pulse_2,
                .left_wave = enable_left.wave,
                .left_noise = enable_left.noise,
                .right_pulse_1 = enable_right.pulse_1,
                .right_pulse_2 = enable_right.pulse_2,
                .right_wave = enable_right.wave,
                .right_noise = enable_right.noise,
            };
        }
    };

    /// Represents the contents of the DirectSound control register
    /// REG_SNDDSCNT.
    pub const DirectSound = packed struct(u16) {
        /// Enumeration of volume options for DMG channels.
        pub const DmgVolume = enum(u2) {
            /// 25% DMG volume ratio
            percent_25 = 0b00,
            /// 50% DMG volume ratio
            percent_50 = 0b01,
            /// 100% DMG volume ratio
            percent_100 = 0b10,
        };

        /// Enumeration of volume options for DirectSound channels.
        pub const DirectSoundVolume = enum(u1) {
            /// 50% DirectSound A/B volume ratio
            percent_50 = 0,
            /// 100% DirectSound A/B volume ratio
            percent_100 = 1,
        };

        /// Relative volume of DMG channels.
        volume_dmg: DmgVolume = .percent_25,
        /// Relative volume of DirectSound channel A.
        volume_a: DirectSoundVolume = .percent_50,
        /// Relative volume of DirectSound channel B.
        volume_b: DirectSoundVolume = .percent_50,
        /// Unused bits.
        _: u4 = 0,
        /// Enable DirectSound A on left speaker.
        left_a: bool = false,
        /// Enable DirectSound A on right speaker.
        right_a: bool = false,
        /// Indicates which timer should be used for DirectSound A.
        timer_a: u1 = 0,
        /// FIFO reset for DirectSound A. When using DMA for DirectSound,
        /// this will cause DMA to reset the FIFO buffer after it's used.
        reset_a: bool = false,
        /// Enable DirectSound B on left speaker.
        left_b: bool = false,
        /// Enable DirectSound B on right speaker.
        right_b: bool = false,
        /// Indicates which timer should be used for DirectSound B.
        timer_b: u1 = 0,
        /// FIFO reset for DirectSound B. When using DMA for DirectSound,
        /// this will cause DMA to reset the FIFO buffer after it's used.
        reset_b: bool = false,
    };
    
    /// Corresponds to REG_SNDDMGCNT.
    dmg: Dmg = .{},
    /// Corresponds to REG_SNDDSCNT.
    dsound: DirectSound = .{},
}

/// Represents the contents of REG_SNDSTAT.
pub const Status = packed struct(u16) {
    /// Whether the Pulse 1 channel should be currently playing.
    pulse_1: bool = false,
    /// Whether the Pulse 2 channel should be currently playing.
    pulse_2: bool = false,
    /// Whether the Wave channel should be currently playing.
    wave: bool = false,
    /// Whether the Noise channel should be currently playing.
    noise: bool = false,
    /// Unused bits.
    _1: u3 = 0,
    /// Master sound enable. Must be set if any sound is to be
    /// heard at all.
    master: bool,
    /// Unused bits.
    _2: u8 = 0,
    
    pub fn init(master: bool, channels: ChannelFlags) Status {
        return .{
            .master = master,
            .pulse_1 = channels.pulse_1,
            .pulse_2 = channels.pulse_2,
            .wave = channels.wave,
            .noise = channels.noise,
        };
    }
};

/// Represents the contents of REG_SNDBIAS.
pub const Bias = packed struct(u16) {
    pub const Cycle = enum(u2) {
        /// 32.768 kHz. (Default, best for DMA channels A, B.)
        bits_9 = 0,
        /// 65.536 kHz.
        bits_8 = 1,
        /// 131.072 kHz.
        bits_7 = 2,
        /// 262.144 kHz. (Best for PSG channels 1-4.)
        bits_6 = 3,
    };

    /// Unused bits.
    _1: u1 = 0,
    /// Bias level, converting signed samples into unsigned.
    level: u9 = 0x100,
    /// Unused bits.
    _2: u4 = 0,
    /// Amplitude resolution/sampling cycle.
    cycle: Cycle = .bits_9,
};

/// Encapsulates sound registers relating to channel 1 (Pulse 1).
pub const PulseChannel1 = extern struct {
    pub const Sweep = PulseChannelSweep;
    pub const Control = PulseChannelControl;
    pub const Frequency = PulseChannelFrequency;
    
    /// Control pitch sweep in channel 1 (Pulse 1).
    /// Corresponds to tonc REG_SND1SWEEP.
    sweep: Sweep,
    /// Control length, duty, and envelope in channel 1 (Pulse 1).
    /// Corresponds to tonc REG_SND1CNT.
    ctrl: Control,
    /// Control rate (determines pitch/frequency) in channel 1 (Pulse 1).
    /// Corresponds to tonc REG_SND1FREQ.
    freq: Frequency,
}

/// Encapsulates sound registers relating to channel 2 (Pulse 2).
pub const PulseChannel2 = extern struct {
    pub const Control = PulseChannelControl;
    pub const Frequency = PulseChannelFrequency;
    
    /// Control length, duty, and envelope in channel 2 (Pulse 2).
    /// Corresponds to tonc REG_SND2CNT.
    ctrl: Control,
    /// Control rate (determines pitch/frequency) in channel 2 (Pulse 2).
    /// Corresponds to tonc REG_SND2FREQ.
    freq: Frequency,
}

/// Encapsulates sound registers relating to channel 3 (Wave).
pub const WaveChannel = extern struct {
    pub const Select = WaveChannelSelect;
    pub const Control = WaveChannelControl;
    pub const Frequency = WaveChannelFrequency;
    
    /// Waveform select for channel 3 (Wave).
    /// Corresponds to REG_SND3SEL.
    select: Select,
    /// Control length and volume in channel 3 (Wave).
    /// Corresponds to tonc REG_SND3CNT.
    ctrl: Control,
    /// Control rate (determines pitch/frequency) in channel 3 (Wave).
    /// Corresponds to tonc REG_SND3FREQ.
    freq: Frequency,
}

/// Encapsulates sound registers relating to channel 4 (Noise).
pub const NoiseChannel = extern struct {
    pub const Control = NoiseChannelControl;
    pub const Frequency = NoiseChannelFrequency;
    
    /// Control length and envelope in channel 4 (Noise).
    /// Corresponds to tonc REG_SND4CNT.
    ctrl: Control,
    /// Control the frequency and quality of noise in channel 4 (Noise).
    /// Corresponds to tonc REG_SND4FREQ.
    freq: Frequency,
}

/// Refers to hardware registers used to affect PSG channel 1 (Pulse 1).
pub const pulse_1: *volatile PulseChannel1 = @ptrCast(gba.mem.io.reg_snd1sweep);

/// Refers to hardware registers used to affect PSG channel 2 (Pulse 2).
pub const pulse_2: *volatile PulseChannel2 = @ptrCast(gba.mem.io.reg_snd2cnt);

/// Refers to hardware registers used to affect PSG channel 3 (Wave).
pub const wave: *volatile WaveChannel = @ptrCast(gba.mem.io.reg_snd3sel);

/// Refers to hardware registers used to affect PSG channel 4 (Noise).
pub const noise: *volatile NoiseChannel = @ptrCast(gba.mem.io.reg_snd4cnt);

/// Corresponds to tonc REG_SNDCNT.
pub const ctrl: *volatile Control = @ptrCast(gba.mem.io.reg_sndcnt);

/// Corresponds to tonc REG_SNDSTAT.
pub const status: *volatile Status = @ptrCast(gba.mem.io.reg_sndstat);

/// Corresponds to tonc REG_SNDBIAS.
pub const bias: *volatile Bias = @ptrCast(gba.mem.io.reg_sndbias);

/// Corresponds to tonc REG_WAVE_RAMx.
pub const wave_ram: *volatile [4]u32 = @ptrCast(gba.mem.io.reg_wave_ramx);

/// Corresponds to tonc REG_FIFO_A.
pub const fifo_a: *volatile [4]u8 = @ptrCast(gba.mem.io.reg_fifo_a);

/// Corresponds to tonc REG_FIFO_B.
pub const fifo_b: *volatile [4]u8 = @ptrCast(gba.mem.io.reg_fifo_b);
