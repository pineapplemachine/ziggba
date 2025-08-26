const gba = @import("gba.zig");

const build_options = @import("ziggba_build_options");

// Imports related to "agbprint"/"gbaprint" logging.
pub const reg_agb_print_protect = @import("debug_agb.zig").reg_agb_print_protect;
pub const reg_agb_print_context = @import("debug_agb.zig").reg_agb_print_context;
pub const reg_agb_print_buffer = @import("debug_agb.zig").reg_agb_print_buffer;
pub const agb_buffer_size = @import("debug_agb.zig").agb_buffer_size;
pub const AgbPrintContext = @import("debug_agb.zig").AgbPrintContext;
pub const agbInit = @import("debug_agb.zig").agbInit;
pub const agbPrint = @import("debug_agb.zig").agbPrint;
pub const agbWrite = @import("debug_agb.zig").agbWrite;

// Imports related to mGBA logging.
pub const MgbaLogLevel = @import("debug_mgba.zig").MgbaLogLevel;
pub const reg_mgba_log_str_size = @import("debug_mgba.zig").reg_mgba_log_str_size;
pub const reg_mgba_log_enabled = @import("debug_mgba.zig").reg_mgba_log_enabled;
pub const reg_mgba_log_str = @import("debug_mgba.zig").reg_mgba_log_str;
pub const reg_mgba_log_level = @import("debug_mgba.zig").reg_mgba_log_level;
pub const reg_mgba_log_enable = @import("debug_mgba.zig").reg_mgba_log_enable;
pub const mgbaPrint = @import("debug_mgba.zig").mgbaPrint;
pub const mgbaWrite = @import("debug_mgba.zig").mgbaWrite;
pub const mgbaPrintInfo = @import("debug_mgba.zig").mgbaPrintInfo;
pub const mgbaWriteInfo = @import("debug_mgba.zig").mgbaWriteInfo;
pub const mgbaPrintWarning = @import("debug_mgba.zig").mgbaPrintWarning;
pub const mgbaWriteWarning = @import("debug_mgba.zig").mgbaWriteWarning;
pub const mgbaPrintError = @import("debug_mgba.zig").mgbaPrintError;
pub const mgbaWriteError = @import("debug_mgba.zig").mgbaWriteError;
pub const mgbaPrintFatal = @import("debug_mgba.zig").mgbaPrintFatal;
pub const mgbaWriteFatal = @import("debug_mgba.zig").mgbaWriteFatal;

// Panic-related imports.
pub const std_panic = @import("debug_panic.zig").std_panic;
pub const stdPanicHandler = @import("debug_panic.zig").stdPanicHandler;
pub const panic = @import("debug_panic.zig").panic;

/// Enumeration of supported logger interfaces.
pub const LoggerInterface = enum {
    /// No default logger.
    /// Corresponds to `stubInit`, `stubPrint`, and `stubWrite`.
    none,
    /// Represents the "agbprint"/"gbaprint" logging interface.
    /// Corresponds to `agbInit`, `agbPrint`, and `agbWrite`.
    agb,
    /// Represents the mGBA logging interface.
    /// Corresponds to `stubInit`, `mgbaPrintInfo`, and `mgbaWriteInfo`.
    mgba,
};

/// Stub function for `gba.debug.init`. Does nothing.
fn stubInit() void {}

/// Stub function for `gba.debug.print`. Does nothing.
fn stubPrint(comptime _: []const u8, _: anytype) void {}

/// Stub function for `gba.debug.write`. Does nothing.
fn stubWrite(_: []const u8) void {}

/// Initialize the default logger, as configured
/// via ZigGBA's build options.
/// This may or may not be strictly necessary, depending on the emulator
/// and the chosen logger.
pub const init = switch(build_options.default_logger) {
    .none => stubInit,
    .agb => agbInit,
    .mgba => stubInit,
};

/// Log a formatted message using the default logger, as configured
/// via ZigGBA's build options.
pub const print = switch(build_options.default_logger) {
    .none => stubPrint,
    .agb => agbPrint,
    .mgba => mgbaPrintInfo,
};

/// Log a message string using the default logger, as configured
/// via ZigGBA's build options.
pub const write = switch(build_options.default_logger) {
    .none => stubWrite,
    .agb => agbWrite,
    .mgba => mgbaWriteInfo,
};
