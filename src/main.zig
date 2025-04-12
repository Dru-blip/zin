const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    // initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    // deallocate memory when block is exited
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.log.err("leak detected: {}\n", .{check});
        }
    }

    const source = "var x=5";

    // initialize lexer
    var lexer = Lexer.init(allocator, source);

    // deallocate lexer memory when block is exited
    defer lexer.dealloc();

    // fill the lexer with tokens
    try lexer.tokenize();

    // initialize parser with token sequence
    var parser = try Parser.init(allocator, source, &lexer.tokens);

    // deallocate parser memory when block is exited
    defer parser.deinit();

    // try to parse the token sequence
    try parser.parse();

    // print the tree
    parser.printAst();
}
