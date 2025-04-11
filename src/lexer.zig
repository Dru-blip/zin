const std = @import("std");

pub const Token = struct {
    pub const Tag = enum(u8) {
        keyword_if,
        keyword_and,
        keyword_or,
        keyword_var,
        keyword_else,
        keyword_def,
        keyword_struct,
        keyword_for,
        keyword_nil,
        keyword_true,
        keyword_false,

        integer,
        float,
        string,

        // punctuations
        left_paren,
        right_paren,
        left_brace,
        right_brace,
        comma,
        dot,
        semicolon,

        // operators
        minus,
        plus,
        slash,
        asterisk,
        bang,
        equal,
        equal_equal,
        bang_equal,
        angle_bracket_left,
        angle_bracket_right,
        angle_bracket_left_equal,
        angle_bracket_right_equal,

        // misc
        range,
        invalid,
        eof,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "if", Tag.keyword_if },
        .{ "and", Tag.keyword_and },
        .{ "or", Tag.keyword_or },
        .{ "var", Tag.keyword_var },
        .{ "else", Tag.keyword_else },
        .{ "def", Tag.keyword_def },
        .{ "struct", Tag.keyword_struct },
        .{ "for", Tag.keyword_for },
        .{ "nil", Tag.keyword_nil },
        .{ "true", Tag.keyword_true },
        .{ "false", Tag.keyword_false },
    });

    literal: ?[]const u8,
    line: u32,
    col: u32,
    start: u32,
    end: u32,
    tag: Tag,

    fn getKeyword(keyword: []const u8) ?Tag {
        return keywords.get(keyword);
    }
};

pub const Lexer = struct {
    input: []const u8,
    line: u32 = 1,
    col: u32 = 0,
    position: u32,
    current_char: u8,
    tokens: std.ArrayList(Token),

    const State = enum {
        start,
        integer,
        string,

        plus,
        minus,
        star,
        asterisk,
        bang,
        equal,
        angle_bracket_left,
        angle_bracket_right,
        dot,
    };

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Lexer {
        return .{
            .input = input,
            .position = 0,
            .current_char = 0,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn dealloc(self: *Lexer) !void {
        self.tokens.deinit();
    }

    fn tokenize(self: *Lexer) Token {
        var token: Token = .{
            .tag = .invalid,
            .line = self.line,
            .col = self.col,
            .start = self.position - 1,
            .literal = null,
        };

        state: switch (State.start) {
            .start => {
                switch (self.input[self.position]) {
                    ' ', '\t', '\r' => {
                        self.position += 1;
                        continue :state .start;
                    },
                    '\n' => {
                        self.line += 1;
                        self.col = 0;
                        self.position += 1;
                        continue :state .start;
                    },
                    '0'...'9' => continue :state .integer,
                    '(' => {
                        self.position += 1;
                        token.tag = .left_paren;
                    },
                    ')' => {
                        self.position += 1;
                        token.tag = .right_paren;
                    },
                    '{' => {
                        self.position += 1;
                        token.tag = .left_brace;
                    },
                    '}' => {
                        self.position += 1;
                        token.tag = .right_brace;
                    },
                    '-' => {
                        self.position += 1;
                        token.tag = .minus;
                    },
                    '/' => {
                        self.position += 1;
                        token.tag = .slash;
                    },
                    else => {
                        continue :state .invalid;
                    },
                }
            },
            .integer => switch (self.input[self.position]) {
                '0'...'9' => {
                    self.position += 1;
                    continue :state .integer;
                },
                else => {},
            },
        }

        return token;
    }
};

test "lexer_init" {
    const lexer: Lexer = Lexer.init(std.heap.page_allocator, "5+6");
    try std.testing.expect(lexer.col == 0);
}
