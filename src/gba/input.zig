//! This module provides an API for reading the state of the GBA's
//! buttons, which are also called "keys".

const std = @import("std");
const gba = @import("gba.zig");

/// Enumeration of physical buttons (or "keys") on the GBA console.
pub const Key = enum {
    A,
    B,
    select,
    start,
    right,
    left,
    up,
    down,
    R,
    L,
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
    
    /// Returns true when the system's A (right) face button was pressed down.
    pub inline fn aIsPressed(self: KeysState) bool {
        return self.button_a == .pressed;
    }
    
    /// Returns true when the system's B (left) face button was pressed down.
    pub inline fn bIsPressed(self: KeysState) bool {
        return self.button_b == .pressed;
    }
    
    /// Returns true when the system's select button was pressed down.
    pub inline fn selectIsPressed(self: KeysState) bool {
        return self.button_select == .pressed;
    }
    
    /// Returns true when the system's start button was pressed down.
    pub inline fn startIsPressed(self: KeysState) bool {
        return self.button_start == .pressed;
    }
    
    /// Returns true when the system's dpad right button was pressed down.
    pub inline fn rightIsPressed(self: KeysState) bool {
        return self.button_right == .pressed;
    }
    
    /// Returns true when the system's dpad left button was pressed down.
    pub inline fn leftIsPressed(self: KeysState) bool {
        return self.button_left == .pressed;
    }
    
    /// Returns true when the system's dpad up button was pressed down.
    pub inline fn upIsPressed(self: KeysState) bool {
        return self.button_up == .pressed;
    }
    
    /// Returns true when the system's dpad down button was pressed down.
    pub inline fn downIsPressed(self: KeysState) bool {
        return self.button_down == .pressed;
    }
    
    /// Returns true when the system's R (right) shoulder button was pressed down.
    pub inline fn rIsPressed(self: KeysState) bool {
        return self.button_r == .pressed;
    }
    
    /// Returns true when the system's L (left) shoulder button was pressed down.
    pub inline fn lIsPressed(self: KeysState) bool {
        return self.button_l == .pressed;
    }
    
    /// Returns true when any of the system's buttons were pressed down.
    pub inline fn anyIsPressed(self: KeysState) bool {
        return @as(u16, self) != 0x07ff;
    }
    
    /// Returns a signed integer representing the state of the system's
    /// left and right dpad buttons.
    ///
    /// Returns -1 when left is pressed but not right,
    /// +1 when right is pressed but not left, and 0 otherwise.
    pub fn getAxisHorizontal(self: KeysState) i2 {
        return (
            @as(i2, if(self.leftIsPressed()) -1 else 0) +
            @as(i2, if(self.rightIsPressed()) 1 else 0)
        );
    }
    
    /// Returns a signed integer representing the state of the system's
    /// up and down dpad buttons.
    ///
    /// Returns -1 when up is pressed but not down,
    /// +1 when down is pressed but not up, and 0 otherwise.
    pub fn getAxisVertical(self: KeysState) i2 {
        return (
            @as(i2, if(self.upIsPressed()) -1 else 0) +
            @as(i2, if(self.downIsPressed()) 1 else 0)
        );
    }
    
    /// Returns a signed integer representing the state of the system's
    /// L (left) and R (right) shoulder buttons.
    ///
    /// Returns -1 when L is pressed but not R,
    /// +1 when R is pressed but not L, and 0 otherwise.
    pub fn getAxisShoulders(self: KeysState) i2 {
        return (
            @as(i2, if(self.lIsPressed()) -1 else 0) +
            @as(i2, if(self.rIsPressed()) 1 else 0)
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
    
    /// Returns true when the system's A (right) face button is currently pressed down.
    pub inline fn aIsPressed(self: BufferedKeysState) bool {
        return self.current.aIsPressed();
    }
    
    /// Returns true when the system's A (right) face button was just pressed.
    pub inline fn aIsJustPressed(self: BufferedKeysState) bool {
        return self.current.aIsPressed() and !self.previous.aIsPressed();
    }
    
    /// Returns true when the system's A (right) face button was just released.
    pub inline fn aIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.aIsPressed() and !self.current.aIsPressed();
    }
    
    /// Returns true when the system's B (left) face button is currently pressed down.
    pub inline fn bIsPressed(self: BufferedKeysState) bool {
        return self.current.bIsPressed();
    }
    
    /// Returns true when the system's B (left) face button was just pressed.
    pub inline fn bIsJustPressed(self: BufferedKeysState) bool {
        return self.current.bIsPressed() and !self.previous.bIsPressed();
    }
    
    /// Returns true when the system's B (left) face button was just released.
    pub inline fn bIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.bIsPressed() and !self.current.bIsPressed();
    }
    
    /// Returns true when the system's select button is currently pressed down.
    pub inline fn selectIsPressed(self: BufferedKeysState) bool {
        return self.current.selectIsPressed();
    }
    
    /// Returns true when the system's select button was just pressed.
    pub inline fn selectIsJustPressed(self: BufferedKeysState) bool {
        return self.current.selectIsPressed() and !self.previous.selectIsPressed();
    }
    
    /// Returns true when the system's select button was just released.
    pub inline fn selectIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.selectIsPressed() and !self.current.selectIsPressed();
    }
    
    /// Returns true when the system's start button is currently pressed down.
    pub inline fn startIsPressed(self: BufferedKeysState) bool {
        return self.current.startIsPressed();
    }
    
    /// Returns true when the system's start button was just pressed.
    pub inline fn startIsJustPressed(self: BufferedKeysState) bool {
        return self.current.startIsPressed() and !self.previous.startIsPressed();
    }
    
    /// Returns true when the system's start button was just released.
    pub inline fn startIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.startIsPressed() and !self.current.startIsPressed();
    }
    
    /// Returns true when the system's dpad right button is currently pressed down.
    pub inline fn rightIsPressed(self: BufferedKeysState) bool {
        return self.current.rightIsPressed();
    }
    
    /// Returns true when the system's dpad right button was just pressed.
    pub inline fn rightIsJustPressed(self: BufferedKeysState) bool {
        return self.current.rightIsPressed() and !self.previous.rightIsPressed();
    }
    
    /// Returns true when the system's dpad right button was just released.
    pub inline fn rightIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.rightIsPressed() and !self.current.rightIsPressed();
    }
    
    /// Returns true when the system's dpad left button is currently pressed down.
    pub inline fn leftIsPressed(self: BufferedKeysState) bool {
        return self.current.leftIsPressed();
    }
    
    /// Returns true when the system's dpad left button was just pressed.
    pub inline fn leftIsJustPressed(self: BufferedKeysState) bool {
        return self.current.leftIsPressed() and !self.previous.leftIsPressed();
    }
    
    /// Returns true when the system's dpad left button was just released.
    pub inline fn leftIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.leftIsPressed() and !self.current.leftIsPressed();
    }
    
    /// Returns true when the system's dpad up button is currently pressed down.
    pub inline fn upIsPressed(self: BufferedKeysState) bool {
        return self.current.upIsPressed();
    }
    
    /// Returns true when the system's dpad up button was just pressed.
    pub inline fn upIsJustPressed(self: BufferedKeysState) bool {
        return self.current.upIsPressed() and !self.previous.upIsPressed();
    }
    
    /// Returns true when the system's dpad up button was just released.
    pub inline fn upIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.upIsPressed() and !self.current.upIsPressed();
    }
    
    /// Returns true when the system's dpad down button is currently pressed down.
    pub inline fn downIsPressed(self: BufferedKeysState) bool {
        return self.current.downIsPressed();
    }
    
    /// Returns true when the system's dpad down button was just pressed.
    pub inline fn downIsJustPressed(self: BufferedKeysState) bool {
        return self.current.downIsPressed() and !self.previous.downIsPressed();
    }
    
    /// Returns true when the system's dpad down button was just released.
    pub inline fn downIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.downIsPressed() and !self.current.downIsPressed();
    }
    
    /// Returns true when the system's R (right) shoulder button is currently pressed down.
    pub inline fn rIsPressed(self: BufferedKeysState) bool {
        return self.current.rIsPressed();
    }
    
    /// Returns true when the system's R (right) shoulder button was just pressed.
    pub inline fn rIsJustPressed(self: BufferedKeysState) bool {
        return self.current.rIsPressed() and !self.previous.rIsPressed();
    }
    
    /// Returns true when the system's R (right) shoulder button was just released.
    pub inline fn rIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.rIsPressed() and !self.current.rIsPressed();
    }
    
    /// Returns true when the system's L (left) shoulder button is currently pressed down.
    pub inline fn lIsPressed(self: BufferedKeysState) bool {
        return self.current.lIsPressed();
    }
    
    /// Returns true when the system's L (left) shoulder button was just pressed.
    pub inline fn lIsJustPressed(self: BufferedKeysState) bool {
        return self.current.lIsPressed() and !self.previous.lIsPressed();
    }
    
    /// Returns true when the system's L (left) shoulder button was just released.
    pub inline fn lIsJustReleased(self: BufferedKeysState) bool {
        return self.previous.lIsPressed() and !self.current.lIsPressed();
    }
    
    /// Returns true when any of the system's buttons are currently pressed down.
    pub inline fn anyIsPressed(self: BufferedKeysState) bool {
        return self.current.anyIsPressed();
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
    _: u4,
    /// Whether to enable interrupts when the input state condition is met.
    interrupt: bool,
    /// Determines whether to trigger an interrupt when any of the selected
    /// keys are pressed, or when all of them are pressed.
    condition: Condition,
};

/// Records the current state of the GBA's buttons (also called "keys").
/// 
/// Corresponds to REG_KEYINPUT.
/// Note that a 0 bit indicates a pressed button and a 1 bit indicates a
/// not-pressed button.
pub const state: *align(2) const volatile KeysState = @ptrFromInt(gba.mem.io + 0x130);

/// Corresponds to REG_KEYCNT.
/// Can be used to request an interrupt when certain buttons are pressed.
pub const ctrl: *align(2) const volatile InterruptControl = @ptrFromInt(gba.mem.io + 0x130);
