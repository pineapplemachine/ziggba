/// Set memory timing appropriately via the WAITCNT hardware register.
/// This function should be called before reading or writing.
pub fn sramSaveInit() Sram {
    gba.mem.wait_ctrl.sram = .cycles_8;
    return .{};
}

/// Implement a common save data interface for SRAM/FRAM.
pub const SramSave = struct {
    /// Get the number of bytes of available SRAM/FRAM.
    pub fn getLength() u32 {
        return gba.mem.sram.len;
    }
    
    /// Read bytes from SRAM/FRAM into a destination buffer.
    /// Reads and writes one byte at a time.
    pub fn read(
        destination: *volatile anyopaque,
        save_offset: u32,
        count_bytes: u32,
    ) void {
        // Note: Reading from SRAM using code stored in ROM may fail
        // on hardware in some cases. (But probably not?)
        // Just in case, the `memcpy8` function runs from IWRAM.
        // https://www.problemkaputt.de/gbatek.htm#gbacartbackupsramfram
        // https://discord.com/channels/768759024270704641/829850171151876127/1416850967479062600
        assert(save_offset + count_bytes <= gba.mem.sram.len);
        gba.mem.memcpy8(destination, &gba.mem.sram[save_offset], count_bytes);
    }
    
    /// Read a single byte from SRAM/FRAM.
    pub fn readByte(
        save_offset: u32,
    ) u8 {
        assert(save_offset < gba.mem.sram.len);
        var data: u8 = undefined;
        SramSave.read(&data, save_offset, 1);
        return data;
    }
    
    /// Write bytes from a destination buffer into SRAM/FRAM.
    pub fn write(
        save_offset: u32,
        source: *volatile anyopaque,
        count_bytes: u32,
    ) void {
        assert(save_offset + count_bytes <= gba.mem.sram.len);
        gba.mem.memcpy8(&gba.mem.sram[save_offset], source, count_bytes);
    }
    
    /// Write a single byte to SRAM/FRAM.
    pub fn writeByte(
        save_offset: u32,
        value: u8,
    ) void {
        assert(save_offset < gba.mem.sram.len);
        gba.mem.sram[save_offset] = value;
    }
    
    /// Write bytes into SRAM/FRAM.
    pub fn fill(
        save_offset: u32,
        value: u8,
        count_bytes: u32,
    ) void {
        assert(save_offset + count_bytes <= gba.mem.sram.len);
        gba.mem.memset8(&gba.mem.sram[save_offset], value, count_bytes);
    }
    
    /// Compare bytes in SRAM/FRAM.
    /// Returns zero when bytes are equal. Returns a nonzero value otherwise.
    pub fn compare(
        save_offset: u32,
        source: *volatile anyopaque,
        count_bytes: u32,
    ) i32 {
        // Note: Reading from SRAM using code stored in ROM may fail
        // on hardware in some cases. (But probably not?)
        // Just in case, the `memcmp8` function runs from IWRAM.
        assert(save_offset + count_bytes <= gba.mem.sram.len);
        return gba.mem.memcmp8(&gba.mem.sram[save_offset], source, count_bytes);
    }
};
