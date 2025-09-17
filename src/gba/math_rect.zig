const gba = @import("gba.zig");

/// Represents a rectangle with X, Y, width, and height components.
pub fn Rect(comptime T: type) type {
    return extern struct {
        const Self = @This();
        const Vec2T = gba.math.Vec2(T);
        
        /// Horizontal position of the rectangle's top left corner.
        /// Like the GBA's screen coordinates, X increases from left to right.
        x: T,
        /// Vertical position of the rectangle's top left corner.
        /// Like the GBA's screen coordinates, Y increases from top to bottom.
        y: T,
        /// Width of the rectangle.
        width: T,
        /// Height of the rectangle.
        height: T,
        
        /// Initialize a `Rect` instance.
        pub fn init(x: T, y: T, width: T, height: T) Self {
            return .{ .x = x, .y = y, .width = width, .height = height };
        }
        
        /// Initialize with bounds rather than size.
        pub fn initBounds(x_min: T, y_min: T, x_max: T, y_max: T) Self {
            return .init(x_min, y_min, x_max - x_min, y_max - y_min);
        }
        
        /// Get the product of width and height.
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
        
        /// Get the top-left corner of the rectange as a vector.
        pub fn topLeft(self: Self) Vec2T {
            return .init(self.x, self.y);
        }
        
        /// Get the top-right corner of the rectange as a vector.
        pub fn topRight(self: Self) Vec2T {
            return .init(self.x + self.width, self.y);
        }
        
        /// Get the bottom-left corner of the rectange as a vector.
        pub fn bottomLeft(self: Self) Vec2T {
            return .init(self.x, self.y + self.height);
        }
        
        /// Get the bottom-right corner of the rectange as a vector.
        pub fn bottomRight(self: Self) Vec2T {
            return .init(self.x + self.width, self.y + self.height);
        }
        
        /// Get the center of the rectange as a vector.
        pub fn center(self: Self) Vec2T {
            return .init(
                self.x + (self.width >> 1),
                self.y + (self.height >> 1),
            );
        }
    };
}

/// Rectangle with signed 8-bit integer components.
pub const RectI8 = Rect(i8);

/// Rectangle with unsigned 8-bit integer components.
pub const RectU8 = Rect(u8);

/// Rectangle with signed 16-bit integer components.
pub const RectI16 = Rect(i16);

/// Rectangle with unsigned 16-bit integer components.
pub const RectU16 = Rect(u16);

/// Rectangle with signed 32-bit integer components.
pub const RectI32 = Rect(i32);

/// Rectangle with unsigned 32-bit integer components.
pub const RectU32 = Rect(u32);
