const std = @import("std");
const GcObj = @import("object.zig").GcObj;

const GC = struct {
    allocator: std.mem.Allocator,
    root: *GcObj,

    pub fn init(allocator: std.mem.Allocator) GC {
        return GC{
            .allocator = allocator,
            .root = null,
        };
    }
};
