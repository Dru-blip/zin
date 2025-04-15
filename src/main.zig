const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Ast = @import("ast.zig").Ast;
const DataPool = @import("pool.zig").DataPool;
const Compiler = @import("./bytecode/compiler.zig").Compiler;
const Disassembler = @import("./bytecode/disassembler.zig").Disassembler;
const VM = @import("./vm/vm.zig").VM;

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

    const file = try std.fs.cwd().openFile("./examples/hello.zin", .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const buffer = try allocator.alloc(u8, file_size + 1);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    buffer[file_size - 1] = 0;

    const terminated_buffer: [:0]const u8 = buffer[0 .. file_size - 1 :0];
    // initialize lexer
    var lexer = Lexer.init(allocator, terminated_buffer);

    // deallocate lexer memory when block is exited
    defer lexer.dealloc();

    // fill the lexer with tokens
    try lexer.tokenize();

    var data_pool = DataPool.init(allocator);

    defer data_pool.deinit();
    // lexer.printTokens();
    var ast = try Ast.init(allocator);
    // const arena_allocator = std.heap.ArenaAllocator.init(allocator);
    // initialize parser with token sequence
    var parser = try Parser.init(&ast, &data_pool, terminated_buffer, &lexer.tokens);

    // arena_allocator.deinit();
    // deallocate parser memory when block is exited
    defer ast.deinit();

    // try to parse the token sequence
    try parser.parse();

    // ast.printAst();
    var compiler = Compiler.init(allocator, &ast, &data_pool, &lexer.tokens);
    defer compiler.deinit();

    try compiler.compile();

    var vm = VM.init(allocator, &compiler.unit);

    defer vm.deinit();

    try vm.run();
    // var dis = Disassembler.init(&data_pool, &compiler.unit);

    // try dis.disassemble();
}
