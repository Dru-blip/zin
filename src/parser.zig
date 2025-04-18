const std = @import("std");
const Ast = @import("ast.zig");
const DataPool = @import("DataPool.zig");
const Token = @import("lexer.zig").Token;
const NodeIndex = Ast.NodeIndex;
const ExtraIndex = Ast.ExtraIndex;

const TokenIndex = Ast.TokenIndex;
const Node = Ast.Node;
const IdentIndex = DataPool.IdentIndex;
const ConstIndex = DataPool.ConstIndex;

const SyntaxError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
    ExpectedVar,
    ExpectedIdentifier,
    ExpectedInteger,
    ExpectedSemicolon,
};

const Errors = (std.mem.Allocator.Error || SyntaxError || std.fmt.ParseIntError);
const Parser = @This();

tree: *Ast,
data_pool: *DataPool,
tokens: *std.ArrayList(Token),
position: TokenIndex,
source: [:0]const u8,
current_token: Token,
err: ?Error = null,

const Error = struct {
    where: TokenIndex,
    expected: Token.Tag,
    found: Token.Tag,
};

const State = enum {
    start,
    var_decl,
    expr_stmt,
    block,
};

/// initialize a new parser with allocator
pub fn init(
    tree: *Ast,
    data_pool: *DataPool,
    source: [:0]const u8,
    tokens: *std.ArrayList(Token),
) !Parser {
    return .{
        .tokens = tokens,
        .source = source,
        .data_pool = data_pool,
        .tree = tree,
        .current_token = tokens.items[0],
        .position = 0,
    };
}

fn advance(self: *Parser) void {
    if (self.position + 1 < self.tokens.items.len) {
        self.position += 1;
        self.current_token = self.tokens.items[self.position];
    }
}

fn addExtra(self: *Parser, data: ExtraIndex) !ExtraIndex {
    const ind: u32 = @truncate(self.tree.extra.items.len);
    try self.tree.extra.append(data);
    return ind;
}

inline fn getPrecedence(_: *Parser, tag: Token.Tag) ?u4 {
    return switch (tag) {
        .equal => 1,
        .bang_equal, .equal_equal => 4,
        .angle_bracket_left,
        .angle_bracket_right,
        .angle_bracket_left_equal,
        .angle_bracket_right_equal,
        => 5,
        .plus, .minus => 8,
        .asterisk, .slash, .modulus => 9,
        else => null,
    };
}

fn tagToError(_: *Parser, tag: Token.Tag) SyntaxError {
    switch (tag) {
        .keyword_var => {
            return SyntaxError.ExpectedVar;
        },
        .semicolon => {
            return SyntaxError.ExpectedSemicolon;
        },
        else => {
            return SyntaxError.UnexpectedToken;
        },
    }
}

/// store the current error context
fn recordError(self: *Parser, tag: Token.Tag) void {
    self.err = .{
        .where = self.position,
        .expected = tag,
        .found = self.current_token.tag,
    };
}

// fn recoverOrExit(self: *Parser) void {

// }

fn printError(self: *Parser) void {
    const err_info = self.err.?;
    const found = Token.tagToLabel(err_info.found);
    const expected = Token.tagToLabel(err_info.expected);
    const at = self.tokens.items[err_info.where];

    std.debug.print("syntax error: {}:{}  found '{s}', expected '{s}'\n", .{
        at.line,
        at.col,
        found,
        expected,
    });
    // std.debug.print("{s}\n", .{found});
}

fn expectSemicolon(self: *Parser) !void {
    try self.eat(.semicolon);
}

fn eat(self: *Parser, tag: Token.Tag) SyntaxError!void {
    if (self.current_token.tag != tag) {
        self.recordError(tag);
        return self.tagToError(tag);
    }
    self.advance();
}

/// top level parse function
pub fn parse(self: *Parser) !void {
    var total_nodes: u32 = 0;

    const mod_index = try self.tree.append(.module, 0, null, null);
    var next_stmt: ?NodeIndex = null;
    // parse until eof token is hit
    loop: while (self.current_token.tag != .eof) {
        state: switch (State.start) {
            .start => {
                switch (self.current_token.tag) {
                    .keyword_var,
                    => continue :state .var_decl,
                    .left_brace => continue :state .block,
                    else => {
                        continue :state .expr_stmt;
                    },
                }
            },
            .var_decl => {
                const ind = self.pVarDecl() catch {
                    self.printError();
                    break :loop;
                };
                if (next_stmt != null) self.setNextStmt(next_stmt.?, ind);
                next_stmt = ind;
            },
            .expr_stmt => {
                const ind = self.pExprStmt() catch {
                    self.printError();
                    break :loop;
                };

                if (next_stmt != null) self.setNextStmt(next_stmt.?, ind);
                next_stmt = ind;
            },
            .block => {
                const ind = self.pBlock() catch {
                    self.printError();
                    break :loop;
                };
                if (next_stmt != null) self.setNextStmt(next_stmt.?, ind);
                next_stmt = ind;
            },
        }
        // if (total_nodes == 0) {
        // module_data.module.start = @intCast(self.tree.nodes.len - 1);
        // }
        total_nodes += 1;
    }
    self.tree.root = mod_index;
    self.finishModule(mod_index, total_nodes);
}

fn pStmt(self: *Parser) !NodeIndex {
    switch (self.current_token.tag) {
        .keyword_var => {
            return self.pVarDecl() catch {
                self.printError();
                std.process.exit(1);
            };
        },
        .left_brace => {
            return self.pBlock() catch {
                self.printError();
                std.process.exit(1);
            };
        },
        else => {
            return try self.pExprStmt();
        },
    }
}

fn pBlock(self: *Parser) Errors!NodeIndex {
    try self.eat(.left_brace);

    const block_ind = try self.tree.append(.block, self.position, null, null);

    const block_start: u32 = @intCast(self.tree.nodes.len);
    var total_stmts: u32 = 0;
    var eof: bool = false;
    var next_stmt: ?NodeIndex = null;
    block_loop: while (self.current_token.tag != .right_brace) {
        if (self.pStmt()) |ind| {
            if (next_stmt != null) self.setNextStmt(next_stmt.?, ind);
            next_stmt = ind;
        } else |err| {
            if (err == SyntaxError.UnexpectedEndOfFile) {
                eof = true;
                break :block_loop;
            }
        }

        total_stmts += 1;
    }

    try self.eat(.right_brace);
    self.finishBlock(block_ind, block_start, total_stmts);
    return block_ind;
}

fn pVarDecl(self: *Parser) !NodeIndex {
    try self.eat(.keyword_var);
    const pos = self.position;
    const id = self.tokens.items[pos];
    try self.eat(.id);
    try self.eat(.equal);

    const ind = try self.data_pool.addIdent(self.source[id.start..id.end]);

    const varDecl = try self.tree.append(.var_decl, pos, ind, null);

    const initializer = try self.pExpr(0);

    try self.expectSemicolon();

    self.setVarDeclInit(varDecl, initializer);
    return varDecl;
}

fn pExprStmt(self: *Parser) !NodeIndex {
    if (self.current_token.tag == .eof) {
        return SyntaxError.UnexpectedEndOfFile;
    }
    const expr_index = try self.tree.append(.expr_stmt, self.position, null, null);

    const ind = try self.pExpr(0);

    try self.expectSemicolon();

    const expr = &self.tree.nodes.items(.lhs)[expr_index];
    expr.* = ind;
    return expr_index;
}

fn prefix(self: *Parser, tag: Token.Tag) Errors!NodeIndex {
    switch (tag) {
        .id => return try self.pIdentifier(),
        .integer => return try self.pInteger(),
        else => {
            self.recordError(.id);
            return SyntaxError.UnexpectedToken;
        },
    }
}

fn infix(self: *Parser, op_index: TokenIndex) Errors!?NodeIndex {
    const prec = self.getPrecedence(self.tokens.items[op_index].tag);
    if (prec == null) {
        return null;
    }
    return try self.pExpr(prec.?);
}

/// parse expression
fn pExpr(self: *Parser, precedence: u4) Errors!NodeIndex {
    var left = try self.prefix(self.current_token.tag);

    while (true) {
        const token = self.current_token;
        const prec = self.getPrecedence(token.tag);

        if (prec == null or precedence >= prec.?) {
            break;
        }

        const op = self.position;
        self.advance();

        const right = try self.infix(op) orelse break;

        if (token.tag == .equal) {
            left = try self.tree.append(.assign, op, left, right);
            continue;
        }
        left = try self.tree.append(
            .binop,
            op,
            left,
            right,
        );
    }

    return left;
}

fn pIdentifier(self: *Parser) Errors!NodeIndex {
    // get the current token
    const token = self.current_token;
    // if token is not an identifier, return unexpected token error
    if (token.tag != .id) {
        self.recordError(.id);
        return SyntaxError.ExpectedIdentifier;
    }

    // parse the source literal to identifier
    const value = self.source[token.start..token.end];

    const pool_ind = try self.data_pool.addIdent(value);
    // append the identifier node to the ast array
    const index = try self.tree.append(
        .id,
        self.position,
        try self.addExtra(pool_ind),
        null,
    );
    // move to the next token
    self.advance();

    // return the index of the identifier node
    return index;
}

/// parse integer token
fn pInteger(self: *Parser) Errors!NodeIndex {
    // get the current token
    const token = self.current_token;
    // if token is not an integer, return unexpected token error
    if (token.tag != .integer) {
        self.recordError(.integer);
        return SyntaxError.ExpectedInteger;
    }

    // parse the source literal to integer
    const value = try std.fmt.parseInt(i32, self.source[token.start..token.end], 10);

    const pool_ind = try self.data_pool.addInt(value);
    // append the integer node to the ast array
    // const index = try self.tree.append(
    //     .{ .int = pool_ind },
    //     .int,
    //     self.position,
    // );
    const index = try self.tree.append(.int, self.position, try self.addExtra(pool_ind), null);
    // move to the next token
    self.advance();

    // return the index of the integer node
    return index;
}

inline fn setNextStmt(self: *Parser, stmt: NodeIndex, next_stmt: NodeIndex) void {
    const s = &self.tree.nodes.items(.next_stmt)[stmt];
    s.* = next_stmt;
}

inline fn setVarDeclInit(self: *Parser, varDecl: NodeIndex, initializer: NodeIndex) void {
    const s = &self.tree.nodes.items(.rhs)[varDecl];
    s.* = initializer;
}

inline fn finishModule(self: *Parser, module_index: NodeIndex, total_stmts: u32) void {
    // const module = &self.tree.nodes.items(.rhs)[module_index];
    const total = &self.tree.nodes.items(.rhs)[module_index];
    const offset = &self.tree.nodes.items(.offset)[module_index];

    total.* = total_stmts;
    offset.* = 1;
}

inline fn finishBlock(
    self: *Parser,
    block_index: NodeIndex,
    offset: NodeIndex,
    total_blocks: u32,
) void {
    const block = &self.tree.nodes.items(.rhs)[block_index];
    const start = &self.tree.nodes.items(.offset)[block_index];

    block.* = total_blocks;
    start.* = offset;
}
