const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("INTERRUPTS", "AINE", "00", 0);

// If `frame_counter` starts at 0, then all interrupts flash white at the start.
var frame_counter: u32 = 0x100;
var interrupt_last_frame: [14]u32 = @splat(0);

const interrupt_names: [14][]const u8 = .{
    "VBLANK",
    "HBLANK",
    "VCOUNT",
    "TIMER0",
    "TIMER1",
    "TIMER2",
    "TIMER3",
    "SERIAL",
    "DMA0",
    "DMA1",
    "DMA2",
    "DMA3",
    "KEYPAD",
    "GAMEPAK",
};

fn drawInterruptNames() void {
    for(0..14) |i| {
        const frame_delta = frame_counter -% interrupt_last_frame[i];
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
            .color = if(frame_delta <= 3) 1 else 2,
            .x = 8,
            .y = @intCast(4 + (8 * i)),
            .text = interrupt_names[i],
        });
    }
}

fn handleInterrupt(flags: gba.interrupt.InterruptFlags) callconv(.c) void {
    if(flags.vblank) interrupt_last_frame[0x0] = frame_counter;
    if(flags.hblank) interrupt_last_frame[0x1] = frame_counter;
    if(flags.vcount) interrupt_last_frame[0x2] = frame_counter;
    if(flags.timer_0) interrupt_last_frame[0x3] = frame_counter;
    if(flags.timer_1) interrupt_last_frame[0x4] = frame_counter;
    if(flags.timer_2) interrupt_last_frame[0x5] = frame_counter;
    if(flags.timer_3) interrupt_last_frame[0x6] = frame_counter;
    if(flags.serial) interrupt_last_frame[0x7] = frame_counter;
    if(flags.dma_0) interrupt_last_frame[0x8] = frame_counter;
    if(flags.dma_1) interrupt_last_frame[0x9] = frame_counter;
    if(flags.dma_2) interrupt_last_frame[0xa] = frame_counter;
    if(flags.dma_3) interrupt_last_frame[0xb] = frame_counter;
    if(flags.keypad) interrupt_last_frame[0xc] = frame_counter;
    if(flags.gamepak) interrupt_last_frame[0xd] = frame_counter;
}

pub export fn main() void {
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .black;
    gba.display.bg_palette.banks[0][1] = .white;
    gba.display.bg_palette.banks[0][2] = .rgb(20, 20, 22);
    
    // Initialize a background, to be used for displaying text.
    gba.bg.ctrl[0] = .{
        .screen_base_block = 31,
        .tile_map_size = .{ .normal = .size_32x32 },
    };
    const normal_bg_map = gba.display.BackgroundMap.initCtrl(gba.bg.ctrl[0]);
    normal_bg_map.getBaseScreenblock().fillLinear(.{});
    
    // Draw initial text.
    drawInterruptNames();
    
    // Initialize the display.
    gba.display.ctrl.* = gba.display.Control{
        .bg0 = true,
    };
    
    // Enable all interrupts.
    gba.interrupt.master.enable = true;
    // VBlank, HBlank, and VCount
    gba.interrupt.enable.vblank = true;
    gba.interrupt.enable.hblank = true;
    gba.interrupt.enable.vcount = true;
    gba.display.status.* = gba.display.Status{
        .vblank_interrupt = true,
        .hblank_interrupt = true,
        .vcount_interrupt = true,
    };
    // Timers
    gba.interrupt.enable.timer_0 = true;
    gba.timers[0].ctrl = gba.Timer.Control{
        .enable = true,
        .interrupt = true,
        .freq = .cycles_64,
    };
    gba.interrupt.enable.timer_1 = true;
    gba.timers[1].ctrl = gba.Timer.Control{
        .enable = true,
        .interrupt = true,
        .mode = .cascade,
    };
    gba.interrupt.enable.timer_2 = true;
    gba.timers[2].ctrl = gba.Timer.Control{
        .enable = true,
        .interrupt = true,
        .freq = .cycles_256,
    };
    gba.interrupt.enable.timer_3 = true;
    gba.timers[3].ctrl = gba.Timer.Control{
        .enable = true,
        .interrupt = true,
        .freq = .cycles_1024,
    };
    // Serial
    gba.interrupt.enable.serial = true;
    // DMA
    gba.interrupt.enable.dma_0 = true;
    gba.mem.dma[0].ctrl.interrupt = true;
    gba.interrupt.enable.dma_1 = true;
    gba.mem.dma[1].ctrl.interrupt = true;
    gba.interrupt.enable.dma_2 = true;
    gba.mem.dma[2].ctrl.interrupt = true;
    gba.interrupt.enable.dma_3 = true;
    gba.mem.dma[3].ctrl.interrupt = true;
    // Keypad
    gba.interrupt.enable.keypad = true;
    gba.input.interrupt.* = gba.input.InterruptControl{
        .button_a = .select,
        .button_b = .select,
        .button_select = .select,
        .button_start = .select,
        .button_right = .select,
        .button_left = .select,
        .button_up = .select,
        .button_down = .select,
        .button_r = .select,
        .button_l = .select,
        .interrupt = true,
        .condition = .any,
    };
    // Game pak
    gba.interrupt.enable.gamepak = true;
    
    // Set up interrupt handler.
    gba.interrupt.isr_default_redirect = handleInterrupt;
    
    // Main loop.
    while(true) : (frame_counter +%= 1) {
        gba.bios.vblankIntrWait();
        drawInterruptNames();
    }
}
