//! This module implements an API for persistent save data on a cartridge,
//! also referred to as "cart backup" in GBATEK documentation.
//! Use build options to select a save data type.

const gba = @import("gba.zig");
const assert = @import("std").debug.assert;

const build_options = @import("ziggba_build_options");

/// Enumeration of supported cartridge save data types.
pub const SaveType = enum(u3) {
    none = 0,
    // eeprom_512b = 1, // TODO
    // eeprom_8kb = 2, // TODO
    sram_32kb = 3,
    flash_64kb = 4,
    flash_128kb = 5,
};

pub const SaveSram = struct {

};

pub const SaveFlash64kb = struct {
    /// Total size of save data, in bytes.
    pub const len: u32 = 0x10000;
    
    /// Set memory timing appropriately via the WAITCNT hardware register.
    /// This function should be called before reading or writing.
    pub fn init() void {
        gba.mem.wait_ctrl.sram = .cycles_8;
    }
    
    /// Read bytes from SRAM into a destination buffer.
    /// Don't use a destination in VRAM.
    pub fn read(
        destination: *volatile anyopaque,
        sram_offset: u32,
        count_bytes: u32,
    ) void {
        assert(sram_offset + count_bytes <= len);
        // Note: Reading from SRAM using code stored in ROM may fail
        // on hardware in some cases. (But probably not?)
        // Just in case, the `memcpy8` function runs from IWRAM.
        // https://www.problemkaputt.de/gbatek.htm#gbacartbackupsramfram
        // https://discord.com/channels/768759024270704641/829850171151876127/1416850967479062600
        gba.mem.memcpy8(destination, &gba.mem.sram[sram_offset], count_bytes);
    }
    
    /// Write bytes from a destination buffer into SRAM.
    pub fn write(
        sram_offset: u32,
        source: *volatile anyopaque,
        count_bytes: u32,
    ) void {
        assert(sram_offset + count_bytes <= len);
        gba.mem.memcpy8(&gba.mem.sram[sram_offset], source, count_bytes);
    }
    
    /// Write bytes into SRAM.
    pub fn fill(
        sram_offset: u32,
        value: u8,
        count_bytes: u32,
    ) void {
        assert(sram_offset + count_bytes <= len);
        gba.mem.memset8(&gba.mem.sram[sram_offset], value, count_bytes);
    }
};

pub const Save = switch(build_options.save_type) {
    .none => void,
    // .eeprom_512b => SaveEeprom.init(0x200),
    // .eeprom_8kb => SaveEeprom.init(0x2000),
    .sram_32kb => SaveSram,
    .flash_64kb => SaveFlash.init(0x10000),
    .flash_128kb => SaveFlash.init(0x20000),
};
