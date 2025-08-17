const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("MEMORY", "AMEE", "00", 0);

const test_buffers_len = 0x1000;

/// An empty buffer to be used for memory operations.
var test_buffer_dst: [test_buffers_len]u8 align(4) = @splat(0);

/// A buffer initialized with pseudorandom bytes.
var test_buffer_src: [test_buffers_len]u8 align(4) = blk: {
    @setEvalBranchQuota(100000);
    var buffer: [test_buffers_len]u8 = undefined;
    var x: u8 = 0x80;
    for(0..buffer.len) |i| {
        buffer[i] = if(x == 0) 1 else x;
        x ^= (x << 2);
        x ^= (x >> 5);
    }
    break :blk buffer;
};

/// Will hold CPU cycle counts for each memory copy or fill operation.
var performance_test_times: [16]i32 = @splat(0);

/// Will hold correctness test results for memcpy.
var cpy_correctness_test_results: [64]bool = @splat(false);

/// Will hold correctness test results for memset.
var set_correctness_test_results: [16]bool = @splat(false);

/// List of strings corresponding to the memory copy and fill functions
/// pertaining to each performance test in `doMemTests`.
const performance_test_names: [16][]const u8 = .{
    "memcpy",
    "memcpy16",
    "memcpy32",
    "cpuSetCopy16",
    "cpuSetCopy32",
    "cpuFastSetCopy",
    "memcpyDma16",
    "memcpyDma32",
    "memset",
    "memset16",
    "memset32",
    "cpuSetFill16",
    "cpuSetFill32",
    "cpuFastSetFill",
    "memsetDma16",
    "memsetDma32",
};

fn drawMemResults() void {
    gba.text.drawToCharblock4Bpp(.{
        .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
        .color = 1,
        .x = 4,
        .y = 2,
        .text = "Performance:",
    });
    for(0..performance_test_names.len) |i| {
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
            .color = 1,
            .x = 4,
            .y = @intCast(12 + (i << 3)),
            .text = performance_test_names[i],
        });
        var text_buffer: [16]u8 = @splat(0);
        const text_len = gba.format.formatHexI32(
            &text_buffer,
            performance_test_times[i],
            .{ .pad_zero_len = 4 },
        );
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
            .color = 1,
            .x = 80,
            .y = @intCast(12 + (i << 3)),
            .text = text_buffer[0..text_len],
        });
    }
    gba.text.drawToCharblock4Bpp(.{
        .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
        .color = 1,
        .x = 124,
        .y = 2,
        .text = "Correctness:",
    });
    for(0..cpy_correctness_test_results.len) |i| {
        const ok = cpy_correctness_test_results[i];
        const status_text_buffer: [3]u8 = .{
            'C',
            gba.format.hex_digits_ascii[(i >> 4) & 0xf],
            gba.format.hex_digits_ascii[i & 0xf],
        };
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
            .color = if(ok) 1 else 2,
            .x = @intCast(124 + ((i >> 4) * 20)),
            .y = @intCast(12 + ((i & 0xf) << 3)),
            .text = &status_text_buffer,
        });
    }
    for(0..set_correctness_test_results.len) |i| {
        const ok = set_correctness_test_results[i];
        const status_text_buffer: [3]u8 = .{
            'S',
            gba.format.hex_digits_ascii[(i >> 4) & 0xf],
            gba.format.hex_digits_ascii[i & 0xf],
        };
        gba.text.drawToCharblock4Bpp(.{
            .target = @ptrCast(&gba.display.bg_charblock_tiles.bpp_4),
            .color = if(ok) 1 else 2,
            .x = @intCast(204 + ((i >> 4) * 20)),
            .y = @intCast(12 + ((i & 0xf) << 3)),
            .text = &status_text_buffer,
        });
    }
}

fn doMemTests() void {
    // Run performance tests.
    for(0..16) |i| {
        const t_start: i32 = (
            gba.timers[0].counter |
            (@as(i32, gba.timers[1].counter) << 16)
        );
        switch(i) {
            0 => {
                gba.mem.memcpy(
                    &test_buffer_dst,
                    &test_buffer_src,
                    test_buffer_src.len,
                );
            },
            1 => {
                gba.mem.memcpy16(
                    &test_buffer_dst,
                    &test_buffer_src,
                    test_buffer_src.len >> 1,
                );
            },
            2 => {
                gba.mem.memcpy32(
                    &test_buffer_dst,
                    &test_buffer_src,
                    test_buffer_src.len >> 2,
                );
            },
            3 => {
                gba.bios.cpuSetCopy16(
                    &test_buffer_src,
                    &test_buffer_dst,
                    test_buffer_src.len >> 1,
                );
            },
            4 => {
                gba.bios.cpuSetCopy32(
                    &test_buffer_src,
                    &test_buffer_dst,
                    test_buffer_src.len >> 2,
                );
            },
            5 => {
                gba.bios.cpuFastSetCopy(
                    &test_buffer_src,
                    &test_buffer_dst,
                    test_buffer_src.len >> 2,
                );
            },
            6 => {
                gba.mem.memcpyDma16(
                    3,
                    &test_buffer_dst,
                    &test_buffer_src,
                    test_buffer_src.len >> 1,
                );
            },
            7 => {
                gba.mem.memcpyDma32(
                    3,
                    &test_buffer_dst,
                    &test_buffer_src,
                    test_buffer_src.len >> 2,
                );
            },
            8 => {
                gba.mem.memset(
                    &test_buffer_dst,
                    0x01,
                    test_buffer_dst.len,
                );
            },
            9 => {
                gba.mem.memset16(
                    &test_buffer_dst,
                    0x0123,
                    test_buffer_dst.len >> 1,
                );
            },
            10 => {
                gba.mem.memset32(
                    &test_buffer_dst,
                    0x01234567,
                    test_buffer_dst.len >> 2,
                );
            },
            11 => {
                const fill_value: u16 = 0x0123;
                gba.bios.cpuSetFill16(
                    &fill_value,
                    &test_buffer_dst,
                    test_buffer_src.len >> 1,
                );
            },
            12 => {
                const fill_value: u32 = 0x01234567;
                gba.bios.cpuSetFill32(
                    &fill_value,
                    &test_buffer_dst,
                    test_buffer_dst.len >> 2,
                );
            },
            13 => {
                const fill_value: u32 = 0x01234567;
                gba.bios.cpuFastSetFill(
                    &fill_value,
                    &test_buffer_dst,
                    test_buffer_dst.len >> 2,
                );
            },
            14 => {
                const fill_value: u16 = 0x0123;
                gba.mem.memsetDma16(
                    3,
                    &test_buffer_dst,
                    &fill_value,
                    test_buffer_dst.len >> 1,
                );
            },
            15 => {
                const fill_value: u32 = 0x01234567;
                gba.mem.memsetDma32(
                    3,
                    &test_buffer_dst,
                    &fill_value,
                    test_buffer_dst.len >> 2,
                );
            },
            else => {},
        }
        const t_end: i32 = (
            gba.timers[0].counter |
            (@as(i32, gba.timers[1].counter) << 16)
        );
        performance_test_times[i] = t_end -% t_start;
    }
    // Run correctness tests for `memcpy`.
    // Note that the `memcpy` function also calls `memcpy16` and `memcpy32`
    // meaning it is not necessary to have separate coverage for each.
    for(0..64) |test_i| {
        const src_start_offset: u32 = @intCast(test_i & 0x3);
        const src_end_offset: u32 = @intCast((test_i >> 2) & 0x3);
        const dst_start_offset: u32 = @intCast((test_i >> 4) & 0x3);
        const len = 0x80 - src_end_offset;
        test_buffer_dst[dst_start_offset + len] = 0x00;
        gba.mem.memcpy(
            &test_buffer_dst[dst_start_offset],
            &test_buffer_src[src_start_offset],
            len,
        );
        cpy_correctness_test_results[test_i] = (
            test_buffer_dst[dst_start_offset + len] == 0x00
        );
        for(0..len) |byte_i| {
            const src = test_buffer_src[byte_i + src_start_offset];
            const dst = test_buffer_dst[byte_i + dst_start_offset];
            if(src != dst) {
                cpy_correctness_test_results[test_i] = false;
                break;
            }
        }
    }
    // Run correctness tests for `memset`.
    // Note that the `memset` function also calls `memset16` and `memset32`
    // meaning it is not necessary to have separate coverage for each.
    for(0..16) |test_i| {
        const fill: u8 = 0x1e;
        const dst_start_offset: u32 = @intCast(test_i & 0x3);
        const dst_end_offset: u32 = @intCast((test_i >> 2) & 0x3);
        const len = 0x80 - dst_end_offset;
        test_buffer_dst[dst_start_offset + len] = 0x00;
        gba.mem.memset(
            &test_buffer_dst[dst_start_offset],
            fill,
            len,
        );
        set_correctness_test_results[test_i] = (
            test_buffer_dst[dst_start_offset + len] == 0x00
        );
        for(0..len) |byte_i| {
            const dst = test_buffer_dst[byte_i + dst_start_offset];
            if(dst != fill) {
                set_correctness_test_results[test_i] = false;
                break;
            }
        }
    }
}

pub export fn main() void {
    // Initialize timers.
    // These will be used to measure elapsed cycles for performance.
    gba.timers[0] = gba.Timer{
        .counter = 0,
        .ctrl = .{
            .freq = .cycles_1,
            .enable = true,
        },
    };
    gba.timers[1] = gba.Timer{
        .counter = 0,
        .ctrl = .{
            .mode = .cascade,
            .enable = true,
        },
    };
    
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = gba.Color.black;
    gba.display.bg_palette.banks[0][1] = gba.Color.white;
    gba.display.bg_palette.banks[0][2] = gba.Color.red;
    
    // Initialize a background, to be used for displaying text.
    gba.bg.ctrl[0] = .{
        .screen_base_block = 31,
        .tile_map_size = .{ .normal = .size_32x32 },
    };
    const normal_bg_map = gba.display.BackgroundMap.initCtrl(gba.bg.ctrl[0]);
    normal_bg_map.getBaseScreenblock().fillLinear(.{});
    
    // Run memory performance and correctness tests.
    doMemTests();
    // Draw performance and correctness results to the screen.
    drawMemResults();
    
    // Initialize the display.
    gba.display.ctrl.* = gba.display.Control{
        .bg0 = true,
    };
    
    // Enable VBlank interrupts.
    // This will allow running the main loop once per frame.
    gba.display.status.vblank_interrupt = true;
    gba.interrupt.enable.vblank = true;
    gba.interrupt.master.enable = true;
    
    // Main loop.
    while(true) {
        gba.bios.vblankIntrWait();
    }
}
