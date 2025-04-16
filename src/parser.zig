const std = @import("std");
const ast = @import("ast.zig");
const pool = @import("pool.zig");
const Token = @import("lexer.zig").Token;
const Index = ast.Index;

const Ast = ast.Ast;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;
const IdentIndex = pool.IdentIndex;
const ConstIndex = pool.ConstIndex;

const SyntaxError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
    ExpectedVar,
    ExpectedIdentifier,
    ExpectedInteger,
};

const Errors = (std.mem.Allocator.Error || SyntaxError || std.fmt.ParseIntError);

pub const Parser = struct {
    ast: *Ast,
    data_pool: *pool.DataPool,
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
    };

    /// initialize a new parser with allocator
    pub fn init(
        tree: *Ast,
        data_pool: *pool.DataPool,
        source: [:0]const u8,
        tokens: *std.ArrayList(Token),
    ) !Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .data_pool = data_pool,
            .ast = tree,
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

    inline fn getPrecedence(_: *Parser, tag: Token.Tag) ?u4 {
        return switch (tag) {
            .plus, .minus => 2,
            .asterisk, .slash => 3,
            else => null,
        };
    }

    fn tagToError(_: *Parser, tag: Token.Tag) SyntaxError {
        switch (tag) {
            .keyword_var => {
                return SyntaxError.ExpectedVar;
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

    fn eat(self: *Parser, tag: Token.Tag) SyntaxError!void {
        if (self.current_token.tag != tag) {
            self.recordError(tag);
            return self.tagToError(tag);
        }
        self.advance();
    }

    /// top level parse function
    pub fn parse(self: *Parser) !void {
        // parse until eof token is hit
        loop: while (self.current_token.tag != .eof) {
            state: switch (State.start) {
                .start => {
                    switch (self.current_token.tag) {
                        .keyword_var => continue :state .var_decl,
                        else => {
                            std.debug.print("{}\n", .{self.current_token});
                            return SyntaxError.UnexpectedToken;
                        },
                    }
                },
                .var_decl => {
                    self.varDecl() catch {
                        self.printError();
                        break :loop;
                    };
                },
            }
        }
    }

    fn varDecl(self: *Parser) !void {
        try self.eat(.keyword_var);
        const pos = self.position;
        const id = self.tokens.items[pos];
        try self.eat(.id);
        try self.eat(.equal);

        const initializer = try self.expr(1);
        const ind = try self.data_pool.addIdent(self.source[id.start..id.end]);
        const data: Node.Data = .{
            .var_decl = .{
                .name = ind,
                .init = initializer,
            },
        };
        _ = try self.ast.append(
            data,
            .var_decl,
            pos,
        );
    }

    fn prefix(self: *Parser, tag: Token.Tag) Errors!Index {
        switch (tag) {
            .id => return try self.identifier(),
            .integer => return try self.int(),
            else => {
                self.recordError(.id);
                return SyntaxError.UnexpectedToken;
            },
        }
    }

    fn infix(self: *Parser, op_index: TokenIndex) Errors!?Index {
        const prec = self.getPrecedence(self.tokens.items[op_index].tag);
        if (prec == null) {
            return null;
        }
        return try self.expr(prec.? - 1);
    }

    /// parse expression
    fn expr(self: *Parser, precedence: u4) Errors!Index {
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
            left = try self.ast.append(
                .{
                    .binop = .{
                        .lhs = left,
                        .rhs = right,
                    },
                },
                .binop,
                op,
            );
        }

        return left;
    }

    fn identifier(self: *Parser) Errors!Index {
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
        const index = try self.ast.append(
            .{ .id = pool_ind },
            .id,
            self.position,
        );
        // move to the next token
        self.advance();

        // return the index of the identifier node
        return index;
    }

    /// parse integer token
    fn int(self: *Parser) Errors!Index {
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
        const index = try self.ast.append(
            .{ .int = pool_ind },
            .int,
            self.position,
        );
        // move to the next token
        self.advance();

        // return the index of the integer node
        return index;
    }
};
