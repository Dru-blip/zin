const std = @import("std");
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");
const Ast = @import("ast.zig");
const DataPool = @import("DataPool.zig");
const Compiler = @import("./bytecode/compiler.zig");
const Disassembler = @import("./bytecode/disassembler.zig");
const VM = @import("./vm/vm.zig");

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
    var lex = Lexer.init(allocator, terminated_buffer);

    // deallocate lexer memory when block is exited
    defer lex.dealloc();

    // fill the lexer with tokens
    try lex.tokenize();

    var data_pool = DataPool.init(allocator);

    defer data_pool.deinit();
    // lexer.printTokens();
    var tree = try Ast.init(allocator, &lex.tokens);
    // const arena_allocator = std.heap.ArenaAllocator.init(allocator);
    // initialize parser with token sequence
    var parser = try Parser.init(&tree, &data_pool, terminated_buffer, &lex.tokens);

    // arena_allocator.deinit();
    // deallocate parser memory when block is exited
    defer tree.deinit();

    // try to parse the token sequence
    try parser.parse();

    // tree.printAst();
    // try ast.printAst(&data_pool);
    // var bc = Compiler.init(allocator, &tree, &data_pool, &lex.tokens);
    // defer bc.deinit();

    // try bc.compile();

    // std.debug.print("{}\n", .{bc.unit.code.items.len});

    // var dis = Disassembler.init(&data_pool, &bc.unit);

    // try dis.disassemble();
    // var vm = VM.init(allocator, &bc.unit);

    // defer vm.deinit();

    // try vm.run();
}
