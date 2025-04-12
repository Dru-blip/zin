const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("lexer.zig").Token;
const Index = ast.Index;
const Ast = ast.Ast;
const TokenIndex = ast.TokenIndex;
const Node = ast.Node;

const SyntaxError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
    ExpectedIdentifier,
};

pub const Parser = struct {
    ast: Ast,
    tokens: *std.ArrayList(Token),
    position: TokenIndex,
    source: [:0]const u8,
    current_token: Token,
    allocator: std.mem.Allocator,

    const State = enum {
        start,
        var_decl,
    };
    /// initialize a new parser with allocator
    pub fn init(
        allocator: std.mem.Allocator,
        source: [:0]const u8,
        tokens: *std.ArrayList(Token),
    ) !Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .ast = try Ast.init(allocator),
            .allocator = allocator,
            .current_token = tokens.items[0],
            .position = 0,
        };
    }

    /// deallocate memory for ast nodes
    pub fn deinit(
        self: *Parser,
    ) void {
        self.ast.deinit();
    }

    fn advance(self: *Parser) void {
        self.position += 1;
        self.current_token = self.tokens.items[self.position];
    }

    fn eat(self: *Parser, tag: Token.Tag) !void {
        if (self.current_token.tag != tag) {
            return SyntaxError.UnexpectedToken;
        }
        self.advance();
    }

    /// print the flattened AST
    pub fn printAst(self: *Parser) void {
        var i: usize = 0;
        while (self.ast.nodes.len > i) : (i += 1) {
            const node = self.ast.nodes.get(i);
            std.log.info("ast {}: {}", .{ i, node.tag });
        }
    }

    /// top level parse function
    pub fn parse(self: *Parser) !void {
        // parse until eof token is hit
        while (self.current_token.tag != .eof) {
            state: switch (State.start) {
                .start => {
                    switch (self.current_token.tag) {
                        .keyword_var => continue :state .var_decl,
                        else => return SyntaxError.UnexpectedToken,
                    }
                },
                .var_decl => try self.parseVarDecl(),
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

    fn parseVarDecl(self: *Parser) !void {
        try self.eat(.keyword_var);
        const id = self.position;
        try self.eat(.id);
        try self.eat(.equal);

        var data: Node.Data = .{ .var_decl = .{ .init = 0 } };
        _ = try self.ast.append(
            data,
            .var_decl,
            id,
        );
        const initializer = try self.parseExpr();
        data.var_decl.init = initializer;
    }

    /// parse expression
    fn parseExpr(self: *Parser) !Index {
        return self.parseInt();
    }

    /// parse integer token
    fn parseInt(self: *Parser) !Index {
        // get the current token
        const token = self.current_token;
        // if token is not an integer, return unexpected token error
        if (token.tag != .integer) return SyntaxError.UnexpectedToken;

        // parse the source literal to integer
        const value = try std.fmt.parseInt(i32, self.source[token.start..token.end], 10);
        // append the integer node to the ast array
        const index = try self.ast.append(
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
