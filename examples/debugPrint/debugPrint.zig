const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("DEBUGPRINT", "ADPE", "00", 0);

pub export fn main() void {
    gba.display.ctrl.* = .initMode3(.{});
    gba.debug.init();
    gba.debug.write("HELLO DEBUGGER!");
    gba.debug.write(
        "This is a much longer message! " ++
        "Messages longer than 256 bytes may be split into multiple entires. " ++
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, " ++
        "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " ++
        "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris " ++
        "nisi ut aliquip ex ea commodo consequat. " ++
        "Duis aute irure dolor in reprehenderit in voluptate velit esse " ++
        "cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat " ++
        "cupidatat non proident, sunt in culpa qui officia deserunt mollit " ++
        "anim id est laborum."
    );
    // Formatted text.
    const name = "DebugPrint";
    for (0..20) |i| {
        gba.debug.print("From {s}: {d}", .{ name, i }) catch {};
    }
}
