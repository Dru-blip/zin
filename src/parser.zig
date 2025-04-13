const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("lexer.zig").Token;
const Index = ast.Index;
const ExprIndex = ast.ExprIndex;
const Ast = ast.Ast;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;

const SyntaxError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
    ExpectedVar,
    ExpectedIdentifier,
    ExpectedInteger,
};

pub const Parser = struct {
    ast: *Ast,
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
        source: [:0]const u8,
        tokens: *std.ArrayList(Token),
    ) !Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .ast = tree,
            .current_token = tokens.items[0],
            .position = 0,
        };
    }

    fn advance(self: *Parser) void {
        self.position += 1;
        self.current_token = self.tokens.items[self.position];
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
                        else => return SyntaxError.UnexpectedToken,
                    }
                },
                .var_decl => {
                    self.varDecl() catch {
                        self.printError();
                        break :loop;
                    };
                },
            }
            // // parse expression and catch error
            // _ = self.parseExpr() catch |err| {
            //     // print error message
            //     std.log.err("{}", .{err});
            //     const tok = self.tokens.items[self.position];
            //     std.log.info("{}", .{tok.tag});
            //     self.position += 1;
            // };
        }
    }

    fn varDecl(self: *Parser) !void {
        try self.eat(.keyword_var);
        const id = self.position;
        try self.eat(.id);
        try self.eat(.equal);

        const initializer = try self.expr();
        const data: Node.Data = .{
            .var_decl = .{
                .init = initializer,
            },
        };
        _ = try self.ast.append(
            data,
            .var_decl,
            id,
        );
        // self.ast.nodes.get(index).data.var_decl.init = initializer;
    }

    /// parse expression
    fn expr(self: *Parser) !ExprIndex {
        return self.int();
    }

    /// parse integer token
    fn int(self: *Parser) !ExprIndex {
        // get the current token
        const token = self.current_token;
        // if token is not an integer, return unexpected token error
        if (token.tag != .integer) {
            self.recordError(.integer);
            return SyntaxError.ExpectedInteger;
        }

        // parse the source literal to integer
        const value = try std.fmt.parseInt(i32, self.source[token.start..token.end], 10);
        // append the integer node to the ast array
        const index = try self.ast.addExpr(
            .{ .int = .{ .value = value } },
            .int,
            self.position,
        );
        // move to the next token
        self.advance();
        // return the index of the integer node
        return index;
    }
};
