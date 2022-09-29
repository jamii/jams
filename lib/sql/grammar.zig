const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

pub const Rule = union(enum) {
    token: Token,
    one_of: []const OneOf,
    all_of: []const RuleRef,
    optional: RuleRef,
    repeat: Repeat,
};
pub const OneOf = sql.GrammarParser.OneOf;
pub const Repeat = sql.GrammarParser.Repeat;
pub const RuleRef = sql.GrammarParser.RuleRef;
pub const TokenAndRange = struct {
    token: Token,
    range: [2]usize,
};
pub const rules = struct {
    pub const anon_0 = Rule{ .optional = RuleRef{ .field_name = "semicolon", .rule_name = "semicolon" } };
    pub const sql = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "statement_or_query", .rule_name = "statement_or_query" },
        RuleRef{ .field_name = "semicolon", .rule_name = "anon_0" },
        RuleRef{ .field_name = "eof", .rule_name = "eof" },
    } };
    pub const statement_or_query = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "SELECT" }, RuleRef{ .field_name = "select", .rule_name = "select" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "VALUES" }, RuleRef{ .field_name = "values", .rule_name = "values" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "CREATE" }, RuleRef{ .field_name = "create", .rule_name = "create" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "INSERT" }, RuleRef{ .field_name = "insert", .rule_name = "insert" },
        } },
    } };
    pub const anon_3 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "CREATE" },
        RuleRef{ .field_name = null, .rule_name = "TABLE" },
    } };
    pub const create = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "anon_3" }, RuleRef{ .field_name = "create_table", .rule_name = "create_table" },
        } },
    } };
    pub const create_table = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "CREATE" },
        RuleRef{ .field_name = null, .rule_name = "TABLE" },
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "column_specs", .rule_name = "column_specs" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const insert = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "INSERT" },
        RuleRef{ .field_name = null, .rule_name = "INTO" },
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "column_specs", .rule_name = "column_specs" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
        RuleRef{ .field_name = "table_expr", .rule_name = "table_expr" },
    } };
    pub const table_expr = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "VALUES" }, RuleRef{ .field_name = "values", .rule_name = "values" },
        } },
    } };
    pub const values = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "VALUES" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const anon_9 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const exprs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "anon_9" },
    } };
    pub const expr = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "value", .rule_name = "value" } },
    } };
    pub const value = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "number", .rule_name = "number" } },
        .{ .choice = RuleRef{ .field_name = "string", .rule_name = "string" } },
    } };
    pub const anon_13 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "column_spec", .rule_name = "column_spec" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const column_specs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "column_spec", .rule_name = "anon_13" },
    } };
    pub const anon_15 = Rule{ .optional = RuleRef{ .field_name = "typ", .rule_name = "typ" } };
    pub const column_spec = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "typ", .rule_name = "anon_15" },
    } };
    pub const typ = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_18 = Rule{ .optional = RuleRef{ .field_name = "distinct_or_all", .rule_name = "distinct_or_all" } };
    pub const anon_19 = Rule{ .optional = RuleRef{ .field_name = "from", .rule_name = "from" } };
    pub const anon_20 = Rule{ .optional = RuleRef{ .field_name = "where", .rule_name = "where" } };
    pub const anon_21 = Rule{ .optional = RuleRef{ .field_name = "group_by", .rule_name = "group_by" } };
    pub const anon_22 = Rule{ .optional = RuleRef{ .field_name = "having", .rule_name = "having" } };
    pub const anon_23 = Rule{ .optional = RuleRef{ .field_name = "window", .rule_name = "window" } };
    pub const anon_24 = Rule{ .optional = RuleRef{ .field_name = "order_by", .rule_name = "order_by" } };
    pub const anon_25 = Rule{ .optional = RuleRef{ .field_name = "limit", .rule_name = "limit" } };
    pub const select = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "SELECT" },
        RuleRef{ .field_name = "distinct_or_all", .rule_name = "anon_18" },
        RuleRef{ .field_name = "result_columns", .rule_name = "result_columns" },
        RuleRef{ .field_name = "from", .rule_name = "anon_19" },
        RuleRef{ .field_name = "where", .rule_name = "anon_20" },
        RuleRef{ .field_name = "group_by", .rule_name = "anon_21" },
        RuleRef{ .field_name = "having", .rule_name = "anon_22" },
        RuleRef{ .field_name = "window", .rule_name = "anon_23" },
        RuleRef{ .field_name = "order_by", .rule_name = "anon_24" },
        RuleRef{ .field_name = "limit", .rule_name = "anon_25" },
    } };
    pub const distinct_or_all = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "DISTINCT" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "ALL" } },
    } };
    pub const anon_28 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "result_column", .rule_name = "result_column" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const results_columns = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "result_column", .rule_name = "anon_28" },
    } };
    pub const result_column = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_31 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "tables_or_subqueries_or_join" }, .separator = null } };
    pub const from = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "FROM" },
        RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "anon_31" },
    } };
    pub const table_or_subquery_or_join = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "tables_or_subqueries", .rule_name = "tables_or_subqueries" } },
        .{ .choice = RuleRef{ .field_name = "join_clause", .rule_name = "join_clause" } },
    } };
    pub const anon_34 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "table_or_subquery", .rule_name = "table_or_subquery" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const tables_or_subqueries = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_or_subquery", .rule_name = "anon_34" },
    } };
    pub const table_or_subquery = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "TODO" },
    } };
    pub const where = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "WHERE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const group_by = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "GROUP" },
        RuleRef{ .field_name = null, .rule_name = "BY" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
    } };
    pub const having = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "HAVING" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const window = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "WINDOW" },
        RuleRef{ .field_name = null, .rule_name = "TODO" },
    } };
    pub const order_by = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "ORDER" },
        RuleRef{ .field_name = null, .rule_name = "BY" },
        RuleRef{ .field_name = "ordering_term", .rule_name = "ordering_term" },
    } };
    pub const ordering_term = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const limit = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "LIMIT" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
    } };
    pub const tokens = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "less_than", .rule_name = "less_than" } },
        .{ .choice = RuleRef{ .field_name = "greater_than", .rule_name = "greater_than" } },
        .{ .choice = RuleRef{ .field_name = "less_than_or_equal", .rule_name = "less_than_or_equal" } },
        .{ .choice = RuleRef{ .field_name = "greater_than_or_equal", .rule_name = "greater_than_or_equal" } },
        .{ .choice = RuleRef{ .field_name = "not_less_than", .rule_name = "not_less_than" } },
        .{ .choice = RuleRef{ .field_name = "not_greater_than", .rule_name = "not_greater_than" } },
        .{ .choice = RuleRef{ .field_name = "equal", .rule_name = "equal" } },
        .{ .choice = RuleRef{ .field_name = "double_equal", .rule_name = "double_equal" } },
        .{ .choice = RuleRef{ .field_name = "not_equal", .rule_name = "not_equal" } },
        .{ .choice = RuleRef{ .field_name = "plus", .rule_name = "plus" } },
        .{ .choice = RuleRef{ .field_name = "minus", .rule_name = "minus" } },
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
        .{ .choice = RuleRef{ .field_name = "forward_slash", .rule_name = "forward_slash" } },
        .{ .choice = RuleRef{ .field_name = "dot", .rule_name = "dot" } },
        .{ .choice = RuleRef{ .field_name = "modulus", .rule_name = "modulus" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_and", .rule_name = "bitwise_and" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_or", .rule_name = "bitwise_or" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_not", .rule_name = "bitwise_not" } },
        .{ .choice = RuleRef{ .field_name = "string_concat", .rule_name = "string_concat" } },
        .{ .choice = RuleRef{ .field_name = "shift_left", .rule_name = "shift_left" } },
        .{ .choice = RuleRef{ .field_name = "shift_right", .rule_name = "shift_right" } },
    } };
    pub const FROM = Rule{ .token = .FROM };
    pub const string = Rule{ .token = .string };
    pub const not_greater_than = Rule{ .token = .not_greater_than };
    pub const DO = Rule{ .token = .DO };
    pub const INSTEAD = Rule{ .token = .INSTEAD };
    pub const TEMPORARY = Rule{ .token = .TEMPORARY };
    pub const DELETE = Rule{ .token = .DELETE };
    pub const DISTINCT = Rule{ .token = .DISTINCT };
    pub const WINDOW = Rule{ .token = .WINDOW };
    pub const NATURAL = Rule{ .token = .NATURAL };
    pub const BY = Rule{ .token = .BY };
    pub const COLLATE = Rule{ .token = .COLLATE };
    pub const IF = Rule{ .token = .IF };
    pub const DEFERRED = Rule{ .token = .DEFERRED };
    pub const WHERE = Rule{ .token = .WHERE };
    pub const modulus = Rule{ .token = .modulus };
    pub const ATTACH = Rule{ .token = .ATTACH };
    pub const GLOB = Rule{ .token = .GLOB };
    pub const NOT = Rule{ .token = .NOT };
    pub const bitwise_not = Rule{ .token = .bitwise_not };
    pub const PRAGMA = Rule{ .token = .PRAGMA };
    pub const WITH = Rule{ .token = .WITH };
    pub const FILTER = Rule{ .token = .FILTER };
    pub const THEN = Rule{ .token = .THEN };
    pub const tables_or_subqueries_or_join = Rule{ .token = .tables_or_subqueries_or_join };
    pub const UNBOUNDED = Rule{ .token = .UNBOUNDED };
    pub const FOR = Rule{ .token = .FOR };
    pub const join_clause = Rule{ .token = .join_clause };
    pub const shift_left = Rule{ .token = .shift_left };
    pub const EXISTS = Rule{ .token = .EXISTS };
    pub const AND = Rule{ .token = .AND };
    pub const double_equal = Rule{ .token = .double_equal };
    pub const BETWEEN = Rule{ .token = .BETWEEN };
    pub const INSERT = Rule{ .token = .INSERT };
    pub const CASCADE = Rule{ .token = .CASCADE };
    pub const INITIALLY = Rule{ .token = .INITIALLY };
    pub const RECURSIVE = Rule{ .token = .RECURSIVE };
    pub const REPLACE = Rule{ .token = .REPLACE };
    pub const CREATE = Rule{ .token = .CREATE };
    pub const open_paren = Rule{ .token = .open_paren };
    pub const UNIQUE = Rule{ .token = .UNIQUE };
    pub const greater_than = Rule{ .token = .greater_than };
    pub const NOTHING = Rule{ .token = .NOTHING };
    pub const OF = Rule{ .token = .OF };
    pub const RESTRICT = Rule{ .token = .RESTRICT };
    pub const semicolon = Rule{ .token = .semicolon };
    pub const WHEN = Rule{ .token = .WHEN };
    pub const DEFERRABLE = Rule{ .token = .DEFERRABLE };
    pub const NULLS = Rule{ .token = .NULLS };
    pub const ON = Rule{ .token = .ON };
    pub const close_paren = Rule{ .token = .close_paren };
    pub const EXPLAIN = Rule{ .token = .EXPLAIN };
    pub const INTERSECT = Rule{ .token = .INTERSECT };
    pub const FULL = Rule{ .token = .FULL };
    pub const PLAN = Rule{ .token = .PLAN };
    pub const PRIMARY = Rule{ .token = .PRIMARY };
    pub const name = Rule{ .token = .name };
    pub const EACH = Rule{ .token = .EACH };
    pub const OFFSET = Rule{ .token = .OFFSET };
    pub const ROLLBACK = Rule{ .token = .ROLLBACK };
    pub const shift_right = Rule{ .token = .shift_right };
    pub const SET = Rule{ .token = .SET };
    pub const TRANSACTION = Rule{ .token = .TRANSACTION };
    pub const bitwise_and = Rule{ .token = .bitwise_and };
    pub const COMMIT = Rule{ .token = .COMMIT };
    pub const VALUES = Rule{ .token = .VALUES };
    pub const EXCLUSIVE = Rule{ .token = .EXCLUSIVE };
    pub const ALL = Rule{ .token = .ALL };
    pub const ADD = Rule{ .token = .ADD };
    pub const ACTION = Rule{ .token = .ACTION };
    pub const dot = Rule{ .token = .dot };
    pub const AFTER = Rule{ .token = .AFTER };
    pub const CONFLICT = Rule{ .token = .CONFLICT };
    pub const DEFAULT = Rule{ .token = .DEFAULT };
    pub const INNER = Rule{ .token = .INNER };
    pub const IS = Rule{ .token = .IS };
    pub const IMMEDIATE = Rule{ .token = .IMMEDIATE };
    pub const SAVEPOINT = Rule{ .token = .SAVEPOINT };
    pub const FOLLOWING = Rule{ .token = .FOLLOWING };
    pub const RAISE = Rule{ .token = .RAISE };
    pub const HAVING = Rule{ .token = .HAVING };
    pub const TEMP = Rule{ .token = .TEMP };
    pub const less_than = Rule{ .token = .less_than };
    pub const CHECK = Rule{ .token = .CHECK };
    pub const RETURNING = Rule{ .token = .RETURNING };
    pub const INDEX = Rule{ .token = .INDEX };
    pub const CONSTRAINT = Rule{ .token = .CONSTRAINT };
    pub const CURRENT_TIME = Rule{ .token = .CURRENT_TIME };
    pub const ISNULL = Rule{ .token = .ISNULL };
    pub const ROW = Rule{ .token = .ROW };
    pub const plus = Rule{ .token = .plus };
    pub const FAIL = Rule{ .token = .FAIL };
    pub const USING = Rule{ .token = .USING };
    pub const NOTNULL = Rule{ .token = .NOTNULL };
    pub const CAST = Rule{ .token = .CAST };
    pub const AS = Rule{ .token = .AS };
    pub const SELECT = Rule{ .token = .SELECT };
    pub const COLUMN = Rule{ .token = .COLUMN };
    pub const END = Rule{ .token = .END };
    pub const IN = Rule{ .token = .IN };
    pub const INDEXED = Rule{ .token = .INDEXED };
    pub const LEFT = Rule{ .token = .LEFT };
    pub const QUERY = Rule{ .token = .QUERY };
    pub const BEFORE = Rule{ .token = .BEFORE };
    pub const equal = Rule{ .token = .equal };
    pub const OTHERS = Rule{ .token = .OTHERS };
    pub const REFERENCES = Rule{ .token = .REFERENCES };
    pub const ORDER = Rule{ .token = .ORDER };
    pub const ROWS = Rule{ .token = .ROWS };
    pub const comma = Rule{ .token = .comma };
    pub const TIES = Rule{ .token = .TIES };
    pub const LIMIT = Rule{ .token = .LIMIT };
    pub const bitwise_or = Rule{ .token = .bitwise_or };
    pub const ABORT = Rule{ .token = .ABORT };
    pub const DETACH = Rule{ .token = .DETACH };
    pub const DROP = Rule{ .token = .DROP };
    pub const LAST = Rule{ .token = .LAST };
    pub const not_equal = Rule{ .token = .not_equal };
    pub const INTO = Rule{ .token = .INTO };
    pub const CURRENT_TIMESTAMP = Rule{ .token = .CURRENT_TIMESTAMP };
    pub const PRECEDING = Rule{ .token = .PRECEDING };
    pub const RANGE = Rule{ .token = .RANGE };
    pub const result_columns = Rule{ .token = .result_columns };
    pub const MATERIALIZED = Rule{ .token = .MATERIALIZED };
    pub const GENERATED = Rule{ .token = .GENERATED };
    pub const string_concat = Rule{ .token = .string_concat };
    pub const OUTER = Rule{ .token = .OUTER };
    pub const AUTOINCREMENT = Rule{ .token = .AUTOINCREMENT };
    pub const CROSS = Rule{ .token = .CROSS };
    pub const CURRENT_DATE = Rule{ .token = .CURRENT_DATE };
    pub const BEGIN = Rule{ .token = .BEGIN };
    pub const ASC = Rule{ .token = .ASC };
    pub const EXCEPT = Rule{ .token = .EXCEPT };
    pub const OR = Rule{ .token = .OR };
    pub const REGEXP = Rule{ .token = .REGEXP };
    pub const RIGHT = Rule{ .token = .RIGHT };
    pub const TRIGGER = Rule{ .token = .TRIGGER };
    pub const EXCLUDE = Rule{ .token = .EXCLUDE };
    pub const UPDATE = Rule{ .token = .UPDATE };
    pub const ESCAPE = Rule{ .token = .ESCAPE };
    pub const RELEASE = Rule{ .token = .RELEASE };
    pub const LIKE = Rule{ .token = .LIKE };
    pub const FIRST = Rule{ .token = .FIRST };
    pub const minus = Rule{ .token = .minus };
    pub const TODO = Rule{ .token = .TODO };
    pub const eof = Rule{ .token = .eof };
    pub const WITHOUT = Rule{ .token = .WITHOUT };
    pub const GROUPS = Rule{ .token = .GROUPS };
    pub const number = Rule{ .token = .number };
    pub const GROUP = Rule{ .token = .GROUP };
    pub const CURRENT = Rule{ .token = .CURRENT };
    pub const FOREIGN = Rule{ .token = .FOREIGN };
    pub const KEY = Rule{ .token = .KEY };
    pub const DATABASE = Rule{ .token = .DATABASE };
    pub const REINDEX = Rule{ .token = .REINDEX };
    pub const UNION = Rule{ .token = .UNION };
    pub const not_less_than = Rule{ .token = .not_less_than };
    pub const OVER = Rule{ .token = .OVER };
    pub const RENAME = Rule{ .token = .RENAME };
    pub const PARTITION = Rule{ .token = .PARTITION };
    pub const forward_slash = Rule{ .token = .forward_slash };
    pub const ANALYZE = Rule{ .token = .ANALYZE };
    pub const VACUUM = Rule{ .token = .VACUUM };
    pub const DESC = Rule{ .token = .DESC };
    pub const VIRTUAL = Rule{ .token = .VIRTUAL };
    pub const JOIN = Rule{ .token = .JOIN };
    pub const NULL = Rule{ .token = .NULL };
    pub const ALWAYS = Rule{ .token = .ALWAYS };
    pub const TO = Rule{ .token = .TO };
    pub const star = Rule{ .token = .star };
    pub const MATCH = Rule{ .token = .MATCH };
    pub const ELSE = Rule{ .token = .ELSE };
    pub const greater_than_or_equal = Rule{ .token = .greater_than_or_equal };
    pub const VIEW = Rule{ .token = .VIEW };
    pub const CASE = Rule{ .token = .CASE };
    pub const ALTER = Rule{ .token = .ALTER };
    pub const IGNORE = Rule{ .token = .IGNORE };
    pub const TABLE = Rule{ .token = .TABLE };
    pub const less_than_or_equal = Rule{ .token = .less_than_or_equal };
    pub const NO = Rule{ .token = .NO };
};

pub const types = struct {
    pub const anon_0 = ?semicolon;
    pub const sql = struct {
        statement_or_query: *statement_or_query,
        semicolon: *anon_0,
        eof: *eof,
    };
    pub const statement_or_query = union(enum) {
        select: select,
        values: values,
        create: create,
        insert: insert,
    };
    pub const anon_3 = struct {};
    pub const create = union(enum) {
        create_table: create_table,
    };
    pub const create_table = struct {
        name: *name,
        open_paren: *open_paren,
        column_specs: *column_specs,
        close_paren: *close_paren,
    };
    pub const insert = struct {
        name: *name,
        open_paren: *open_paren,
        column_specs: *column_specs,
        close_paren: *close_paren,
        table_expr: *table_expr,
    };
    pub const table_expr = union(enum) {
        values: values,
    };
    pub const values = struct {
        open_paren: *open_paren,
        exprs: *exprs,
        close_paren: *close_paren,
    };
    pub const anon_9 = []const expr;
    pub const exprs = struct {
        expr: *anon_9,
    };
    pub const expr = union(enum) {
        value: value,
    };
    pub const value = union(enum) {
        number: number,
        string: string,
    };
    pub const anon_13 = []const column_spec;
    pub const column_specs = struct {
        column_spec: *anon_13,
    };
    pub const anon_15 = ?typ;
    pub const column_spec = struct {
        name: *name,
        typ: *anon_15,
    };
    pub const typ = struct {
        name: *name,
    };
    pub const anon_18 = ?distinct_or_all;
    pub const anon_19 = ?from;
    pub const anon_20 = ?where;
    pub const anon_21 = ?group_by;
    pub const anon_22 = ?having;
    pub const anon_23 = ?window;
    pub const anon_24 = ?order_by;
    pub const anon_25 = ?limit;
    pub const select = struct {
        distinct_or_all: *anon_18,
        result_columns: *result_columns,
        from: *anon_19,
        where: *anon_20,
        group_by: *anon_21,
        having: *anon_22,
        window: *anon_23,
        order_by: *anon_24,
        limit: *anon_25,
    };
    pub const distinct_or_all = enum {
        DISTINCT,
        ALL,
    };
    pub const anon_28 = []const result_column;
    pub const results_columns = struct {
        result_column: *anon_28,
    };
    pub const result_column = struct {
        expr: *expr,
    };
    pub const anon_31 = []const tables_or_subqueries_or_join;
    pub const from = struct {
        tables_or_subqueries_or_join: *anon_31,
    };
    pub const table_or_subquery_or_join = union(enum) {
        tables_or_subqueries: tables_or_subqueries,
        join_clause: join_clause,
    };
    pub const anon_34 = []const table_or_subquery;
    pub const tables_or_subqueries = struct {
        table_or_subquery: *anon_34,
    };
    pub const table_or_subquery = struct {};
    pub const where = struct {
        expr: *expr,
    };
    pub const group_by = struct {
        exprs: *exprs,
    };
    pub const having = struct {
        expr: *expr,
    };
    pub const window = struct {};
    pub const order_by = struct {
        ordering_term: *ordering_term,
    };
    pub const ordering_term = struct {
        expr: *expr,
    };
    pub const limit = struct {
        exprs: *exprs,
    };
    pub const tokens = union(enum) {
        less_than: less_than,
        greater_than: greater_than,
        less_than_or_equal: less_than_or_equal,
        greater_than_or_equal: greater_than_or_equal,
        not_less_than: not_less_than,
        not_greater_than: not_greater_than,
        equal: equal,
        double_equal: double_equal,
        not_equal: not_equal,
        plus: plus,
        minus: minus,
        star: star,
        forward_slash: forward_slash,
        dot: dot,
        modulus: modulus,
        bitwise_and: bitwise_and,
        bitwise_or: bitwise_or,
        bitwise_not: bitwise_not,
        string_concat: string_concat,
        shift_left: shift_left,
        shift_right: shift_right,
    };
    pub const FROM = TokenAndRange;
    pub const string = TokenAndRange;
    pub const not_greater_than = TokenAndRange;
    pub const DO = TokenAndRange;
    pub const INSTEAD = TokenAndRange;
    pub const TEMPORARY = TokenAndRange;
    pub const DELETE = TokenAndRange;
    pub const DISTINCT = TokenAndRange;
    pub const WINDOW = TokenAndRange;
    pub const NATURAL = TokenAndRange;
    pub const BY = TokenAndRange;
    pub const COLLATE = TokenAndRange;
    pub const IF = TokenAndRange;
    pub const DEFERRED = TokenAndRange;
    pub const WHERE = TokenAndRange;
    pub const modulus = TokenAndRange;
    pub const ATTACH = TokenAndRange;
    pub const GLOB = TokenAndRange;
    pub const NOT = TokenAndRange;
    pub const bitwise_not = TokenAndRange;
    pub const PRAGMA = TokenAndRange;
    pub const WITH = TokenAndRange;
    pub const FILTER = TokenAndRange;
    pub const THEN = TokenAndRange;
    pub const tables_or_subqueries_or_join = TokenAndRange;
    pub const UNBOUNDED = TokenAndRange;
    pub const FOR = TokenAndRange;
    pub const join_clause = TokenAndRange;
    pub const shift_left = TokenAndRange;
    pub const EXISTS = TokenAndRange;
    pub const AND = TokenAndRange;
    pub const double_equal = TokenAndRange;
    pub const BETWEEN = TokenAndRange;
    pub const INSERT = TokenAndRange;
    pub const CASCADE = TokenAndRange;
    pub const INITIALLY = TokenAndRange;
    pub const RECURSIVE = TokenAndRange;
    pub const REPLACE = TokenAndRange;
    pub const CREATE = TokenAndRange;
    pub const open_paren = TokenAndRange;
    pub const UNIQUE = TokenAndRange;
    pub const greater_than = TokenAndRange;
    pub const NOTHING = TokenAndRange;
    pub const OF = TokenAndRange;
    pub const RESTRICT = TokenAndRange;
    pub const semicolon = TokenAndRange;
    pub const WHEN = TokenAndRange;
    pub const DEFERRABLE = TokenAndRange;
    pub const NULLS = TokenAndRange;
    pub const ON = TokenAndRange;
    pub const close_paren = TokenAndRange;
    pub const EXPLAIN = TokenAndRange;
    pub const INTERSECT = TokenAndRange;
    pub const FULL = TokenAndRange;
    pub const PLAN = TokenAndRange;
    pub const PRIMARY = TokenAndRange;
    pub const name = TokenAndRange;
    pub const EACH = TokenAndRange;
    pub const OFFSET = TokenAndRange;
    pub const ROLLBACK = TokenAndRange;
    pub const shift_right = TokenAndRange;
    pub const SET = TokenAndRange;
    pub const TRANSACTION = TokenAndRange;
    pub const bitwise_and = TokenAndRange;
    pub const COMMIT = TokenAndRange;
    pub const VALUES = TokenAndRange;
    pub const EXCLUSIVE = TokenAndRange;
    pub const ALL = TokenAndRange;
    pub const ADD = TokenAndRange;
    pub const ACTION = TokenAndRange;
    pub const dot = TokenAndRange;
    pub const AFTER = TokenAndRange;
    pub const CONFLICT = TokenAndRange;
    pub const DEFAULT = TokenAndRange;
    pub const INNER = TokenAndRange;
    pub const IS = TokenAndRange;
    pub const IMMEDIATE = TokenAndRange;
    pub const SAVEPOINT = TokenAndRange;
    pub const FOLLOWING = TokenAndRange;
    pub const RAISE = TokenAndRange;
    pub const HAVING = TokenAndRange;
    pub const TEMP = TokenAndRange;
    pub const less_than = TokenAndRange;
    pub const CHECK = TokenAndRange;
    pub const RETURNING = TokenAndRange;
    pub const INDEX = TokenAndRange;
    pub const CONSTRAINT = TokenAndRange;
    pub const CURRENT_TIME = TokenAndRange;
    pub const ISNULL = TokenAndRange;
    pub const ROW = TokenAndRange;
    pub const plus = TokenAndRange;
    pub const FAIL = TokenAndRange;
    pub const USING = TokenAndRange;
    pub const NOTNULL = TokenAndRange;
    pub const CAST = TokenAndRange;
    pub const AS = TokenAndRange;
    pub const SELECT = TokenAndRange;
    pub const COLUMN = TokenAndRange;
    pub const END = TokenAndRange;
    pub const IN = TokenAndRange;
    pub const INDEXED = TokenAndRange;
    pub const LEFT = TokenAndRange;
    pub const QUERY = TokenAndRange;
    pub const BEFORE = TokenAndRange;
    pub const equal = TokenAndRange;
    pub const OTHERS = TokenAndRange;
    pub const REFERENCES = TokenAndRange;
    pub const ORDER = TokenAndRange;
    pub const ROWS = TokenAndRange;
    pub const comma = TokenAndRange;
    pub const TIES = TokenAndRange;
    pub const LIMIT = TokenAndRange;
    pub const bitwise_or = TokenAndRange;
    pub const ABORT = TokenAndRange;
    pub const DETACH = TokenAndRange;
    pub const DROP = TokenAndRange;
    pub const LAST = TokenAndRange;
    pub const not_equal = TokenAndRange;
    pub const INTO = TokenAndRange;
    pub const CURRENT_TIMESTAMP = TokenAndRange;
    pub const PRECEDING = TokenAndRange;
    pub const RANGE = TokenAndRange;
    pub const result_columns = TokenAndRange;
    pub const MATERIALIZED = TokenAndRange;
    pub const GENERATED = TokenAndRange;
    pub const string_concat = TokenAndRange;
    pub const OUTER = TokenAndRange;
    pub const AUTOINCREMENT = TokenAndRange;
    pub const CROSS = TokenAndRange;
    pub const CURRENT_DATE = TokenAndRange;
    pub const BEGIN = TokenAndRange;
    pub const ASC = TokenAndRange;
    pub const EXCEPT = TokenAndRange;
    pub const OR = TokenAndRange;
    pub const REGEXP = TokenAndRange;
    pub const RIGHT = TokenAndRange;
    pub const TRIGGER = TokenAndRange;
    pub const EXCLUDE = TokenAndRange;
    pub const UPDATE = TokenAndRange;
    pub const ESCAPE = TokenAndRange;
    pub const RELEASE = TokenAndRange;
    pub const LIKE = TokenAndRange;
    pub const FIRST = TokenAndRange;
    pub const minus = TokenAndRange;
    pub const TODO = TokenAndRange;
    pub const eof = TokenAndRange;
    pub const WITHOUT = TokenAndRange;
    pub const GROUPS = TokenAndRange;
    pub const number = TokenAndRange;
    pub const GROUP = TokenAndRange;
    pub const CURRENT = TokenAndRange;
    pub const FOREIGN = TokenAndRange;
    pub const KEY = TokenAndRange;
    pub const DATABASE = TokenAndRange;
    pub const REINDEX = TokenAndRange;
    pub const UNION = TokenAndRange;
    pub const not_less_than = TokenAndRange;
    pub const OVER = TokenAndRange;
    pub const RENAME = TokenAndRange;
    pub const PARTITION = TokenAndRange;
    pub const forward_slash = TokenAndRange;
    pub const ANALYZE = TokenAndRange;
    pub const VACUUM = TokenAndRange;
    pub const DESC = TokenAndRange;
    pub const VIRTUAL = TokenAndRange;
    pub const JOIN = TokenAndRange;
    pub const NULL = TokenAndRange;
    pub const ALWAYS = TokenAndRange;
    pub const TO = TokenAndRange;
    pub const star = TokenAndRange;
    pub const MATCH = TokenAndRange;
    pub const ELSE = TokenAndRange;
    pub const greater_than_or_equal = TokenAndRange;
    pub const VIEW = TokenAndRange;
    pub const CASE = TokenAndRange;
    pub const ALTER = TokenAndRange;
    pub const IGNORE = TokenAndRange;
    pub const TABLE = TokenAndRange;
    pub const less_than_or_equal = TokenAndRange;
    pub const NO = TokenAndRange;
};

pub const Token = enum {
    FROM,
    string,
    not_greater_than,
    DO,
    INSTEAD,
    TEMPORARY,
    DELETE,
    DISTINCT,
    WINDOW,
    NATURAL,
    BY,
    COLLATE,
    IF,
    DEFERRED,
    WHERE,
    modulus,
    ATTACH,
    GLOB,
    NOT,
    bitwise_not,
    PRAGMA,
    WITH,
    FILTER,
    THEN,
    tables_or_subqueries_or_join,
    UNBOUNDED,
    FOR,
    join_clause,
    shift_left,
    EXISTS,
    AND,
    double_equal,
    BETWEEN,
    INSERT,
    CASCADE,
    INITIALLY,
    RECURSIVE,
    REPLACE,
    CREATE,
    open_paren,
    UNIQUE,
    greater_than,
    NOTHING,
    OF,
    RESTRICT,
    semicolon,
    WHEN,
    DEFERRABLE,
    NULLS,
    ON,
    close_paren,
    EXPLAIN,
    INTERSECT,
    FULL,
    PLAN,
    PRIMARY,
    name,
    EACH,
    OFFSET,
    ROLLBACK,
    shift_right,
    SET,
    TRANSACTION,
    bitwise_and,
    COMMIT,
    VALUES,
    EXCLUSIVE,
    ALL,
    ADD,
    ACTION,
    dot,
    AFTER,
    CONFLICT,
    DEFAULT,
    INNER,
    IS,
    IMMEDIATE,
    SAVEPOINT,
    FOLLOWING,
    RAISE,
    HAVING,
    TEMP,
    less_than,
    CHECK,
    RETURNING,
    INDEX,
    CONSTRAINT,
    CURRENT_TIME,
    ISNULL,
    ROW,
    plus,
    FAIL,
    USING,
    NOTNULL,
    CAST,
    AS,
    SELECT,
    COLUMN,
    END,
    IN,
    INDEXED,
    LEFT,
    QUERY,
    BEFORE,
    equal,
    OTHERS,
    REFERENCES,
    ORDER,
    ROWS,
    comma,
    TIES,
    LIMIT,
    bitwise_or,
    ABORT,
    DETACH,
    DROP,
    LAST,
    not_equal,
    INTO,
    CURRENT_TIMESTAMP,
    PRECEDING,
    RANGE,
    result_columns,
    MATERIALIZED,
    GENERATED,
    string_concat,
    OUTER,
    AUTOINCREMENT,
    CROSS,
    CURRENT_DATE,
    BEGIN,
    ASC,
    EXCEPT,
    OR,
    REGEXP,
    RIGHT,
    TRIGGER,
    EXCLUDE,
    UPDATE,
    ESCAPE,
    RELEASE,
    LIKE,
    FIRST,
    minus,
    TODO,
    eof,
    WITHOUT,
    GROUPS,
    number,
    GROUP,
    CURRENT,
    FOREIGN,
    KEY,
    DATABASE,
    REINDEX,
    UNION,
    not_less_than,
    OVER,
    RENAME,
    PARTITION,
    forward_slash,
    ANALYZE,
    VACUUM,
    DESC,
    VIRTUAL,
    JOIN,
    NULL,
    ALWAYS,
    TO,
    star,
    MATCH,
    ELSE,
    greater_than_or_equal,
    VIEW,
    CASE,
    ALTER,
    IGNORE,
    TABLE,
    less_than_or_equal,
    NO,
};

pub const keywords = keywords: {
    @setEvalBranchQuota(10000);
    break :keywords std.ComptimeStringMap(Token, .{
        .{ "ABORT", Token.ABORT },
        .{ "ACTION", Token.ACTION },
        .{ "ADD", Token.ADD },
        .{ "AFTER", Token.AFTER },
        .{ "ALL", Token.ALL },
        .{ "ALTER", Token.ALTER },
        .{ "ALWAYS", Token.ALWAYS },
        .{ "ANALYZE", Token.ANALYZE },
        .{ "AND", Token.AND },
        .{ "AS", Token.AS },
        .{ "ASC", Token.ASC },
        .{ "ATTACH", Token.ATTACH },
        .{ "AUTOINCREMENT", Token.AUTOINCREMENT },
        .{ "BEFORE", Token.BEFORE },
        .{ "BEGIN", Token.BEGIN },
        .{ "BETWEEN", Token.BETWEEN },
        .{ "BY", Token.BY },
        .{ "CASCADE", Token.CASCADE },
        .{ "CASE", Token.CASE },
        .{ "CAST", Token.CAST },
        .{ "CHECK", Token.CHECK },
        .{ "COLLATE", Token.COLLATE },
        .{ "COLUMN", Token.COLUMN },
        .{ "COMMIT", Token.COMMIT },
        .{ "CONFLICT", Token.CONFLICT },
        .{ "CONSTRAINT", Token.CONSTRAINT },
        .{ "CREATE", Token.CREATE },
        .{ "CROSS", Token.CROSS },
        .{ "CURRENT", Token.CURRENT },
        .{ "CURRENT_DATE", Token.CURRENT_DATE },
        .{ "CURRENT_TIME", Token.CURRENT_TIME },
        .{ "CURRENT_TIMESTAMP", Token.CURRENT_TIMESTAMP },
        .{ "DATABASE", Token.DATABASE },
        .{ "DEFAULT", Token.DEFAULT },
        .{ "DEFERRABLE", Token.DEFERRABLE },
        .{ "DEFERRED", Token.DEFERRED },
        .{ "DELETE", Token.DELETE },
        .{ "DESC", Token.DESC },
        .{ "DETACH", Token.DETACH },
        .{ "DISTINCT", Token.DISTINCT },
        .{ "DO", Token.DO },
        .{ "DROP", Token.DROP },
        .{ "EACH", Token.EACH },
        .{ "ELSE", Token.ELSE },
        .{ "END", Token.END },
        .{ "ESCAPE", Token.ESCAPE },
        .{ "EXCEPT", Token.EXCEPT },
        .{ "EXCLUDE", Token.EXCLUDE },
        .{ "EXCLUSIVE", Token.EXCLUSIVE },
        .{ "EXISTS", Token.EXISTS },
        .{ "EXPLAIN", Token.EXPLAIN },
        .{ "FAIL", Token.FAIL },
        .{ "FILTER", Token.FILTER },
        .{ "FIRST", Token.FIRST },
        .{ "FOLLOWING", Token.FOLLOWING },
        .{ "FOR", Token.FOR },
        .{ "FOREIGN", Token.FOREIGN },
        .{ "FROM", Token.FROM },
        .{ "FULL", Token.FULL },
        .{ "GENERATED", Token.GENERATED },
        .{ "GLOB", Token.GLOB },
        .{ "GROUP", Token.GROUP },
        .{ "GROUPS", Token.GROUPS },
        .{ "HAVING", Token.HAVING },
        .{ "IF", Token.IF },
        .{ "IGNORE", Token.IGNORE },
        .{ "IMMEDIATE", Token.IMMEDIATE },
        .{ "IN", Token.IN },
        .{ "INDEX", Token.INDEX },
        .{ "INDEXED", Token.INDEXED },
        .{ "INITIALLY", Token.INITIALLY },
        .{ "INNER", Token.INNER },
        .{ "INSERT", Token.INSERT },
        .{ "INSTEAD", Token.INSTEAD },
        .{ "INTERSECT", Token.INTERSECT },
        .{ "INTO", Token.INTO },
        .{ "IS", Token.IS },
        .{ "ISNULL", Token.ISNULL },
        .{ "JOIN", Token.JOIN },
        .{ "KEY", Token.KEY },
        .{ "LAST", Token.LAST },
        .{ "LEFT", Token.LEFT },
        .{ "LIKE", Token.LIKE },
        .{ "LIMIT", Token.LIMIT },
        .{ "MATCH", Token.MATCH },
        .{ "MATERIALIZED", Token.MATERIALIZED },
        .{ "NATURAL", Token.NATURAL },
        .{ "NO", Token.NO },
        .{ "NOT", Token.NOT },
        .{ "NOTHING", Token.NOTHING },
        .{ "NOTNULL", Token.NOTNULL },
        .{ "NULL", Token.NULL },
        .{ "NULLS", Token.NULLS },
        .{ "OF", Token.OF },
        .{ "OFFSET", Token.OFFSET },
        .{ "ON", Token.ON },
        .{ "OR", Token.OR },
        .{ "ORDER", Token.ORDER },
        .{ "OTHERS", Token.OTHERS },
        .{ "OUTER", Token.OUTER },
        .{ "OVER", Token.OVER },
        .{ "PARTITION", Token.PARTITION },
        .{ "PLAN", Token.PLAN },
        .{ "PRAGMA", Token.PRAGMA },
        .{ "PRECEDING", Token.PRECEDING },
        .{ "PRIMARY", Token.PRIMARY },
        .{ "QUERY", Token.QUERY },
        .{ "RAISE", Token.RAISE },
        .{ "RANGE", Token.RANGE },
        .{ "RECURSIVE", Token.RECURSIVE },
        .{ "REFERENCES", Token.REFERENCES },
        .{ "REGEXP", Token.REGEXP },
        .{ "REINDEX", Token.REINDEX },
        .{ "RELEASE", Token.RELEASE },
        .{ "RENAME", Token.RENAME },
        .{ "REPLACE", Token.REPLACE },
        .{ "RESTRICT", Token.RESTRICT },
        .{ "RETURNING", Token.RETURNING },
        .{ "RIGHT", Token.RIGHT },
        .{ "ROLLBACK", Token.ROLLBACK },
        .{ "ROW", Token.ROW },
        .{ "ROWS", Token.ROWS },
        .{ "SAVEPOINT", Token.SAVEPOINT },
        .{ "SELECT", Token.SELECT },
        .{ "SET", Token.SET },
        .{ "TABLE", Token.TABLE },
        .{ "TEMP", Token.TEMP },
        .{ "TEMPORARY", Token.TEMPORARY },
        .{ "THEN", Token.THEN },
        .{ "TIES", Token.TIES },
        .{ "TO", Token.TO },
        .{ "TRANSACTION", Token.TRANSACTION },
        .{ "TRIGGER", Token.TRIGGER },
        .{ "UNBOUNDED", Token.UNBOUNDED },
        .{ "UNION", Token.UNION },
        .{ "UNIQUE", Token.UNIQUE },
        .{ "UPDATE", Token.UPDATE },
        .{ "USING", Token.USING },
        .{ "VACUUM", Token.VACUUM },
        .{ "VALUES", Token.VALUES },
        .{ "VIEW", Token.VIEW },
        .{ "VIRTUAL", Token.VIRTUAL },
        .{ "WHEN", Token.WHEN },
        .{ "WHERE", Token.WHERE },
        .{ "WINDOW", Token.WINDOW },
        .{ "WITH", Token.WITH },
        .{ "WITHOUT", Token.WITHOUT },
    });
};
