const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Ast = @import("ast.zig").Ast;

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

    const source = "var x=12+5";

    // initialize lexer
    var lexer = Lexer.init(allocator, source);

    // deallocate lexer memory when block is exited
    defer lexer.dealloc();

    // fill the lexer with tokens
    try lexer.tokenize();

    var ast = try Ast.init(allocator);
    // const arena_allocator = std.heap.ArenaAllocator.init(allocator);
    // initialize parser with token sequence
    var parser = try Parser.init(&ast, source, &lexer.tokens);

    // arena_allocator.deinit();
    // deallocate parser memory when block is exited
    defer ast.deinit();

    // try to parse the token sequence
    try parser.parse();

    // print the tree
    ast.printAst();
}
