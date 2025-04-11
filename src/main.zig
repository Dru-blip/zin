const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("leak detected:{}\n", .{check});
        }
    }
    _ = Lexer.init(allocator, "5+4");
}
