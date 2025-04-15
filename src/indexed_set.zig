const std = @import("std");

inline fn GetMap(comptime T: type) type {
    comptime if (@typeInfo(T) == .pointer and @typeInfo(T).pointer.child == u8) {
        return std.StringHashMap(u32);
    } else {
        return std.AutoHashMap(T, u32);
    };
}

pub fn IndexedSet(comptime T: type) type {
    const Map = GetMap(T);
    return struct {
        const Index = u32;
        const Self = @This();
        values: std.ArrayList(T),
        indices: Map,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .values = std.ArrayList(T).init(allocator),
                .indices = Map.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.values.deinit();
            self.indices.deinit();
        }

        pub fn contains(self: *Self, value: T) bool {
            return self.indices.contains(value);
        }

        pub fn insert(self: *Self, value: T) !Index {
            const ind: ?u32 = self.indices.get(value);

            if (ind != null) {
                return ind.?;
            }
            const index: u32 = @truncate(self.values.items.len);
            try self.values.append(value);
            try self.indices.put(value, index);
            return index;
        }

        pub fn get(self: *Self, index: Index) T {
            return self.values.items[index];
        }
    };
}
