//! Utilities for the GBA's window feature, which acts like a mask or stencil.

const gba = @import("gba.zig");

/// Represents the structure of REG_WIN0H, REG_WIN1H, REG_WIN0V, REG_WIN1V,
/// REG_WININ, and REG_WINOUT.
pub const Window = extern struct {
    /// Represents the structure of REG_WIN0H and REG_WIN1H.
    pub const BoundsHorizontal = packed struct(u16) {
        right: u8 = 0,
        left: u8 = 0,
    };
    
    /// Represents the structure of REG_WIN0V and REG_WIN1V.
    pub const BoundsVertical = packed struct(u16) {
        bottom: u8 = 0,
        top: u8 = 0,
    };
    
    /// Contains flags determining how layers are affected by a given
    /// window region.
    /// See `Inner.win0`, `Inner.win1`, `Other.outer`, and `Other.obj`.
    pub const Layers = packed struct(u8) {
        /// All flags set.
        pub const all: Layers = @bitCast(0x3f);
        /// No flags set.
        pub const none: Layers = .{};
        
        /// Indicates whether a given window region should affect background 0.
        bg0: bool = false,
        /// Indicates whether a given window region should affect background 1.
        bg1: bool = false,
        /// Indicates whether a given window region should affect background 2.
        bg2: bool = false,
        /// Indicates whether a given window region should affect background 3.
        bg3: bool = false,
        /// Indicates whether a given window region should affect objects/sprites.
        obj: bool = false,
        /// Indicates whether blending may be used with the contents of
        /// a given window region.
        blend: bool = false,
        /// Padding bits.
        _: u2 = 0,
    };
    
    /// Determines the rectangular bounds of windows 0 and 1.
    /// Corresponds to REG_WIN0H and REG_WIN1H.
    /// Note that REG_WIN0H and REG_WIN1H are write-only.
    bounds_x: [2]BoundsHorizontal,
    /// Determines the rectangular bounds of windows 0 and 1.
    /// Corresponds to REG_WIN0V and REG_WIN1V.
    /// Note that REG_WIN0V and REG_WIN1V are write-only.
    bounds_y: [2]BoundsVertical,
    /// Indicates which layers should be affected by the window 0 region.
    /// Corresponds to REG_WIN0CNT.
    win0: Layers = .none,
    /// Indicates which layers should be affected by the window 1 region.
    /// Corresponds to REG_WIN1CNT.
    win1: Layers = .none,
    /// Indicates which layers should be affected by the region not
    /// overlapping window 0, window 1, or any object set to window mode.
    /// Corresponds to REG_WINOUTCNT.
    outer: Layers = .none,
    /// Indicates which layers should be affected by objects set to
    /// window mode. See `gba.display.Object.effect`.
    /// Corresponds to REG_WINOBJCNT.
    obj: Layers = .none,
};

/// Controls the system's window feature. This behaves like a mask or stencil
/// for drawing only parts of layers.
/// The window feature must be enabled via `gba.display.ctrl`
/// before any of the options here will have an effect.
///
/// Corresponds to REG_WIN0H, REG_WIN1H, REG_WIN0V, REG_WIN1V,
/// REG_WININ, and REG_WINOUT.
/// Note that REG_WIN0H, REG_WIN1H, REG_WIN0V, and REG_WIN1V are write-only.
pub const window: *volatile Window = @ptrCast(gba.mem.io.reg_win0h);
