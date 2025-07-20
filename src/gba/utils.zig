/// Ternary primitive
pub const TriState = enum(i2) {
    minus = -1,
    zero = 0,
    plus = 1,

    pub fn get(minus: bool, plus: bool) TriState {
        return @enumFromInt(@as(i2, @intCast(@intFromBool(plus))) - @intFromBool(minus));
    }

    pub fn toInt(self: TriState) i2 {
        return @intFromEnum(self);
    }

    pub fn scale(self: TriState, amt: anytype) @TypeOf(amt) {
        return amt * self.toInt();
    }
};
