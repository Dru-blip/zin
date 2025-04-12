const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.log.err("leak detected: {}\n", .{check});
        }
    }
    var lexer = Lexer.init(allocator, "5+5-5*5/5");
    defer lexer.dealloc();

    try lexer.tokenize();
    // std.debug.print("{}", .{lexer.tokens});
}
