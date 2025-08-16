const gba = @import("gba.zig");

/// DMA (direct memory access) can be used to copy or fill data between
/// regions in memory.
/// You should expect DMA copies to be little faster than `gba.bios.cpuFastCopy`
/// and fills to be a little slower than `gba.bios.cpuFastSet`.
/// The faster copies come with the tradeoff of disabling interrupts while the
/// operation is ongoing, because the CPU is stopped while the DMA controller
/// does its work.
///
/// Note that source and destination addresses only use the least significant
/// 27 bits (for internal memory) or 28 bits (for any memory)
pub const Dma = packed struct {
    pub const DestinationAdjustment = enum(u2) {
        /// Increment after each transfer.
        increment = 0,
        /// Decrement after each transfer.
        decrement = 1,
        /// Address is fixed.
        fixed = 2,
        /// Increment the destination during the transfer, and reset it so
        /// that repeat DMA will always start at the same destination. 
        reload = 3,
    };

    pub const SourceAdjustment = enum(u2) {
        /// Increment after each transfer.
        increment = 0,
        /// Decrement after each transfer.
        decrement = 1,
        /// Address is fixed.
        fixed = 2,
    };

    pub const Size = enum(u1) {
        /// Transfer 16-bit half-words.
        bits_16,
        /// Transfer 32-bit words.
        bits_32,
    };

    /// Enumeration of DMA timing modes.
    pub const Timing = enum(u2) {
        /// Start transfer immediately.
        immediate = 0,
        /// Start transfer at VBlank.
        vblank = 1,
        /// Start transfer at HBlank.
        hblank = 2,
        /// DMA0: Forbidden.
        ///
        /// DMA1-2: Sound FIFO.
        ///
        /// DMA3: Video Capture.
        special = 3,
    };

    /// Represents the contents of REG_DMAxCNT registers.
    pub const Control = packed struct(u32) {
        /// Number of transfers.
        /// Counts the number of words or half-words to transfer, depending
        /// on `size`.
        /// For DMA0-2, only the low 14 bits are used.
        /// A value of zero is treated as max length, i.e. 0x4000 for DMA0-2
        /// or 0x10000 for DMA3.
        count: u16 = 0,
        /// Unused bits.
        _: u5 = 0,
        /// Destination pointer adjustment.
        dest: DestinationAdjustment = .increment,
        /// Source pointer adjustment.
        source: SourceAdjustment = .increment,
        /// Repeats the copy at each VBlank or HBlank if the DMA timing has
        /// been set to those modes. 
        /// Must be false if gamepak_drq is used (DMA3 only).
        dma_repeat: bool = false,
        /// Whether to copy by 32-bit word or 16-bit half-word.
        size: Size = .bits_16,
        /// DMA3 only.
        gamepak_drq: bool = false,
        /// Timing mode. Specifies when the transfer should start. 
        timing: Timing = .immediate,
        /// Interrupt request. If set, then an interrupt will be raised
        /// upon finishing the transfer.
        interrupt: bool = false,
        /// Enable DMA transfer for this channel.
        enabled: bool = false,
    };

    /// Source pointer to copy memory from.
    /// For DMA 0, can only be internal memory.
    source: *const volatile anyopaque,
    /// Destination pointer to copy memory to.
    /// For DMA 0-2, can only be internal memory.
    dest: *volatile anyopaque,
    /// Indicates various parameters for the transfer, including length.
    ctrl: Control,
};

/// Direct memory access.
pub const dma: *[4]Dma = @ptrFromInt(gba.mem.io + 0xB0);
