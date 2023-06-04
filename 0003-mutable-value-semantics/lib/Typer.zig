const std = @import("std");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("./Parser.zig");
const NodeId = Parser.NodeId;

const Self = @This();
allocator: Allocator,
parser: Parser,
type_of: []?TypeId,
types: ArrayList(Type),
scope: Scope,
error_message: ?[]const u8,

pub const TypeId = usize;
pub const Type = union(enum) {
    any,
    unit,
    int,
    float,
    list: TypeId,
    @"struct": struct {
        name: []const u8,
        fields: []Field,
    },
    fun: struct {
        params: []Param,
        return_typ: TypeId,
    },
};
pub const Field = struct {
    mutability: Mutability,
    name: []const u8,
    typ: TypeId,
};
pub const Param = struct {
    mutability: Mutability,
    typ: TypeId,
};
pub const Mutability = Parser.Mutability;

pub const Scope = ArrayList(Binding);
pub const Binding = struct {
    name: []const u8,
    typ: TypeId,
};

pub fn init(allocator: Allocator, parser: Parser) Self {
    const type_of = allocator.alloc(?TypeId, parser.nodes.items.len) catch panic("OOM", .{});
    for (type_of) |*typ_id| typ_id.* = null;
    return Self{
        .allocator = allocator,
        .parser = parser,
        .type_of = type_of,
        .types = ArrayList(Type).init(allocator),
        .scope = Scope.init(allocator),
        .error_message = null,
    };
}

pub fn check(self: *Self) error{TypeError}!void {
    try self.checkDeclOrExpr(self.parser.nodes.items.len - 1);
}

fn checkDeclOrExpr(self: *Self, node_id: NodeId) error{TypeError}!void {
    const node = self.parser.nodes.items[node_id];
    switch (node) {
        .decl => |decl| {
            const fields = self.allocator.alloc(Field, decl.fields.len) catch panic("OOM", .{});
            for (fields, decl.fields) |*field, field_id| {
                const field_node = self.parser.nodes.items[field_id].field;
                field.* = .{
                    .mutability = field_node.mutability,
                    .name = field_node.name,
                    .typ = try self.checkType(field_node.typ),
                };
            }
            const typ_id = self.typ(node_id, .{.@"struct" = .{
                .name = decl.name,
            .fields = fields,
            }});
            self.scope.append(.{
                .name = decl.name,
                .typ = typ_id,
            }) catch panic("OOM", .{});
            try self.checkDeclOrExpr(decl.tail);
        },
        .expr => {
            _ = try self.checkExpr(node_id);
        },
        else => panic("Wrong node type {}", .{node}),
    }
}

fn checkTypesEqual(self: *Self, a_id: TypeId, b_id: NodeId) error{TypeError}!void {
    const a = self.types.items[a_id];
    const b = self.types.items[b_id];
    const a_tag = std.meta.activeTag(a);
    const b_tag = std.meta.activeTag(b);
    try self.assertEqual(a_tag, b_tag);
    switch (a_tag) {
        .any => {},
        .unit, .int, .float => {},
        .list => {
            try self.checkTypesEqual(a.list, b.list);
        },
        .@"struct" => {
            try self.assertEqual(a_id, b_id);
        },
        .fun => {
            for (a.fun.params, b.fun.params) |a_param, b_param| {
                try self.assertEqual(a_param.mutability, b_param.mutability);
                try self.checkTypesEqual(a_param.typ, b_param.typ);
            }
            try self.checkTypesEqual(a.fun.return_typ, b.fun.return_typ);
        }
    }
}


fn checkExpr(self: *Self, node_id: NodeId) error{TypeError}!TypeId {
    const typ_id = try self.checkExprInner(node_id);
    self.type_of[node_id] = typ_id;
    return typ_id;
}

fn checkExprInner(self: *Self, node_id: NodeId) error{TypeError}!TypeId {
    const node = self.parser.nodes.items[node_id].expr;
    switch (node) {
        .assign => |assign| {
            const path_typ = try self.checkExpr(assign.path);
            const value_typ = try self.checkExpr(assign.value);
            try self.checkTypesEqual(path_typ, value_typ);
            return self.checkExpr(assign.tail);
        },
        .seq => |exprs| {
            _ = try self.checkExpr(exprs[0]);
            return self.checkExpr(exprs[1]);
        },
        .call => |call| {
            const fun_typ = self.types.items[try self.checkExpr(call.fun)];
            try self.assertEqual(std.meta.activeTag(fun_typ), .fun);
            try self.assertEqual(fun_typ.fun.params.len, call.args.len);
            for (fun_typ.fun.params, call.mutabilities, call.args) |param, mut, arg| {
                try self.assertEqual(param.mutability, mut);
                const arg_typ = try self.checkExpr(arg);
                try self.checkTypesEqual(param.typ, arg_typ);
            }
            return fun_typ.fun.return_typ;
        },
        .op => |op| {
            const arg_typ0 = try self.checkExpr(op.args[0]);
            const arg_typ1 = try self.checkExpr(op.args[1]);
            try self.checkTypesEqual(arg_typ0, arg_typ1);
            switch (op.op) {
                .plus, .minus, .multiply, .divide => {
                    for (&[_]TypeId{arg_typ0, arg_typ1}) |arg_typ| {
                        switch (self.types.items[arg_typ]) {
                            .int, .float => {},
                            else => return self.fail("Expected number, found {}", .{arg_typ}),
                            }
                        }
                    return arg_typ0;
                    },
                .equals, .greater_than, .less_than => {
                    return self.typ(node_id, .int);                
                },
            }
        },
        else => panic("TODO", .{}),
    }
}
            
fn checkType(self: *Self, node_id: NodeId) error{TypeError}!TypeId {
    const node = self.parser.nodes.items[node_id].typ;
    return switch (node) {
        .any => self.typ(node_id, .any),
        .int => self.typ(node_id, .int),
        .float => self.typ(node_id, .float),
        .unit => self.typ(node_id, .unit),
        .list => |elem| self.typ(node_id, .{.list = try self.checkType(elem)}),
        .fun => |fun| self.typ(node_id, .{.fun = .{
            .params = try self.checkParams(fun.params),
            .return_typ = try self.checkType(fun.return_typ),
        }}),
        .identifier => |name| try self.lookup(name),
    };
}

fn checkParams(self: *Self, param_ids: []const NodeId) error{TypeError}![]Param {
    const params = self.allocator.alloc(Param, param_ids.len) catch panic("OOM", .{});
    for (params, param_ids) |*param, param_id| {
        const param_node = self.parser.nodes.items[param_id].param;
        param.* = .{
            .mutability = param_node.mutability,
            .typ = try self.checkType(param_node.typ),
        };
    }
    return params;
}

fn lookup(self: *Self, name: []const u8) error{TypeError}!TypeId {
    var i = self.scope.items.len - 1;
    while (i > 0) : (i -= 1) {
        const binding = self.scope.items[i];
        if (std.mem.eql(u8, name, binding.name)) return binding.typ;
    }
    return self.fail("Name not defined: {s}", .{name});
}

fn typ(self: *Self, node_id_o: ?NodeId, type_value: Type) TypeId {
    const id = self.types.items.len;
    self.types.append(type_value) catch panic("OOM", .{});
    if (node_id_o) |node_id| self.type_of[node_id] = id;
    return id;
}

fn fail(self: *Self, comptime message: []const u8, args: anytype) error{TypeError} {
    self.error_message = std.fmt.allocPrint(
        self.allocator,
        message,
        args,
    ) catch panic("OOM", .{});
    return error.TypeError;
}
    
    fn assertEqual(self: *Self, a: anytype, b: @TypeOf(a)) error{TypeError}!void {
        if (a != b) 
        return self.fail("Expected {}, found {}", .{a,b});
    }
