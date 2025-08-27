//! This module provides an API for reading the state of the GBA's
//! buttons, which are also called "keys".
//!
//! Conventional usage of this library would be like so:
//!
//! ```zig
//! const gba = @import("gba.zig");
//! 
//! pub export fn main() void {
//!     // Initialize an object to contain input state.
//!     var input: gba.input.BufferedKeysState = .{};
//! 
//!     while (true) {
//!         // Wait for the next frame.
//!         gba.display.naiveVSync();
//!         // Update the input state object.
//!         input.poll();
//! 
//!         if(input.isJustPressed(.start)) {
//!             // Do something when the start button was just pressed
//!         }
//!     }
//! }
//! ```

const gba = @import("gba.zig");

/// Enumeration of physical buttons (or "keys") on the GBA console.
pub const Key = enum(u4) {
    /// "A" face button (right side).
    A = 0,
    /// "B" face button (left side).
    B = 1,
    /// "SELECT" button.
    select = 2,
    /// "START" button.
    start = 3,
    /// D-pad right.
    right = 4,
    /// D-pad left.
    left = 5,
    /// D-pad up.
    up = 6,
    /// D-pad down.
    down = 7,
    /// Right shoulder button.
    R = 8,
    /// Left shoulder button.
    L = 9,
};

/// Holds a bitfield representing the state of each of the console's buttons.
///
/// Represents the contents of the system's REG_KEYINPUT register.
pub const KeysState = packed struct(u16) {
    /// The key input hardware register uses a 0 bit to represent
    /// a button being pressed and a 1 bit to represent it being released.
    pub const KeyState = enum(u1) {
        pressed = 0,
        released = 1,
    };
    
    /// State of the system's A (right) face button.
    button_a: KeyState = .released,
    /// State of the system's B (left) face button.
    button_b: KeyState = .released,
    /// State of the system's select button.
    button_select: KeyState = .released,
    /// State of the system's start button.
    button_start: KeyState = .released,
    /// State of the system's dpad right button.
    button_right: KeyState = .released,
    /// State of the system's dpad left button.
    button_left: KeyState = .released,
    /// State of the system's dpad up button.
    button_up: KeyState = .released,
    /// State of the system's dpad down button.
    button_down: KeyState = .released,
    /// State of the system's R (right) shoulder button.
    button_r: KeyState = .released,
    /// State of the system's L (left) shoulder button.
    button_l: KeyState = .released,
    /// Unused bits.
    _: u6 = 0,
    
    /// Overwrite the object's state with the system's current input state.
    pub fn poll(self: *KeysState) void {
        self.* = state.*;
    }
    
    /// Returns true when a given button was pressed down.
    pub fn isPressed(self: KeysState, key: Key) bool {
        return switch(key) {
            .A => self.button_a == .pressed,
            .B => self.button_b == .pressed,
            .select => self.button_select == .pressed,
            .start => self.button_start == .pressed,
            .right => self.button_right == .pressed,
            .left => self.button_left == .pressed,
            .up => self.button_up == .pressed,
            .down => self.button_down == .pressed,
            .R => self.button_r == .pressed,
            .L => self.button_l == .pressed,
        };
    }
    
    /// Returns true when any of the system's buttons were pressed down.
    pub inline fn isAnyPressed(self: KeysState) bool {
        return @as(u16, @bitCast(self)) != 0x03ff;
    }
    
    /// Returns a signed integer representing the state of the system's
    /// left and right dpad buttons.
    ///
    /// Returns -1 when left is pressed but not right,
    /// +1 when right is pressed but not left, and 0 otherwise.
    pub fn getAxisHorizontal(self: KeysState) i2 {
        return (
            @as(i2, if(self.isPressed(.left)) -1 else 0) +
            @as(i2, if(self.isPressed(.right)) 1 else 0)
        );
    }
    
    /// Returns a signed integer representing the state of the system's
    /// up and down dpad buttons.
    ///
    /// Returns -1 when up is pressed but not down,
    /// +1 when down is pressed but not up, and 0 otherwise.
    pub fn getAxisVertical(self: KeysState) i2 {
        return (
            @as(i2, if(self.isPressed(.up)) -1 else 0) +
            @as(i2, if(self.isPressed(.down)) 1 else 0)
        );
    }
    
    /// Returns a signed integer representing the state of the system's
    /// L (left) and R (right) shoulder buttons.
    ///
    /// Returns -1 when L is pressed but not R,
    /// +1 when R is pressed but not L, and 0 otherwise.
    pub fn getAxisShoulders(self: KeysState) i2 {
        return (
            @as(i2, if(self.isPressed(.L)) -1 else 0) +
            @as(i2, if(self.isPressed(.R)) 1 else 0)
        );
    }
};

/// Maintains both a current and previous `KeysState` state.
/// This makes it easy to check if a button was just pressed or released,
/// i.e. that its state changed between one polling and the next.
pub const BufferedKeysState = packed struct(u32) {
    /// The most recently polled input state.
    current: KeysState = .{},
    /// The previously polled input state.
    previous: KeysState = .{},
    
    /// Poll the system's current input state and update the input state
    /// information accordingly.
    ///
    /// Normally, you will want to call this function once at the beginning
    /// of every frame.
    pub fn poll(self: *BufferedKeysState) void {
        self.previous = self.current;
        self.current = state.*;
    }
    
    /// Poll the system's current input state and return a new
    /// `BufferedKeysState` object representing the subsequent input state.
    pub fn pollNext(self: BufferedKeysState) BufferedKeysState {
        return BufferedKeysState{
            .current = state.*,
            .previous = self.current,
        };
    }
    
    /// Returns true when a given button is currently pressed down.
    pub inline fn isPressed(self: BufferedKeysState, key: Key) bool {
        return self.current.isPressed(key);
    }
    
    /// Returns true when a given button was just pressed.
    pub inline fn isJustPressed(self: BufferedKeysState, key: Key) bool {
        return self.current.isPressed(key) and !self.previous.isPressed(key);
    }
    
    /// Returns true when a given button was just released.
    pub inline fn isJustReleased(self: BufferedKeysState, key: Key) bool {
        return self.previous.isPressed(key) and !self.current.isPressed(key);
    }
    
    /// Returns true when any of the system's buttons are currently pressed down.
    pub inline fn isAnyPressed(self: BufferedKeysState) bool {
        return self.current.isAnyPressed();
    }
    
    /// Returns true when any of the system's buttons are currently pressed down.
    pub inline fn isAnyJustPressed(self: BufferedKeysState) bool {
        return self.current.isAnyPressed() and !self.previous.isAnyPressed();
    }
    
    /// Returns a signed integer representing the state of the system's
    /// left and right dpad buttons.
    ///
    /// Returns -1 when left is pressed but not right,
    /// +1 when right is pressed but not left, and 0 otherwise.
    pub inline fn getAxisHorizontal(self: BufferedKeysState) i2 {
        return self.current.getAxisHorizontal();
    }
    
    /// Returns a signed integer representing the state of the system's
    /// up and down dpad buttons.
    ///
    /// Returns -1 when up is pressed but not down,
    /// +1 when down is pressed but not up, and 0 otherwise.
    pub inline fn getAxisVertical(self: BufferedKeysState) i2 {
        return self.current.getAxisVertical();
    }
    
    /// Returns a signed integer representing the state of the system's
    /// L (left) and R (right) shoulder buttons.
    ///
    /// Returns -1 when L is pressed but not R,
    /// +1 when R is pressed but not L, and 0 otherwise.
    pub inline fn getAxisShoulders(self: BufferedKeysState) i2 {
        return self.current.getAxisShoulders();
    }
};

/// Represents the contents of the key interrupt control register, REG_KEYCNT.
pub const InterruptControl = packed struct(u16) {
    /// Used to indicate which buttons ("keys") are selected or ignored,
    /// when determining whether an interrupt should be triggered.
    pub const KeyState = enum(u1) {
        ignore = 0,
        select = 1,
    };
    
    /// Describes the condition upon which an interrupt is triggered.
    pub const Condition = enum(u1) {
        /// Trigger an interrupt when at least one of the selected keys
        /// is pressed.
        any = 0,
        /// Trigger an interrupt when all of the selected keys
        /// are pressed.
        all = 1,
    };

    /// If selected, the system's A (right) face button affects interrupt behavior.
    button_a: KeyState = .ignore,
    /// If selected, the system's B (left) face button affects interrupt behavior.
    button_b: KeyState = .ignore,
    /// If selected, the system's select button affects interrupt behavior.
    button_select: KeyState = .ignore,
    /// If selected, the system's start button affects interrupt behavior.
    button_start: KeyState = .ignore,
    /// If selected, the system's dpad right button affects interrupt behavior.
    button_right: KeyState = .ignore,
    /// If selected, the system's dpad left button affects interrupt behavior.
    button_left: KeyState = .ignore,
    /// If selected, the system's dpad up button affects interrupt behavior.
    button_up: KeyState = .ignore,
    /// If selected, the system's dpad down button affects interrupt behavior.
    button_down: KeyState = .ignore,
    /// If selected, the system's R (right) shoulder button affects interrupt behavior.
    button_r: KeyState = .ignore,
    /// If selected, the system's L (left) shoulder button affects interrupt behavior.
    button_l: KeyState = .ignore,
    /// Unused bits.
    _: u4 = 0,
    /// Whether to enable interrupts when the input state condition is met.
    interrupt: bool = false,
    /// Determines whether to trigger an interrupt when any of the selected
    /// keys are pressed, or when all of them are pressed.
    condition: Condition = .any,
    
    /// Set the state of a given key to `KeyState.select`.
    pub fn select(self: *volatile InterruptControl, key: Key) void {
        const self_16: u16 = @bitCast(self.*);
        self.* = @bitCast(self_16 | (@as(u16, 1) << @intFromEnum(key)));
    }
    
    /// Set the state of a given key to `KeyState.ignore`.
    pub fn ignore(self: *volatile InterruptControl, key: Key) void {
        const self_16: u16 = @bitCast(self.*);
        self.* = @bitCast(self_16 & ~(@as(u16, 1) << @intFromEnum(key)));
    }
};

/// Records the current state of the GBA's buttons (also called "keys").
/// Corresponds to REG_KEYINPUT.
/// Note that a 0 bit indicates a pressed button and a 1 bit indicates a
/// not-pressed button.
pub const state: *align(2) volatile KeysState = @ptrCast(gba.mem.io.reg_keyinput);

/// Corresponds to REG_KEYCNT.
/// Can be used to request an interrupt when certain buttons are pressed.
pub const interrupt: *align(2) volatile InterruptControl = @ptrCast(gba.mem.io.reg_keycnt);
