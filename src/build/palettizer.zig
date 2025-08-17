pub const ColorRgba32 = @import("image.zig").ColorRgba32;
pub const Bpp = @import("../gba/color.zig").Color.Bpp;

/// Helper for determining what color in a palette should be used for
/// a corresponding pixel within an image.
pub const Palettizer = struct {
    /// Contains information about a pixel of an image whose palette index
    /// should be determined by a call to `get`.
    pub const Pixel = struct {
        /// Color of the pixel.
        color: ColorRgba32,
        /// X position of the pixel within an image.
        x: u16,
        /// Y position of the pixel within an image.
        y: u16,
    };
    
    pub const VTable = struct {
        get: *const fn(*anyopaque, px: Pixel) u8,
    };
    
    context: *anyopaque,
    vtable: VTable,
    
    pub fn get(self: Palettizer, px: Pixel) u8 {
        return self.vtable.get(px);
    }
};

/// Simple `Palettizer` implementation which assigns indices based on the
/// nearest linear color match within an array of colors.
///
/// Only the first 16 items are considered for 4bpp tiles,
/// and only the first 256 items for 8bpp tiles.
/// The first palette color is treated as full transparency, to reflect
/// GBA rendering behavior.
///
/// Pixels with less than full 100% opacity are always matched with palette
/// index 0. Otherwise, a Euclidean distance algorithm is used to match the
/// nearest color that isn't at index 0.
pub const PalettizerNearest = struct {
    colors: []const ColorRgba32,
    
    pub fn init(colors: []const ColorRgba32) PalettizerNearest {
        return .{ .colors = colors };
    }
    
    pub fn pal(self: *PalettizerNearest) Palettizer {
        return .{
            .context = self,
            .vtable = &.{
                .get = get,
            },
        };
    }
    
    pub fn get(self: *PalettizerNearest, px: Palettizer.Pixel) u8 {
        if (px.color.a < 0xff) {
            // Transparent pixels are always palette index 0
            return 0;
        }
        var pal_i: usize = 1;
        var pal_nearest_i: u8 = 0;
        var pal_nearest_dist: i32 = 0;
        while(pal_i < self.colors.len) {
            const pal_col = self.colors[pal_i];
            const dr = px.color.r - @as(i32, pal_col.r);
            const dg = px.color.g - @as(i32, pal_col.g);
            const db = px.color.b - @as(i32, pal_col.b);
            const dist: i32 = (dg * dg) + (dr * dr) + (db * db);
            if(pal_nearest_i <= 0 or dist < pal_nearest_dist) {
                pal_nearest_i = @truncate(pal_i);
                pal_nearest_dist = dist;
            }
            pal_i += 1;
        }
        return pal_nearest_i;
    }
};
