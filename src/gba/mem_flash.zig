// References:
// https://github.com/laqieer/libsavgba/blob/main/src/gba_flash.c
// https://github.com/Lorenzooone/Pokemon-Gen3-to-Gen-X/blob/main/source/save.c
// https://gitea.com/akouzoukos/apotris/src/branch/main/source/flashSaves.cpp

/// Size in bytes of a single 64kb bank of flash memory.
pub const flash_bank_size = 0x10000;

/// Enumeration of known flash chip sizes.
pub const FlashSize = enum(u1) {
    /// Single 64-kilobyte bank.
    size_64kb = 0,
    /// Two 64-kilobyte banks.
    size_128kb = 1,
    
    /// Get the total number of bytes associated with a given flash chip size.
    pub fn getLength(self: FlashSize) u32 {
        return switch(self) {
            .size_64kb => 0x10000,
            .size_128kb => 0x20000,
        };
    }
};

/// Enumeration of known flash chip manufacturers.
pub const FlashManufacturer = enum(u8) {
    atmel = 0x1f,
    panasonic = 0x32,
    sanyo = 0x62,
    sst = 0xbf,
    macronix = 0xc2,
};

/// Enumeration of known flash chip devices.
pub const FlashDevice = enum(u8) {
    /// Macronix MX29L010TC-15A1
    mx29l010 = 0x09,
    /// Sanyo LE26FV10N1TS
    le26fv10n1ts = 0x13,
    /// Panasonic MN63F805MNP
    mn63f805mnp = 0x1b,
    /// Macronix MX29L512
    mx29l512 = 0x1c,
    /// Atmel AT29LV512
    at29lv512 = 0x3d,
    /// Exact model not clear from the documentation I could find.
    /// Apparently could be SST39LF512, SST39VF512, or a Sanyo chip.
    /// See also: https://reinerziegler.de.mirrors.gg8.se/GBA/LE39FW512.pdf
    le39fw512 = 0xd4,
    
    /// Get whether a given device has one bank or two banks.
    pub fn getSize(self: FlashDevice) FlashSize {
        return switch(self) {
            mx29l010 => true,
            le26fv10n1ts => true,
            else => false,
        };
    }
    
    /// Get fastest allowed memory timing for reads with a given device.
    /// See also `gba.mem.WaitControl.sram`.
    pub fn getReadCycles(self: FlashDevice) gba.mem.WaitControl.Cycles2 {
        return switch(self) {
            mx29l010 => .cycles_8, // Not documented, assume worst case
            le26fv10n1ts => .cycles_8, // Not documented, assume worst case
            mn63f805mnp => .cycles_2, // 4,2
            mx29l512 = .cycles_3, // 8,3
            at29lv512 = .cycles_8, // 8,8
            le39fw512 = .cycles_2, // 3,2
        };
    }
    
    /// Get fastest allowed memory timing for writes with a given device.
    /// See also `gba.mem.WaitControl.sram`.
    pub fn getWriteCycles(self: FlashDevice) gba.mem.WaitControl.Cycles2 {
        return switch(self) {
            mx29l010 => .cycles_8, // Not documented, assume worst case
            le26fv10n1ts => .cycles_8, // Not documented, assume worst case
            mn63f805mnp => .cycles_4, // 4,2
            mx29l512 = .cycles_8, // 8,3
            at29lv512 = .cycles_8, // 8,8
            le39fw512 = .cycles_3, // 3,2
        };
    }
};

/// Enumeration of flash chip command opcodes.
const FlashCommand = enum(u4) {
    erase_chip = 0x10,
    erase_sector = 0x30,
    erase = 0x80,
    enter_id_mode = 0x90,
    write = 0xa0,
    set_bank = 0xb0,
    exit_id_mode = 0xf0,
};

/// Flash chip commands occur by writing special values to this address,
/// as well as to `flash_cmd_1`.
const flash_cmd_0: *volatile u8 = @ptrFromInt(gba.mem.sram_address + 0x5555);

/// Flash chip commands occur by writing special values to this address,
/// as well as to `flash_cmd_0`.
const flash_cmd_1: *volatile u8 = @ptrFromInt(gba.mem.sram_address + 0x2aaa);

/// Implement a common save data interface for flash chips.
pub const FlashSave = struct {
    manufacturer: FlashManufacturer,
    device: FlashDevice,
    
    manufacturer_atmel: bool,
    write_timeout_terminate_cmd: bool,
    size: FlashSize,
    read_cycles: gba.mem.WaitControl.Cycles2,
    write_cycles: gba.mem.WaitControl.Cycles2,
    
    pub fn initDevice(
        manufacturer: FlashManufacturer,
        device: FlashDevice,
    ) FlashSave {
        return .{
            .manufacturer = manufacturer,
            .device = device,
            
            .manufacturer_atmel = (manufacturer == .atmel),
            .write_timeout_terminate_cmd = (device == .mx29l512),
            .size = device.getSize(),
            .read_cycles = device.getReadCycles(),
            .write_cycles = device.getWriteCycles(),
        };
    }
    
    pub fn getSize(self: FlashSave) FlashSize {
        return self.device.getSize();
    }
    
    pub fn getReadCycles(self: FlashSave) gba.mem.WaitControl.Cycles2 {
        return self.device.getReadCycles();
    }
    
    pub fn getWriteCycles(self: FlashSave) gba.mem.WaitControl.Cycles2 {
        return self.device.getWriteCycles();
    }
    
    /// Set SRAM timing via WAITCNT to the fastest supported read speed.
    /// Use this before reading from the flash chip to get a performance
    /// increase in some cases. It is NOT required.
    /// If you use this, however, do not forget to also call `setWriteTiming`
    /// before writing.
    pub fn setReadTiming(self: FlashSave) void {
        gba.mem.wait_ctrl.sram = self.getReadCycles();
    }
    
    /// Set SRAM timing via WAITCNT to the fastest supported write speed.
    /// If you use `setReadTiming` to potentially gain performance when reading,
    /// then you must call this function after reading and before writing.
    /// If you do not ever call `setReadTiming`, or otherwise make changes to
    /// SRAM timing, then this function is NOT required.
    pub fn setWriteTiming(self: FlashSave) void {
        gba.mem.wait_ctrl.sram = self.getWriteCycles();
    }
    
    /// Get the number of bytes of available flash memory.
    pub fn getLength(self: FlashSave) u32 {
        return self.size.getLength();
    }

    /// Read bytes from a flash chip into a destination buffer.
    /// Reads and writes one byte at a time.
    pub fn read(
        self: FlashSave,
        destination: *volatile anyopaque,
        save_offset: u32,
        count_bytes: u32,
    ) void {
        // Note: Reading from flash memory using code stored in ROM may fail
        // on hardware. Accordingly, the `memcpy8` function runs from IWRAM.
        if(self.size == .size_128kb) {
            assert(save_offset < (2 * flash_bank_size));
            if(save_offset >= flash_bank_size) {
                flashSetBank(1);
                gba.mem.memcpy8(
                    destination,
                    &gba.mem.sram_flash[save_offset - flash_bank_size],
                    count_bytes,
                );
            }
            else if(save_offset + count_bytes <= flash_bank_size) {
                flashSetBank(0);
                gba.mem.memcpy8(
                    destination,
                    &gba.mem.sram_flash[save_offset],
                    count_bytes,
                );
            }
            else {
                var dest_8: [*]volatile u8 = @ptrCast(destination);
                const bank_0_len = flash_bank_size - save_offset;
                flashSetBank(0);
                gba.mem.memcpy8(
                    dest_8,
                    &gba.mem.sram_flash[save_offset],
                    bank_0_len,
                );
                flashSetBank(1);
                gba.mem.memcpy8(
                    &dest_8[bank_0_len],
                    &gba.mem.sram_flash[0],
                    count_bytes - bank_0_len,
                );
            }
        }
        else {
            assert(save_offset + count_bytes <= flash_bank_size);
            gba.mem.memcpy8(
                destination,
                &gba.mem.sram_flash[save_offset],
                count_bytes,
            );
        }
    }
    
    /// Read a single byte from the flash chip.
    pub fn readByte(
        save_offset: u32,
    ) u8 {
        var data: u8 = undefined;
        if(self.size == .size_128kb) {
            assert(save_offset < (2 * flash_bank_size));
            if(save_offset >= flash_bank_size) {
                flashSetBank(1);
                gba.mem.memcpy8(
                    &data,
                    &gba.mem.sram_flash[save_offset - flash_bank_size],
                    count_bytes,
                );
                return data;
            }
            else {
                flashSetBank(0);
                gba.mem.memcpy8(
                    &data,
                    &gba.mem.sram_flash[save_offset],
                    count_bytes,
                );
                return data;
            }
        }
        else {
            assert(save_offset < flash_bank_size);
            gba.mem.memcpy8(
                &data,
                &gba.mem.sram_flash[save_offset],
                1,
            );
            return data;
        }
    }
    
    pub fn clearSector(
        self: FlashSave,
        save_offset: u32,
    ) void {
        // TODO: Atmel works differently
        const sector_offset = save_offset & 0xfffff000;
        
    }
    
    pub fn clearOverlappingSectors(
        self: FlashSave,
        save_offset: u32,
        count_bytes: u32,
    ) void {
    }
    
    /// Write bytes from a destination buffer into flash memory.
    /// This function assumes that the memory being written to was previously
    /// cleared.
    /// Beware: It's possible (though unlikely) that some bytes could silently
    /// fail to write!
    pub fn write(
        self: FlashSave,
        save_offset: u32,
        source: *anyopaque,
        count_bytes: u32,
    ) void {
        const source_8: [*]u8 = @ptrCast(source);
        for(0..count_bytes) |i| {
            self.writeByte(@intCast(save_offset + i), source[i]);
        }
    }
    
    /// Write a single byte to the flash chip.
    /// This function assumes that the memory being written to was previously
    /// cleared.
    /// Beware: It's possible (though unlikely) that this could silently fail!
    pub fn writeByte(save_offset: u32, value: u8) void {
        for(0..3) |_| {
            if(self.readByte(save_offset) == value) {
                return;
            }
            self.writeByteOnce(save_offset, value);
            gba.mem.memwait8(10000, &gba.mem.sram_flash[save_offset], value);
        }
    }
    
    /// Helper used by `writeByte`.
    /// Represents a single attempt to write a byte to the flash chip.
    /// Flash chips can apparently be flaky, so `writeByte` calls this
    /// function multiple times.
    fn writeByteOnce(save_offset: u32, value: u8) void {
        flashCommand(.write);
        if(self.size == .size_128kb) {
            assert(save_offset < (2 * flash_bank_size));
            if(save_offset >= flash_bank_size) {
                flashSetBank(1);
                gba.mem.memcpy8(
                    &data,
                    &gba.mem.sram_flash[save_offset - flash_bank_size],
                    count_bytes,
                );
                return data;
            }
            else {
                flashSetBank(0);
                gba.mem.memcpy8(
                    &data,
                    &gba.mem.sram_flash[save_offset],
                    count_bytes,
                );
                return data;
            }
        }
        else {
            assert(save_offset < flash_bank_size);
            gba.mem.memcpy8(
                &data,
                &gba.mem.sram_flash[save_offset],
                1,
            );
            return data;
        }
    }
    
    /// Write bytes into flash memory.
    pub fn fill(
        self: FlashSave,
        save_offset: u32,
        value: u8,
        count_bytes: u32,
    ) void {
    }
    
    /// Compare bytes in flash chip memory.
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
    
    /// After instructing the flash chip to write a byte, repeatedly
    /// read from that address until the write is confirmed, or until
    /// a timeout period passes.
    /// Returns `true` when the operation timed out, or `false` when
    /// it was successful.
    fn waitUntilWritten(
        self: FlashSave,
        save_offset: u32,
        value: u8,
    ) bool {
        // Expected timeout: About 20 milliseconds
        var i: u32 = 0;
        while(i < 18000) {
            if(self.compare(save_offset, &value, 1) == 0) {
                return false;
            }
            i += 1;
        }
        // Some devices expect a termination command upon timeout
        if(self.device == .mx29l512) {
            flash_cmd_0.* = 0xf0;
        }
        return true;
    }
};

/// Helper to execute a given flash chip command.
fn flashCommand(cmd: FlashCommand) void {
    flash_cmd_0.* = 0xaa;
    flash_cmd_1.* = 0x55;
    flash_cmd_0.* = @intFromEnum(cmd);
}

/// Helper to switch banks in larger flash chips.
/// Only supported for 128kb chips.
fn flashSetBank(bank: u1) void {
    flashCommand(.set_bank);
    gba.mem.sram_flash[0] = bank;
}

/// Helper to wait 20 milliseconds.
/// This is needed for compatibility with the Atmel AT29LV512.
fn wait20ms() void {
    // TODO: Time this loop to verify that it does in fact take 20ms
    var i: u32 = 0;
    while(i < 20000) {
        asm volatile (""); // Don't optimize away this loop
        i++;
    }
}

/// Check flash chip hardware and return an object which can be used
/// to read and write save data.
pub fn flashSaveInit() FlashSave {
    // Use slowest wait state for initial detection.
    // After device detection, smaller wait values may be used.
    gba.mem.wait_ctrl.sram = .cycles_8;
    // Enter ID mode to identify the flash chip
    flashCommand(.enter_id_mode);
    // Atmel docs say to wait 20ms when entering or exiting ID mode
    wait20ms();
    // Get flash chip info
    const manufacturer: FlashManufacturer = @enumFromInt(gba.mem.sram_flash[0]);
    const device: FlashDevice = @enumFromInt(gba.mem.sram_flash[1]);
    // Leave ID mode
    flashCommand(.exit_id_mode);
    // Atmel docs say to wait 20ms when entering or exiting ID mode
    wait20ms();
    // 128K sanyo flash exceptionally needs to the exit code written twice.
    if(device == .le26fv10n1ts) {
        flash_cmd_0.* = @intFromEnum(FlashCommand.exit_id_mode);
    }
    // Initialize save helper
    const save: FlashSave = .initDevice(manufacturer, device);
    // Set wait state according to detected device
    save.setWriteTiming();
    // All done!
    return save;
}

