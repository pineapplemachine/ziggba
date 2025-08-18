/// Represents a rectangle with X, Y, width, and height components.
pub fn Rect(comptime T: type) type {
    return extern struct {
        const Self = @This();
        
        x: T,
        y: T,
        width: T,
        height: T,
        
        pub fn init(x: T, y: T, width: T, height: T) Self {
            return .{ .x = x, .y = y, .width = width, .height = height };
        }
        
        pub fn area(self: Self) T {
            return self.width * self.height;
        }
        
        /// Returns true when the `self.x <= x < (self.x + self.width)` and
        /// `self.y <= y < (self.y + self.height)`.
        pub fn containsPoint(self: Self, x: T, y: T) bool {
            return (
                x >= self.x and
                y >= self.y and
                x < (self.x + self.width) and
                y < (self.y + self.height)
            );
        }
        
        /// Returns true when a given rectangle is fully contained within this
        /// one.
        pub fn containsRect(self: Self, rect: Self) bool {
            return (
                rect.x >= self.x and
                rect.y >= self.y and
                (rect.x + rect.width) <= (self.x + self.width) and
                (rect.y + rect.height) <= (self.y + self.height)
            );
        }
    };
}

pub const RectI8 = Rect(i8);
pub const RectU8 = Rect(u8);
pub const RectI16 = Rect(i16);
pub const RectU16 = Rect(u16);
pub const RectI32 = Rect(i32);
pub const RectU32 = Rect(u32);
