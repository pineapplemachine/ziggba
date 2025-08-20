const std = @import("std");
const gba = @import("gba.zig");

extern var __data_start__: u8;
extern var __data_end__: u8;

// TODO: declaration in gba.mem could probably already just look like this?
const ewram: *volatile [0x40000]u8 = @ptrFromInt(gba.mem.ewram);

/// Get EWRAM not reserved at link time for the ROM's data section,
/// i.e. EWRAM not reserved for global variables.
pub fn getUnreservedEWRAM() []u8 {
    const data_len: usize = (
        @intFromPtr(&__data_end__) - @intFromPtr(&__data_start__)
    );
    return ewram[data_len..];
}

/// Implements a very simple allocation strategy given an owned buffer.
/// Each new allocation is made at the top of the stack.
/// If you free previous allocations in the exact reverse order as they
/// are allocated, then memory can be reclaimed. Otherwise, freeing does not
/// actually reclaim used memory.
///
/// One practical allocation strategy for games can be implemented using
/// multiple stacked `StackAllocators`:
///
/// - Initialize a root `StackAllocator` for the entire heap.
/// The convenience function `StackAllocator.initHeap` exists to make this
/// particular step very easy.
///
/// - Using the root allocator, make any allocations whose lifetime is the
/// entire runtime of the program.
///
/// - Create a second `StackAllocator` which owns all memory remaining in
/// the root allocator after those longest-lived allocations.
/// There is a convenience function for this named `StackAllocator.initStacked`.
///
/// - Use the second allocator for memory whose lifetime is for the duration
/// of a scene or level. Call `StackAllocator.reset` and then allocate all
/// needed memory upon scene or level change.
///
/// - Create a third `StackAllocator` which owns all memory remaining in the
/// second allocator after those long-lived allocations.
///
/// - Use the third allocator for short-lived allocations, and `reset` it
/// every frame.
pub const StackAllocator = struct {
    /// Buffer to be managed by this allocator.
    buffer: []u8,
    /// The next allocation will start at this index within the owned buffer.
    buffer_offset: usize = 0,
    
    /// Get an `std.mem.Allocator` representing a common interface to this
    /// allocator instance.
    pub fn allocator(self: *StackAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }
    
    /// Initialize with ownership of a given buffer.
    pub fn init(buffer: []u8) StackAllocator {
        return .{ .buffer = buffer };
    }
    
    /// Initialize by requesting a buffer from the given allocator.
    /// You probably want to call `deinit` with the same allocator argument
    /// when you're done with this allocator.
    pub fn initAlloc(
        owning_allocator: std.mem.Allocator,
        size: usize,
    ) !StackAllocator {
        return .{ .buffer = try owning_allocator.alloc(u8, size) };
    }
    
    /// Initialize another `StackAllocator` which manages all memory still
    /// remaining within another `StackAllocator`, which can be independently
    /// `reset`.
    pub fn initStacked(owning_allocator: *StackAllocator) StackAllocator {
        return .{ .buffer = owning_allocator.allocRemaining() };
    }
    
    /// Helper to initialize an allocator which manages the entire heap,
    /// meaning all of EWRAM except for whatever was reserved for global vars.
    pub fn initHeap() StackAllocator {
        return .{ .buffer = getUnreservedEWRAM() };
    }
    
    /// Reclaim memory used by this allocator.
    pub fn deinit(
        self: StackAllocator,
        owning_allocator: std.mem.Allocator,
    ) void {
        owning_allocator.free(self.buffer);
    }
    
    /// Free and invalidate all prior allocations.
    pub fn reset(self: *StackAllocator) void {
        self.buffer_offset = 0;
    }
    
    /// Claim and return all memory remaining in the allocator's owned buffer.
    pub fn allocRemaining(self: *StackAllocator) []u8 {
        defer self.buffer_offset = self.buffer.len;
        return self.buffer[self.buffer_offset..];
    }
    
    /// Get the total size in bytes of the allocator's owned buffer.
    pub fn getCapacity(self: StackAllocator) usize {
        return self.buf.len;
    }
    
    /// Get the number of remaining unallocated bytes in the owned buffer.
    pub fn getUnusedCapacity(self: StackAllocator) usize {
        return self.buf.len - self.buffer_offset;
    }
    
    /// Helper to check if some buffer is currently on the top of the stack,
    /// i.e. was the most recent allocation.
    fn isTopBuffer(self: StackAllocator, buf: []u8) bool {
        const buf_end = @intFromPtr(buf) + buf.len;
        const self_buffer_end = @intFromPtr(self.buffer) + self.buffer_offset;
        return buf_end == self_buffer_end;
    }
    
    /// Helper to check if some previously allocated is currently on the top
    /// of the stack, i.e. was the most recent allocation.
    fn isTop(self: StackAllocator, allocation: anytype) bool {
        return self.isTopBuffer(std.mem.sliceAsBytes(allocation));
    }
    
    /// Implement `std.mem.Allocator` interface.
    /// In most cases, you should use `StackAllocator.allocator().alloc`
    /// rather than calling this function directly.
    fn alloc(
        ctx: *anyopaque,
        n: usize,
        alignment: std.mem.Alignment,
        _: usize,
    ) ?[*]u8 {
        const self: *StackAllocator = @ptrCast(@alignCast(ctx));
        const aligned_ptr = std.mem.alignForward(
            *u8,
            &self.buffer + self.buffer_offset,
            alignment.toByteUnits(),
        );
        const aligned_offset = (
            @intFromPtr(aligned_ptr) - @intFromPtr(self.buffer)
        );
        const aligned_end = n + aligned_offset;
        if(aligned_end > self.buffer.len) {
            return null;
        }
        self.buffer_offset = aligned_end;
        return &self.buffer[aligned_offset];
    }
    
    /// Implement `std.mem.Allocator` interface.
    /// In most cases, you should use `StackAllocator.allocator().resize`
    /// rather than calling this function directly.
    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        _: std.mem.Alignment,
        new_len: usize,
        _: usize,
    ) ?[*]u8 {
        const self: *StackAllocator = @ptrCast(@alignCast(ctx));
        if(!self.isTopBuffer(buf)) {
            return new_len <= buf.len;
        }
        else if(buf.len >= new_len) {
            self.buffer_offset -= (buf.len - new_len);
            return true;
        }
        else if(self.buffer_offset + (new_len - buf.len) > self.buffer.len) {
            self.buffer_offset += (new_len - buf.len);
            return true;
        }
        else {
            return false;
        }
    }
    
    /// Implement `std.mem.Allocator` interface.
    /// In most cases, you should use `StackAllocator.allocator().remap`
    /// rather than calling this function directly.
    fn remap(
        ctx: *anyopaque,
        buf: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ra: usize,
    ) ?[*]u8 {
        if(resize(ctx, buf, alignment, new_len, ra)) {
            return buf.ptr;
        }
        else {
            free(ctx, buf, alignment, ra);
            const new_buf = alloc(ctx, new_len, alignment, ra);
            gba.mem.memcpy(new_buf, buf, buf.len);
            return new_buf;
        }
    }
    
    /// Implement `std.mem.Allocator` interface.
    /// In most cases, you should use `StackAllocator.allocator().free`
    /// rather than calling this function directly.
    fn free(ctx: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *StackAllocator = @ptrCast(@alignCast(ctx));
        if(self.isTopBuffer(buf)) {
            self.buffer_offset -= buf.len;
        }
    }
};
