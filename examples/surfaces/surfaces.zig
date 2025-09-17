const gba = @import("gba");

export var header linksection(".gbaheader") = gba.Header.init("SURFACES", "ASFE", "00", 0);

fn drawToSurface(
    comptime SurfaceT: type,
    comptime PixelT: type,
    surface: SurfaceT,
    pixel_background: PixelT,
    pixel_foreground: PixelT,
    text: []const u8,
) void {
    // Draw some text identifying the surface type, centered in the screen
    // and with a rectangular outline around it.
    var bounds_layout: gba.text.TextLayout = .init(text, .{ .x = 0, .y = 0 });
    bounds_layout.exhaust();
    const bounds_layout_rect = bounds_layout.getBoundsRect();
    const bounds_layout_off = bounds_layout.getBoundsOffset();
    const draw_pos_x: u32 = (
        ((surface.getWidth() - bounds_layout_rect.width) >> 1) -
        bounds_layout_off.x
    );
    const draw_pos_y: u32 = (
        ((surface.getHeight() - bounds_layout_rect.height) >> 1) -
        bounds_layout_off.y
    );
    surface.draw().fill(pixel_background);
    const bounds_drawn = surface.draw().textGetBounds(
        text,
        .init(pixel_foreground),
        .{ .x = draw_pos_x, .y = draw_pos_y },
    );
    surface.draw().rectOutline(
        bounds_drawn.x - 2,
        bounds_drawn.y - 2,
        bounds_drawn.width + 4,
        bounds_drawn.height + 4,
        pixel_foreground,
    );
}

fn drawMode0Bpp4() void {
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 31,
        .size = .size_32x32,
        .bpp = .bpp_4,
    });
    bg0_map.getBaseScreenblock().fillLinear(.{});
    const text = "gba.display.bg_blocks.getSurface4Bpp";
    const surface = gba.display.bg_blocks.getSurface4Bpp(0, 32, 32).sub(0, 0, 30, 20);
    const SurfaceT = @TypeOf(surface);
    drawToSurface(SurfaceT, SurfaceT.Pixel, surface, 0, 1, text);
}

fn drawMode0Bpp8() void {
    gba.display.ctrl.* = .initMode0(.{ .bg0 = true });
    const bg0_map = gba.display.BackgroundMap.setup(0, .{
        .base_screenblock = 31,
        .size = .size_32x32,
        .bpp = .bpp_8,
    });
    bg0_map.getBaseScreenblock().fillLinear(.{});
    const text = "gba.display.bg_blocks.getSurface8Bpp";
    const surface = gba.display.bg_blocks.getSurface8Bpp(0, 32, 32).sub(0, 0, 30, 20);
    const SurfaceT = @TypeOf(surface);
    drawToSurface(SurfaceT, SurfaceT.Pixel, surface, 0, 1, text);
}

fn drawMode3() void {
    gba.display.ctrl.* = .initMode3(.{});
    gba.display.bg_2_affine.* = .identity;
    const text = "gba.display.getMode3Surface";
    const surface = gba.display.getMode3Surface();
    const SurfaceT = @TypeOf(surface);
    drawToSurface(SurfaceT, SurfaceT.Pixel, surface, .black, .white, text);
}

fn drawMode4() void {
    gba.display.ctrl.* = .initMode4(.{});
    gba.display.bg_2_affine.* = .identity;
    const text = "gba.display.getMode4Surface";
    const surface = gba.display.getMode4Surface(0);
    const SurfaceT = @TypeOf(surface);
    drawToSurface(SurfaceT, SurfaceT.Pixel, surface, 0, 1, text);
}

fn drawMode5() void {
    gba.display.ctrl.* = .initMode5(.{});
    gba.bios.bgAffineSetDisplay2(.{
        .original = .init(
            .fromInt(gba.display.mode5_width >> 1),
            .fromInt(gba.display.mode5_height >> 1),
        ),
        .display = .init(
            gba.display.screen_width >> 1,
            gba.display.screen_height >> 1,
        ),
    });
    const text = "gba.display.getMode5Surface";
    const surface = gba.display.getMode5Surface(0);
    const SurfaceT = @TypeOf(surface);
    drawToSurface(SurfaceT, SurfaceT.Pixel, surface, .black, .white, text);
}

fn draw(mode: u8) void {
    switch(mode) {
        0 => drawMode0Bpp4(),
        1 => drawMode0Bpp8(),
        2 => drawMode3(),
        3 => drawMode4(),
        4 => drawMode5(),
        else => {}
    }
}

pub export fn main() void {
    // Initialize a color palette.
    gba.display.bg_palette.banks[0][0] = .rgb(10, 10, 12);
    gba.display.bg_palette.banks[0][1] = .white;
    
    // Initialize a variable for tracking input state.
    var input: gba.input.BufferedKeysState = .{};
    
    // Initialize variable for switching draw mode, and draw an initial screen.
    var mode: u8 = 0;
    draw(mode);
    
    // Main loop.
    while (true) {
        // Run this loop only once per frame.
        gba.display.naiveVSync();
        
        // Check the state of button inputs for this frame.
        input.poll();
        
        // Cycle through graphics modes with the left and right buttons.
        if(input.isJustPressed(.left)) {
            mode = if(mode == 0) 4 else mode - 1;
            draw(mode);
        }
        else if(input.isJustPressed(.right)) {
            mode = if(mode == 4) 0 else mode + 1;
            draw(mode);
        }
    }
}
