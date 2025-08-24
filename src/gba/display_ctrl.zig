const gba = @import("gba.zig");

/// Controls the capabilities of background layers.
/// Modes 0, 1, and 2 are tile modes.
/// Modes 3, 4, and 5 are bitmap modes.
pub const Mode = enum(u3) {
    /// Enumeration of possible background types in each graphics mode.
    pub const BackgroundType = enum(i2) {
        /// Indicates that a background is not available at all in a given mode.
        unavailable = -1,
        /// Indicates that a background is normal (non-affine) in a given mode.
        normal = 0,
        /// Indicates that a background uses affine display in a given mode.
        affine = 1,
        /// Indicates that a background is not used normally, but must be
        /// enabled in order for bitmap graphics to display, i.e. in
        /// modes 3, 4, and 5.
        bitmap = 2,
    };
    
    /// Type for each background in each graphics mode.
    pub const BackgroundTypes: [6][4]BackgroundType = .{
        @splat(.normal),
        .{ .normal, .normal, .affine, .unavailable },
        .{ .unavailable, .unavailable, .affine, .affine },
        .{ .unavailable, .unavailable, .bitmap, .unavailable },
        .{ .unavailable, .unavailable, .bitmap, .unavailable },
        .{ .unavailable, .unavailable, .bitmap, .unavailable },
    };
    
    /// Tiled mode.
    /// Provides four normal background layers (0, 1, 2, 3)
    /// and no affine layers.
    mode_0 = 0,
    /// Tiled mode.
    /// Provides two normal (0, 1) and one affine background layer (2).
    mode_1 = 1,
    /// Tiled mode.
    /// Provides two affine background layers (2, 3)
    /// and no normal non-affine layers.
    mode_2 = 2,
    /// Bitmap mode.
    /// Provides one full-screen 16bpp bitmap frame.
    mode_3 = 3,
    /// Bitmap mode.
    /// Provides two 8bpp (256 color) frames.
    mode_4 = 4,
    /// Bitmap mode.
    /// Provides two 160x128 pixel 16bpp frames.
    mode_5 = 5,
    
    /// Get the type of a given background in a certain display mode.
    pub fn getBackgroundType(self: Mode, bg_index: u2) BackgroundType {
        return switch(self) {
            .mode_0 => .normal,
            .mode_1 => switch(bg_index) {
                0, 1 => .normal,
                2 => .affine,
                else => .unavailable,
            },
            .mode_2 => switch(bg_index) {
                2, 3 => .affine,
                else => .unavailable,
            },
            else => switch(bg_index) {
                2 => .bitmap,
                else => .unavailable,
            },
        };
    }
    
    /// Get the types of all four backgrounds in a certain display mode.
    pub fn getBackgroundTypeArray(self: Mode) [4]BackgroundType {
        return BackgroundTypes[@intFromEnum(self)];
    }
};

/// Represents the structure of the display control register REG_DISPCNT.
pub const Control = packed struct(u16) {
    /// Object mapping relates to how `gba.display.Object.base_tile` determines the
    /// appearance of an object/sprite.
    pub const ObjMapping = enum(u1) {
        /// Object charblock data is interpreted as a series of 32-tile rows
        /// making up a 256 pixel wide bitmap.
        map_2d = 0,
        /// Object charblock data is represented sequentially.
        map_1d = 1,
    };
    
    /// Graphics mode. See `gba.display.Mode`.
    mode: Mode = .mode_0,
    /// Read-only. Should always be false.
    gbc_mode: bool = false,
    /// Indicates which page or frame to display in modes 4 and 5.
    page_select: u1 = 0,
    /// When true, the system allows access to OAM during HBlank.
    /// This feature reduces the number of sprites that can be displayed
    /// per line.
    hblank_oam: bool = false,
    /// Indicates how object/sprite tiles are laid out in VRAM.
    /// See `gba.display.Object.base_tile`.
    obj_mapping: ObjMapping = .map_2d,
    /// Forces the system to behave as though it was in a VBlank/HBlank.
    /// The system's video controller displays only white lines, but
    /// allows fast access to VRAM, OAM, and palette memory.
    force_blank: bool = false,
    /// Enable background 0. Only relevant to graphics modes 0 and 1.
    bg0: bool = false,
    /// Enable background 1. Only relevant to graphics modes 0 and 1.
    bg1: bool = false,
    /// Enable background 2. Primarily relevant to graphics modes 0, 1, and 2,
    /// for enabling as a normal or affine background, but this flag must also
    /// be set in order for anything to be visible in modes 3, 4, and 5.
    bg2: bool = false,
    /// Enable background 3. Only relevant to graphics modes 0 and 2.
    bg3: bool = false,
    /// Enable objects/sprites.
    obj: bool = false,
    /// Enable window 0. See `gba.display.window`.
    window_0: bool = false,
    /// Enable window 1. See `gba.display.window`.
    window_1: bool = false,
    /// Enable the object window.
    /// See `gba.display.window` and `gba.display.Object.effect`.
    window_obj: bool = false,
    
    /// Options related specifically to graphics mode 0.
    /// See `gba.display.Mode.mode_0`.
    pub const InitMode0Options = struct {
        /// Allows access to OAM during HBlank.
        hblank_oam: bool = false,
        /// Indicates how object/sprite tiles are laid out in VRAM.
        obj_mapping: ObjMapping = .map_2d,
        /// Forces the system to behave as though it was in a VBlank/HBlank.
        force_blank: bool = false,
        /// Enable background 0, displayed as normal (non-affine).
        bg0: bool = false,
        /// Enable background 1, displayed as normal (non-affine).
        bg1: bool = false,
        /// Enable background 2, displayed as normal (non-affine).
        bg2: bool = false,
        /// Enable background 3, displayed as normal (non-affine).
        bg3: bool = false,
        /// Enable objects/sprites.
        obj: bool = false,
        /// Enable window 0.
        window_0: bool = false,
        /// Enable window 1.
        window_1: bool = false,
        /// Enable the object window.
        window_obj: bool = false,
    };
    
    /// Options related specifically to graphics mode 1.
    /// See `gba.display.Mode.mode_1`.
    pub const InitMode1Options = struct {
        /// Allows access to OAM during HBlank.
        hblank_oam: bool = false,
        /// Indicates how object/sprite tiles are laid out in VRAM.
        obj_mapping: ObjMapping = .map_2d,
        /// Forces the system to behave as though it was in a VBlank/HBlank.
        force_blank: bool = false,
        /// Enable background 0, displayed as normal (non-affine).
        bg0: bool = false,
        /// Enable background 1, displayed as normal (non-affine).
        bg1: bool = false,
        /// Enable background 2, displayed as affine.
        bg2: bool = false,
        /// Enable objects/sprites.
        obj: bool = false,
        /// Enable window 0.
        window_0: bool = false,
        /// Enable window 1.
        window_1: bool = false,
        /// Enable the object window.
        window_obj: bool = false,
    };
    
    /// Options related specifically to graphics mode 2.
    /// See `gba.display.Mode.mode_2`.
    pub const InitMode2Options = struct {
        /// Allows access to OAM during HBlank.
        hblank_oam: bool = false,
        /// Indicates how object/sprite tiles are laid out in VRAM.
        obj_mapping: ObjMapping = .map_2d,
        /// Forces the system to behave as though it was in a VBlank/HBlank.
        force_blank: bool = false,
        /// Enable background 2, displayed as affine.
        bg2: bool = false,
        /// Enable background 3, displayed as affine.
        bg3: bool = false,
        /// Enable objects/sprites.
        obj: bool = false,
        /// Enable window 0.
        window_0: bool = false,
        /// Enable window 1.
        window_1: bool = false,
        /// Enable the object window.
        window_obj: bool = false,
    };
    
    /// Options related specifically to graphics mode 3.
    /// See `gba.display.Mode.mode_3`.
    pub const InitMode3Options = struct {
        /// Allows access to OAM during HBlank.
        hblank_oam: bool = false,
        /// Indicates how object/sprite tiles are laid out in VRAM.
        obj_mapping: ObjMapping = .map_2d,
        /// Forces the system to behave as though it was in a VBlank/HBlank.
        force_blank: bool = false,
        /// Enable objects/sprites.
        obj: bool = false,
        /// Enable window 0.
        window_0: bool = false,
        /// Enable window 1.
        window_1: bool = false,
        /// Enable the object window.
        window_obj: bool = false,
    };
    
    /// Options related specifically to graphics mode 4.
    /// See `gba.display.Mode.mode_4`.
    pub const InitMode4Options = struct {
        /// Indicates which page or frame to display.
        page_select: u1 = 0,
        /// Allows access to OAM during HBlank.
        hblank_oam: bool = false,
        /// Indicates how object/sprite tiles are laid out in VRAM.
        obj_mapping: ObjMapping = .map_2d,
        /// Forces the system to behave as though it was in a VBlank/HBlank.
        force_blank: bool = false,
        /// Enable objects/sprites.
        obj: bool = false,
        /// Enable window 0.
        window_0: bool = false,
        /// Enable window 1.
        window_1: bool = false,
        /// Enable the object window.
        window_obj: bool = false,
    };
    
    /// Options related specifically to graphics mode 5.
    /// See `gba.display.Mode.mode_5`.
    /// Mode 5 related options are the same as mode 4.
    pub const InitMode5Options = InitMode4Options;
    
    /// Initialize with options related specifically to graphics mode 0.
    /// See `gba.display.Mode.mode_0`.
    pub fn initMode0(options: InitMode0Options) Control {
        return .{
            .mode = .mode_0,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg0 = options.bg0,
            .bg1 = options.bg1,
            .bg2 = options.bg2,
            .bg3 = options.bg3,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
    
    /// Initialize with options related specifically to graphics mode 1.
    /// See `gba.display.Mode.mode_1`.
    pub fn initMode1(options: InitMode1Options) Control {
        return .{
            .mode = .mode_1,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg0 = options.bg0,
            .bg1 = options.bg1,
            .bg2 = options.bg2,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
    
    /// Initialize with options related specifically to graphics mode 2.
    /// See `gba.display.Mode.mode_2`.
    pub fn initMode2(options: InitMode2Options) Control {
        return .{
            .mode = .mode_2,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg2 = options.bg2,
            .bg3 = options.bg3,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
    
    /// Initialize with options related specifically to graphics mode 3.
    /// Sets the `bg2` flag to true, to enable bitmap display.
    /// See `gba.display.Mode.mode_3`.
    pub fn initMode3(options: InitMode3Options) Control {
        return .{
            .mode = .mode_3,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg2 = true,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
    
    /// Initialize with options related specifically to graphics mode 4.
    /// Sets the `bg2` flag to true, to enable bitmap display.
    /// See `gba.display.Mode.mode_4`.
    pub fn initMode4(options: InitMode4Options) Control {
        return .{
            .mode = .mode_4,
            .page_select = options.page_select,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg2 = true,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
    
    /// Initialize with options related specifically to graphics mode 5.
    /// Sets the `bg2` flag to true, to enable bitmap display.
    /// See `gba.display.Mode.mode_5`.
    pub fn initMode5(options: InitMode5Options) Control {
        return .{
            .mode = .mode_5,
            .page_select = options.page_select,
            .hblank_oam = options.hblank_oam,
            .obj_mapping = options.obj_mapping,
            .force_blank = options.force_blank,
            .bg2 = true,
            .obj = options.obj,
            .window_0 = options.window_0,
            .window_1 = options.window_1,
            .window_obj = options.window_obj,
        };
    }
};

/// Display control register. Corresponds to REG_DISPCNT.
pub const ctrl: *volatile Control = @ptrCast(gba.mem.io.reg_dispcnt);
