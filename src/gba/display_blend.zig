//! This module provides an API for interacting with the REG_BLDCNT,
//! REG_BLDALPHA, and REG_BLDY hardware registers, which can be used
//! to create blending, fading, and transparency effects.

const gba = @import("gba.zig");

/// Represents the contents of REG_BLDCNT, REG_BLDALPHA, and REG_BLDY.
pub const Blend = extern struct {
    /// Represents the contents of REG_BLDCNT.
    pub const Control = packed struct(u16) {
        /// Enumeration of blending modes.
        pub const Mode = enum(u2) {
            /// No blending. Blending effects are disabled.
            none,
            /// Blend A and B layers.
            alpha,
            /// Blend A with white.
            white,
            /// Blend A with black.
            black,
        };
        
        /// Has a flag for each blend layer.
        pub const LayerFlags = packed struct(u6) {
            pub const all: LayerFlags = @bitCast(0x3f);
            pub const none: LayerFlags = .{};
            
            /// Background 0 layer.
            bg0: bool = false,
            /// Background 1 layer.
            bg1: bool = false,
            /// Background 2 layer.
            bg2: bool = false,
            /// Background 3 layer.
            bg3: bool = false,
            /// Object/sprite layer.
            obj: bool = false,
            /// Backdrop layer.
            /// The backdrop is a solid-color layer filled with palette color 0.
            backdrop: bool = false,
        };
        
        /// Select layers for blend A.
        a: LayerFlags = .none,
        /// Determines blending behavior.
        mode: Mode = .none,
        /// Select layers for blend B.
        b: LayerFlags = .none,
        /// Unused bits.
        _: u2 = 0,
        
        pub fn init(mode: Mode, a: LayerFlags, b: LayerFlags) Control {
            return .{ .mode = mode, .a = a, .b = b };
        }
        
        /// Initialize a `Control` value for use with `Mode.alpha`.
        pub fn initAlpha(a: LayerFlags, b: LayerFlags) Control {
            return .{ .mode = .alpha, .a = a, .b = b };
        }
        
        /// Initialize a `Control` value for use with `Mode.white`.
        pub fn initWhite(a: LayerFlags) Control {
            return .{ .mode = .white, .a = a };
        }
        
        /// Initialize a `Control` value for use with `Mode.black`.
        pub fn initBlack(a: LayerFlags) Control {
            return .{ .mode = .black, .a = a };
        }
    };
    
    /// Represents the contents of REG_BLDALPHA.
    pub const Alpha = packed struct(u16) {
        /// Blend weight for blend A. Clamped to a maximum value of 16.
        a: u5,
        /// Unused bits.
        _0: u3,
        /// Blend weight for blend B. Clamped to a maximum value of 16.
        /// Used as a ratio with `Alpha.a` when `Control.mode` is `Mode.blend`.
        b: u5,
        /// Unused bits.
        _1: u3,
        
        pub fn init(a: u5, b: u5) Alpha {
            return .{ .a = a, .b = b };
        }
    };
    
    /// Represents the contents of REG_BLDY.
    /// Note that Tonc documents REG_BLDY as a 16-bit register whereas GBATEK
    /// documents it as a 32-bit register with 16 additional unused bits.
    pub const Luma = packed struct(u16) {
        pub const zero = Luma.init(0);
        
        /// Blend weight for white or black. Clamped to a maximum of 16.
        /// Used as a ratio with `Alpha.a` when `Control.mode` is
        /// `Mode.white` or `Mode.black`.
        y: u5 = 0,
        /// Unused bits.
        _: u11 = 0,
        
        pub fn init(y: u5) Luma {
            return .{ .y = y };
        }
    };
    
    /// Controls blend mode as well as which layers are involved in blending.
    /// Corresponds to REG_BLDCNT.
    ctrl: Control,
    /// Contains a blending weight for blend A (used by all modes except
    /// `Control.Mode.none`) and blend B (used only for `Control.Mode.blend`).
    /// Corresponds to REG_BLDALPHA.
    alpha: Alpha,
    /// Contains a blending weight value for blending A with white or black.
    /// Corresponds to REG_BLDY, which is write-only.
    luma: Luma,
    
    pub fn init(ctrl: Control, alpha: Alpha, luma: Luma) Blend {
        return .{ .ctrl = ctrl, .alpha = alpha, .luma = luma };
    }
    
    /// Initialize with `Mode.alpha`.
    pub fn initAlpha(
        a_flags: Control.LayerFlags,
        b_flags: Control.LayerFlags,
        a_weight: u5,
        b_weight: u5,
    ) Blend {
        return .{
            .ctrl = .initAlpha(a_flags, b_flags),
            .alpha = .init(a_weight, b_weight),
            .luma = .zero,
        };
    }
    
    /// Initialize with `Mode.white`.
    pub fn initWhite(
        a_flags: Control.LayerFlags,
        a_weight: u5,
        y_weight: u5,
    ) Blend {
        return .{
            .ctrl = .initWhite(a_flags),
            .alpha = .init(a_weight, 0),
            .luma = .init(y_weight),
        };
    }
    
    /// Initialize with `Mode.black`.
    pub fn initBlack(
        a_flags: Control.LayerFlags,
        a_weight: u5,
        y_weight: u5,
    ) Blend {
        return .{
            .ctrl = .initBlack(a_flags),
            .alpha = .init(a_weight, 0),
            .luma = .init(y_weight),
        };
    }
};

/// Controls for alpha blending.
/// Corresponds to REG_BLDCNT, REG_BLDALPHA, and REG_BLDY.
/// Note that REG_BLDY is write-only.
pub const blend: *volatile Blend = @ptrCast(gba.mem.io.reg_bldcnt);
