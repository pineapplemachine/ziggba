const std = @import("std");

/// Represents the structure and contents of a standard GBA ROM header.
///
/// You should use `Header.init` to initialize a header, since initialization
/// includes computing a checksum.
pub const Header = extern struct {
    /// Error type that may be returned when validating header strings.
    pub const StringValidationError = error{
        /// The string was too long or too short.
        InvalidLength,
        /// The string contained an invalid character.
        InvalidCharacter,
    };
    
    /// Encodes a relative jump past the end of the header in ARM.
    ///
    /// EA 00 is an unconditional jump without linking.
    /// 00 2E is an offset. Jump ahead `(0x2E << 2) + 8`, past end of header.
    rom_entry_point: u32 align(1) = 0xEA00002E,
    /// Contains the Nintendo logo which is displayed during the boot procedure.
    ///
    /// You probably don't want to modify this. Doing so will normally cause
    /// the cartridge to not work.
    nintendo_logo: [156]u8 align(1) = .{
        0x24, 0xFF, 0xAE, 0x51, 0x69, 0x9A, 0xA2, 0x21, 0x3D, 0x84, 0x82, 0x0A, 0x84,
        0xE4, 0x09, 0xAD, 0x11, 0x24, 0x8B, 0x98, 0xC0, 0x81, 0x7F, 0x21, 0xA3, 0x52,
        0xBE, 0x19, 0x93, 0x09, 0xCE, 0x20, 0x10, 0x46, 0x4A, 0x4A, 0xF8, 0x27, 0x31,
        0xEC, 0x58, 0xC7, 0xE8, 0x33, 0x82, 0xE3, 0xCE, 0xBF, 0x85, 0xF4, 0xDF, 0x94,
        0xCE, 0x4B, 0x09, 0xC1, 0x94, 0x56, 0x8A, 0xC0, 0x13, 0x72, 0xA7, 0xFC, 0x9F,
        0x84, 0x4D, 0x73, 0xA3, 0xCA, 0x9A, 0x61, 0x58, 0x97, 0xA3, 0x27, 0xFC, 0x03,
        0x98, 0x76, 0x23, 0x1D, 0xC7, 0x61, 0x03, 0x04, 0xAE, 0x56, 0xBF, 0x38, 0x84,
        0x00, 0x40, 0xA7, 0x0E, 0xFD, 0xFF, 0x52, 0xFE, 0x03, 0x6F, 0x95, 0x30, 0xF1,
        0x97, 0xFB, 0xC0, 0x85, 0x60, 0xD6, 0x80, 0x25, 0xA9, 0x63, 0xBE, 0x03, 0x01,
        0x4E, 0x38, 0xE2, 0xF9, 0xA2, 0x34, 0xFF, 0xBB, 0x3E, 0x03, 0x44, 0x78, 0x00,
        0x90, 0xCB, 0x88, 0x11, 0x3A, 0x94, 0x65, 0xC0, 0x7C, 0x63, 0x87, 0xF0, 0x3C,
        0xAF, 0xD6, 0x25, 0xE4, 0x8B, 0x38, 0x0A, 0xAC, 0x72, 0x21, 0xD4, 0xF8, 0x07,
    },
    /// A game name string contains at most 12 upper-case alphanumeric
    /// ASCII characters, padded with null bytes.
    game_name: [12]u8 align(1) = @splat(0),
    /// A game code string contains four upper-case alphanumeric ASCII
    /// characters.
    ///
    /// By convention, a game code has three parts:
    /// - A unique code. "A" or "B" for most games.
    /// - A short title, e.g. a two-letter abbreviation of the game title.
    /// - Destination or language. Usually "J", "E", or "P".
    ///
    /// List of known unique codes and their meanings:
    /// - A: Normal game; Older titles (mainly 2001..2003)
    /// - B: Normal game; Newer titles (2003..)
    /// - C: Normal game; Not used yet, but might be used for even newer titles
    /// - F: Famicom/Classic NES Series (software emulated NES games)
    /// - K: Yoshi and Koro Koro Puzzle (acceleration sensor)
    /// - P: e-Reader (dot-code scanner) (or NDS PassMe image when gamecode="PASS")
    /// - R: Warioware Twisted (cartridge with rumble and z-axis gyro sensor)
    /// - U: Boktai 1 and 2 (cartridge with RTC and solar sensor)
    /// - V: Drill Dozer (cartridge with rumble)
    ///
    /// List of known destination/language characters and their meanings:
    /// - E: USA/American English
    /// - J: Japan
    /// - P: Europe/Elsewhere
    /// - D: German
    /// - F: French (European)
    /// - I: Italian
    /// - S: Spanish (European)
    game_code: [4]u8 align(1) = @splat(0),
    /// A maker code string contains two upper-case alphanumeric ASCII
    /// characters, usually digits.
    /// The code can identify a licensed commercial developer or publisher.
    /// This is often "00" for homebrew ROMs.
    ///
    /// Example maker codes:
    /// - 01: Nintendo
    /// - 08: Capcom
    /// - 20: EA Games
    /// - 41: Ubisoft
    /// - 51: David A. Palmer Productions
    /// - 52: Activision
    /// - 69: Electronic Arts
    /// - 5D: Midway Sports
    /// - 5Q: Lego Software
    /// - 6L: BAM! Entertainment
    /// - 78: THQ
    /// - 7S: Rockstar
    /// - A4: Konami
    /// - AF: Namco
    /// - E9: Natsume
    maker_code: [2]u8 align(1) = @splat(0),
    /// Cannot be changed.
    fixed_value: u8 align(1) = 0x96,
    /// Identifies the required hardware.
    /// Should be 0 for current GBA models.
    main_unit_code: u8 align(1) = 0x00,
    /// Should normally be zero, but can contain information for use with
    /// Nintendo's hardware debugger.
    device_type: u8 align(1) = 0x00,
    /// Reserved area.
    _1: [7]u8 align(1) = @splat(0),
    /// Version number of the game. Usually zero.
    software_version: u8 align(1) = 0x00,
    /// Header checksum.
    complement_check: u8 align(1) = 0x00,
    /// Reserved area.
    _2: [2]u8 align(1) = @splat(0),
    
    /// Check whether a game name string is valid.
    /// Game name strings must contain only upper-case alphanumeric ASCII
    /// characters, and must not be longer than 12 characters.
    pub fn validateGameName(
        comptime game_name: []const u8,
    ) StringValidationError!void {
        if (game_name.len > 12) {
            return .InvalidLength;
        }
        for (game_name) |char| {
            if (!(std.ascii.isUpper(char) or std.ascii.isDigit(char))) {
                return .InvalidCharacter;
            }
        }
    }
    
    /// Check whether a game code string is valid.
    /// Game code strings must contain only upper-case alphanumeric ASCII
    /// characters, and must be exactly 4 characters long.
    pub fn validateGameCode(
        comptime game_code: []const u8,
    ) StringValidationError!void {
        if (game_code.len != 4) {
            return .InvalidLength;
        }
        for (game_code) |char| {
            if (!(std.ascii.isUpper(char) or std.ascii.isDigit(char))) {
                return .InvalidCharacter;
            }
        }
    }
    
    /// Check whether a maker code string is valid.
    /// Maker code strings must contain only upper-case alphanumeric ASCII
    /// characters, and must be exactly 2 characters long.
    pub fn validateMakerCode(
        comptime maker_code: []const u8,
    ) StringValidationError!void {
        if (maker_code.len != 2) {
            return .InvalidLength;
        }
        for (maker_code) |char| {
            if (!(std.ascii.isUpper(char) or std.ascii.isDigit(char))) {
                return .InvalidCharacter;
            }
        }
    }
    
    /// Initialize a header struct with the given information.
    pub fn init(
        /// Game name string. Must contain only upper-case alphanumeric ASCII
        /// characters, and must not be more than 12 characters in length.
        comptime game_name: []const u8,
        /// Game code string. Must contain four upper-case alphanumeric ASCII
        /// characters.
        /// Typically starts with "A", ends with "E" (for USA/American English),
        /// and contains a two-letter abbreviation of the game title in the
        /// middle.
        comptime game_code: []const u8,
        /// Maker code string. Must contain two upper-case alphanumeric ASCII
        /// characters.
        /// Often "00" for homebrew ROMs.
        comptime maker_code: []const u8,
        /// Software version of the game. Usually 0.
        comptime software_version: u8,
    ) Header {
        comptime {
            var header: Header = .{};
            // Validate strings
            Header.validateGameName(game_name) catch |err| switch(err) {
                StringValidationError.InvalidLength => @compileError(
                    "Game name string is too long. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must not be more than " ++
                    "12 characters in length."
                ),
                StringValidationError.InvalidCharacter => @compileError(
                    "Game name string contains an invalid character. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must not be more than " ++
                    "12 characters in length."
                ),
            };
            Header.validateGameCode(game_code) catch |err| switch(err) {
                StringValidationError.InvalidLength => @compileError(
                    "Game code string is too long. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must be exactly " ++
                    "4 characters in length."
                ),
                StringValidationError.InvalidCharacter => @compileError(
                    "Game code string contains an invalid character. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must be exactly " ++
                    "4 characters in length."
                ),
            };
            Header.validateMakerCode(maker_code) catch |err| switch(err) {
                StringValidationError.InvalidLength => @compileError(
                    "Maker code string is too long. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must be exactly " ++
                    "2 characters in length."
                ),
                StringValidationError.InvalidCharacter => @compileError(
                    "Maker code string contains an invalid character. " ++
                    "The game name must contain only upper-case " ++
                    "alphanumeric ASCII characters, and must be exactly " ++
                    "2 characters in length."
                ),
            };
            // Initialize data
            @memcpy(header.game_name[0..game_name.len], game_name);
            @memcpy(header.game_code[0..game_code.len], game_code);
            @memcpy(header.maker_code[0..maker_code.len], maker_code);
            header.software_version = software_version;
            // Compute checksum
            var complement_check: u8 = 0;
            for (std.mem.asBytes(&header)[0xA0..0xBD]) |byte| {
                complement_check +%= byte;
            }
            const temp_check = -(0x19 + @as(i32, @intCast(complement_check)));
            header.complement_check = @bitCast(@as(i8, @truncate(temp_check)));
            // All done
            return header;
        }
    }
};
