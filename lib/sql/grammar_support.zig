pub const Token = enum {
    EOF,
};

pub const Rule = union(enum) {
    token: Token,
    one_of: []const OneOf,
    all_of: []const RuleRef,
    optional: RuleRef,
    repeat: Repeat,
};

pub const OneOf = union(enum) {
    choice: RuleRef,
    committed_choice: [2]RuleRef,
};

pub const Repeat = struct {
    min_count: usize,
    element: RuleRef,
    separator: ?RuleRef,
};

pub const RuleRef = struct {
    field_name: ?[]const u8,
    rule_name: []const u8,
};
