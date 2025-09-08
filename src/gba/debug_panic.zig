const std = @import("std");
const gba = @import("gba.zig");

/// Include this line in a ROM source to override the `@panic` handler with
/// `gba.debug.stdPanicHandler`, which itself wraps a call to `gba.debug.panic`:
/// `pub const panic = gba.debug.std_panic;`
pub const std_panic = std.debug.FullPanic(stdPanicHandler);

/// Wraps `gba.debug.panic` with an interface compatible with
/// `std.debug.FullPanic`, allowing it to be used as a `@panic` handler.
pub fn stdPanicHandler(message: []const u8, first_trace_addr: ?usize) noreturn {
    gba.interrupt.master.enable = false; // Prevent interrupts.
    gba.sound.status.* = .init(false); // Mute sounds.
    if(first_trace_addr) |addr| {
        var addr_buffer: [8]u8 = @splat(0);
        const addr_len = gba.format.formatHexU32(
            &addr_buffer,
            @truncate(addr),
            .{ .pad_zero_len = 8 },
        );
        panic(addr_buffer[0..addr_len], message);
    }
    else {
        gba.debug.panic(null, message);
    }
}

/// Display an error message and halt the program.
/// Writes a message like `PANIC @ <location>\n\n<message>`.
/// This is appropriate for reporting unrecoverable errors.
pub fn panic(location: ?[]const u8, message: []const u8) noreturn {
    // Prevent interrupts.
    gba.interrupt.master.enable = false;
    // Mute sounds.
    gba.sound.status.* = .init(false);
    // Display message text.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .white;
    gba.display.bg_palette.banks[0][2] = .yellow;
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 31,
        .size = .size_32x32,
    });
    bg0_map.getBaseScreenblock().fillLinear(.{});
    gba.display.Tile4Bpp.fillLine(
        gba.display.bg_blocks.tiles_4bpp[0..640],
        0,
    );
    const text_surface = gba.display.bg_blocks.getSurface4Bpp(0, 32, 32);
    const text_header = if(location) |_| "PANIC @" else "PANIC";
    text_surface.draw().text(text_header, .{
        .pixel = 2,
        .x = 8,
        .y = 4,
    });
    if(location) |loc| {
        text_surface.draw().text(loc, .{
            .pixel = 2,
            .x = 50,
            .y = 4,
        });
    }
    text_surface.draw().text(message, .{
        .pixel = 1,
        .x = 8,
        .y = 20,
        .max_width = 224,
        .max_height = 140,
        .wrap = .simple, // TODO: Smarter word wrap
    });
    // Try to also print the error to a debugger.
    gba.debug.init();
    gba.debug.write("PANIC");
    gba.debug.write(if(location) |loc| loc else "No location info");
    gba.debug.write(message);
    // Hang forever.
    gba.bios.halt(); // Hang here in a low-power state.
    @trap(); // Satisfy Zig's `noreturn`, and catch poorly-behaved emulators.
}
