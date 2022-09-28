const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const rules = sql.grammar.rules;
const types = sql.grammar.types;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
// Last token is .eof. We don't use a sentinel type because I could lazy when trying to figure out the correct casts.
tokens: []const sql.grammar.Token,
pos: usize,

pub const Error = error{
    OutOfMemory,
};

pub fn init(
    arena: *u.ArenaAllocator,
    tokens: []const sql.grammar.Token,
) Self {
    return Self{
        .arena = arena,
        .allocator = arena.allocator(),
        .tokens = tokens,
        .pos = 0,
    };
}

// TODO memoize for left-recursion where needed

pub fn parse(self: *Self, comptime rule_name: []const u8) Error!?@field(types, rule_name) {
    const ResultType = @field(types, rule_name);
    switch (@field(rules, rule_name)) {
        .token => |token| {
            return if (self.tokens[self.pos] == token) token else null;
        },
        .one_of => |one_ofs| {
            const start_pos = self.pos;
            inline for (one_ofs) |one_of| {
                switch (one_of) {
                    .choice => |rule_ref| {
                        if (try self.parse(rule_ref.rule_name)) |result| {
                            return @unionInit(ResultType, rule_ref.field_name.?, result);
                        } else {
                            // Try next one_of.
                            self.pos = start_pos;
                        }
                    },
                    .committed_choice => |rule_refs| {
                        if (try self.parse(rule_refs[0].rule_name)) |_| {
                            // Reset after lookahead
                            self.pos = start_pos;
                            if (try self.parse(rule_refs[1].rule_name)) |result| {
                                return @unionInit(ResultType, rule_refs[1].field_name.?, result);
                            } else {
                                // Already committed.
                                return null;
                            }
                        } else {
                            // Try next one_of.
                            self.pos = start_pos;
                        }
                    },
                }
            }
            return null;
        },
        .all_of => |all_ofs| {
            var result: ResultType = undefined;
            inline for (all_ofs) |all_of| {
                if (try self.parse(all_of.rule_name)) |field_result| {
                    if (all_of.field_name) |field_name| {
                        const field_result_ptr = try self.allocator.create(@field(types, all_of.rule_name));
                        field_result_ptr.* = field_result;
                        @field(result, field_name) = field_result_ptr;
                    }
                } else {
                    return null;
                }
            }
        },
        .optional => |optional| {
            if (try self.parse(optional.rule_name)) |optional_result| {
                return optional_result;
            } else {
                // This cast leads to returning Some(null) instead of null.
                return @as(ResultType, null);
            }
        },
        .repeat => |repeat| {
            var results = u.ArrayList(@field(types, repeat.element.rule_name)).init(self.allocator);
            while (true) {
                const start_pos = self.pos;
                if (repeat.element.separator) |separator| {
                    if (results.items.len > 0) {
                        if (try self.parse(separator.rule_name) == null) {
                            self.pos = start_pos;
                            break;
                        }
                    }
                }
                if (try self.parse(repeat.element.rule_name)) |result| {
                    try results.append(result);
                } else {
                    self.pos = start_pos;
                    break;
                }
            }
            return if (results.items.len >= repeat.min_count)
                results.toOwnedSlice()
            else
                null;
        },
    }
}
