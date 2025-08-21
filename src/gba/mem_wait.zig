//! Provides an interface for wait state control.

/// Describes the contents of REG_WAITCNT.
pub const WaitControl = packed struct(u16) {
    /// Reflects the uninitialized state of REG_WAITCNT at startup.
    pub const startup: WaitControl = .{};
    
    /// Real GBA catridges normally initialize REG_WAITCNT to this
    /// configuration (0x4317).
    pub const default: WaitControl = .{
        .sram = .cycles_8,
        .first_0 = .cycles_3,
        .second_0 = .cycles_1,
        .first_2 = .cycles_8,
        .second_2 = .cycles_8,
        .prefetch = true,
    };
    
    pub const Cycles2 = enum(u2) {
        cycles_4 = 0,
        cycles_3 = 1,
        cycles_2 = 2,
        cycles_8 = 3,
    };
    
    pub const CyclesSecond0 = enum(u1) {
        cycles_2 = 0,
        cycles_1 = 1,
    };
    
    pub const CyclesSecond1 = enum(u1) {
        cycles_4 = 0,
        cycles_1 = 1,
    };
    
    pub const CyclesSecond2 = enum(u1) {
        cycles_8 = 0,
        cycles_1 = 1,
    };
    
    pub const TerminalOutput = enum(u2) {
        disable = 0,
        /// 4.19MHz.
        mhz_4_19 = 1,
        /// 8.38MHz.
        mhz_8_38 = 2,
        /// 16.78MHz.
        mhz_16_78 = 3,
    };
    
    pub const GamepakType = enum(u2) {
        /// Game Boy Advance game pak.
        gba = 0,
        /// Game Boy Color game pak.
        gbc = 1,
    };
    
    /// Timing for cartridge SRAM.
    sram: Cycles2 = .cycles_4,
    /// First (non-sequential) access timing for wait state 0 (ROM).
    first_0: Cycles2 = .cycles_4,
    /// Second (sequential) access timing for wait state 0 (ROM).
    second_0: CyclesSecond0 = .cycles_2,
    /// First (non-sequential) access timing for wait state 1.
    first_1: Cycles2 = .cycles_4,
    /// Second (sequential) access timing for wait state 1.
    second_1: CyclesSecond1 = .cycles_4,
    /// First (non-sequential) access timing for wait state 2 (EEPROM).
    first_2: Cycles2 = .cycles_4,
    /// Second (sequential) access timing for wait state 2 (EEPROM).
    second_2: CyclesSecond2 = .cycles_8,
    /// PHI terminal output.
    terminal: TerminalOutput = .disable,
    /// Unused bit.
    _1: u1,
    /// Enable or disable gamepak prefetch buffer.
    prefetch: bool = false,
    /// Gamepak type flag. Read-only.
    gamepak: GamepakType = .gba,
};

/// Corresponds to REG_WAITCNT.
pub const wait_ctrl: *volatile WaitControl = @ptrCast(gba.mem.io.reg_waitcnt);
