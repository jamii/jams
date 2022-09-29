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
    pub const anon_9 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "column_spec", .rule_name = "column_spec" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const column_specs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "column_spec", .rule_name = "anon_9" },
    } };
    pub const anon_11 = Rule{ .optional = RuleRef{ .field_name = "typ", .rule_name = "typ" } };
    pub const column_spec = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "typ", .rule_name = "anon_11" },
    } };
    pub const typ = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_14 = Rule{ .optional = RuleRef{ .field_name = "distinct_or_all", .rule_name = "distinct_or_all" } };
    pub const anon_15 = Rule{ .optional = RuleRef{ .field_name = "from", .rule_name = "from" } };
    pub const anon_16 = Rule{ .optional = RuleRef{ .field_name = "where", .rule_name = "where" } };
    pub const anon_17 = Rule{ .optional = RuleRef{ .field_name = "group_by", .rule_name = "group_by" } };
    pub const anon_18 = Rule{ .optional = RuleRef{ .field_name = "having", .rule_name = "having" } };
    pub const anon_19 = Rule{ .optional = RuleRef{ .field_name = "window", .rule_name = "window" } };
    pub const anon_20 = Rule{ .optional = RuleRef{ .field_name = "order_by", .rule_name = "order_by" } };
    pub const anon_21 = Rule{ .optional = RuleRef{ .field_name = "limit", .rule_name = "limit" } };
    pub const select = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "SELECT" },
        RuleRef{ .field_name = "distinct_or_all", .rule_name = "anon_14" },
        RuleRef{ .field_name = "result_columns", .rule_name = "result_columns" },
        RuleRef{ .field_name = "from", .rule_name = "anon_15" },
        RuleRef{ .field_name = "where", .rule_name = "anon_16" },
        RuleRef{ .field_name = "group_by", .rule_name = "anon_17" },
        RuleRef{ .field_name = "having", .rule_name = "anon_18" },
        RuleRef{ .field_name = "window", .rule_name = "anon_19" },
        RuleRef{ .field_name = "order_by", .rule_name = "anon_20" },
        RuleRef{ .field_name = "limit", .rule_name = "anon_21" },
    } };
    pub const distinct_or_all = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "DISTINCT" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "ALL" } },
    } };
    pub const anon_24 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "result_column", .rule_name = "result_column" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const result_columns = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "result_column", .rule_name = "anon_24" },
    } };
    pub const result_column = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_27 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "tables_or_subqueries_or_join" }, .separator = null } };
    pub const from = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "FROM" },
        RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "anon_27" },
    } };
    pub const table_or_subquery_or_join = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "tables_or_subqueries", .rule_name = "tables_or_subqueries" } },
        .{ .choice = RuleRef{ .field_name = "join_clause", .rule_name = "join_clause" } },
    } };
    pub const anon_30 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "table_or_subquery", .rule_name = "table_or_subquery" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const tables_or_subqueries = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_or_subquery", .rule_name = "anon_30" },
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
    pub const anon_40 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const exprs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "anon_40" },
    } };
    pub const expr = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "CASE" }, RuleRef{ .field_name = "case", .rule_name = "case" },
        } },
        .{ .choice = RuleRef{ .field_name = "function_call", .rule_name = "function_call" } },
        .{ .choice = RuleRef{ .field_name = "value", .rule_name = "value" } },
    } };
    pub const anon_43 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "case_when", .rule_name = "case_when" }, .separator = null } };
    pub const anon_44 = Rule{ .optional = RuleRef{ .field_name = "case_else", .rule_name = "case_else" } };
    pub const case = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "CASE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
        RuleRef{ .field_name = "case_when", .rule_name = "anon_43" },
        RuleRef{ .field_name = "case_else", .rule_name = "anon_44" },
        RuleRef{ .field_name = null, .rule_name = "END" },
    } };
    pub const case_when = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "WHEN" },
        RuleRef{ .field_name = "when", .rule_name = "expr" },
        RuleRef{ .field_name = null, .rule_name = "THEN" },
        RuleRef{ .field_name = "then", .rule_name = "expr" },
    } };
    pub const case_else = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "ELSE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_48 = Rule{ .optional = RuleRef{ .field_name = "function_args", .rule_name = "function_args" } };
    pub const function_call = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "function_name", .rule_name = "function_name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "function_args", .rule_name = "anon_48" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const function_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_51 = Rule{ .optional = RuleRef{ .field_name = null, .rule_name = "DISTINCT" } };
    pub const anon_52 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const anon_53 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "anon_51" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_52" },
    } };
    pub const function_args = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "args", .rule_name = "anon_53" } },
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
    } };
    pub const value = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "number", .rule_name = "number" } },
        .{ .choice = RuleRef{ .field_name = "string", .rule_name = "string" } },
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
    pub const when = Rule{ .token = .when };
    pub const WINDOW = Rule{ .token = .WINDOW };
    pub const NATURAL = Rule{ .token = .NATURAL };
    pub const BY = Rule{ .token = .BY };
    pub const COLLATE = Rule{ .token = .COLLATE };
    pub const IF = Rule{ .token = .IF };
    pub const DEFERRED = Rule{ .token = .DEFERRED };
    pub const WHERE = Rule{ .token = .WHERE };
    pub const args = Rule{ .token = .args };
    pub const modulus = Rule{ .token = .modulus };
    pub const ATTACH = Rule{ .token = .ATTACH };
    pub const GLOB = Rule{ .token = .GLOB };
    pub const bitwise_not = Rule{ .token = .bitwise_not };
    pub const NOT = Rule{ .token = .NOT };
    pub const PRAGMA = Rule{ .token = .PRAGMA };
    pub const FILTER = Rule{ .token = .FILTER };
    pub const THEN = Rule{ .token = .THEN };
    pub const tables_or_subqueries_or_join = Rule{ .token = .tables_or_subqueries_or_join };
    pub const WITH = Rule{ .token = .WITH };
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
    pub const WHEN = Rule{ .token = .WHEN };
    pub const NOTHING = Rule{ .token = .NOTHING };
    pub const OF = Rule{ .token = .OF };
    pub const semicolon = Rule{ .token = .semicolon };
    pub const RESTRICT = Rule{ .token = .RESTRICT };
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
    pub const then = Rule{ .token = .then };
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
    pub const MATERIALIZED = Rule{ .token = .MATERIALIZED };
    pub const OUTER = Rule{ .token = .OUTER };
    pub const GENERATED = Rule{ .token = .GENERATED };
    pub const string_concat = Rule{ .token = .string_concat };
    pub const REGEXP = Rule{ .token = .REGEXP };
    pub const AUTOINCREMENT = Rule{ .token = .AUTOINCREMENT };
    pub const CROSS = Rule{ .token = .CROSS };
    pub const CURRENT_DATE = Rule{ .token = .CURRENT_DATE };
    pub const BEGIN = Rule{ .token = .BEGIN };
    pub const ASC = Rule{ .token = .ASC };
    pub const EXCEPT = Rule{ .token = .EXCEPT };
    pub const OR = Rule{ .token = .OR };
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
    pub const anon_9 = []const column_spec;
    pub const column_specs = struct {
        column_spec: *anon_9,
    };
    pub const anon_11 = ?typ;
    pub const column_spec = struct {
        name: *name,
        typ: *anon_11,
    };
    pub const typ = struct {
        name: *name,
    };
    pub const anon_14 = ?distinct_or_all;
    pub const anon_15 = ?from;
    pub const anon_16 = ?where;
    pub const anon_17 = ?group_by;
    pub const anon_18 = ?having;
    pub const anon_19 = ?window;
    pub const anon_20 = ?order_by;
    pub const anon_21 = ?limit;
    pub const select = struct {
        distinct_or_all: *anon_14,
        result_columns: *result_columns,
        from: *anon_15,
        where: *anon_16,
        group_by: *anon_17,
        having: *anon_18,
        window: *anon_19,
        order_by: *anon_20,
        limit: *anon_21,
    };
    pub const distinct_or_all = enum {
        DISTINCT,
        ALL,
    };
    pub const anon_24 = []const result_column;
    pub const result_columns = struct {
        result_column: *anon_24,
    };
    pub const result_column = struct {
        expr: *expr,
    };
    pub const anon_27 = []const tables_or_subqueries_or_join;
    pub const from = struct {
        tables_or_subqueries_or_join: *anon_27,
    };
    pub const table_or_subquery_or_join = union(enum) {
        tables_or_subqueries: tables_or_subqueries,
        join_clause: join_clause,
    };
    pub const anon_30 = []const table_or_subquery;
    pub const tables_or_subqueries = struct {
        table_or_subquery: *anon_30,
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
    pub const anon_40 = []const expr;
    pub const exprs = struct {
        expr: *anon_40,
    };
    pub const expr = union(enum) {
        case: case,
        function_call: function_call,
        value: value,
    };
    pub const anon_43 = []const case_when;
    pub const anon_44 = ?case_else;
    pub const case = struct {
        expr: *expr,
        case_when: *anon_43,
        case_else: *anon_44,
    };
    pub const case_when = struct {
        when: *expr,
        then: *expr,
    };
    pub const case_else = struct {
        expr: *expr,
    };
    pub const anon_48 = ?function_args;
    pub const function_call = struct {
        function_name: *function_name,
        open_paren: *open_paren,
        function_args: *anon_48,
        close_paren: *close_paren,
    };
    pub const function_name = struct {
        name: *name,
    };
    pub const anon_51 = ?DISTINCT;
    pub const anon_52 = []const expr;
    pub const anon_53 = struct {
        expr: *anon_52,
    };
    pub const function_args = union(enum) {
        args: anon_53,
        star: star,
    };
    pub const value = union(enum) {
        number: number,
        string: string,
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
    pub const FROM = [2]usize;
    pub const string = [2]usize;
    pub const not_greater_than = [2]usize;
    pub const DO = [2]usize;
    pub const INSTEAD = [2]usize;
    pub const TEMPORARY = [2]usize;
    pub const DELETE = [2]usize;
    pub const DISTINCT = [2]usize;
    pub const when = [2]usize;
    pub const WINDOW = [2]usize;
    pub const NATURAL = [2]usize;
    pub const BY = [2]usize;
    pub const COLLATE = [2]usize;
    pub const IF = [2]usize;
    pub const DEFERRED = [2]usize;
    pub const WHERE = [2]usize;
    pub const args = [2]usize;
    pub const modulus = [2]usize;
    pub const ATTACH = [2]usize;
    pub const GLOB = [2]usize;
    pub const bitwise_not = [2]usize;
    pub const NOT = [2]usize;
    pub const PRAGMA = [2]usize;
    pub const FILTER = [2]usize;
    pub const THEN = [2]usize;
    pub const tables_or_subqueries_or_join = [2]usize;
    pub const WITH = [2]usize;
    pub const UNBOUNDED = [2]usize;
    pub const FOR = [2]usize;
    pub const join_clause = [2]usize;
    pub const shift_left = [2]usize;
    pub const EXISTS = [2]usize;
    pub const AND = [2]usize;
    pub const double_equal = [2]usize;
    pub const BETWEEN = [2]usize;
    pub const INSERT = [2]usize;
    pub const CASCADE = [2]usize;
    pub const INITIALLY = [2]usize;
    pub const RECURSIVE = [2]usize;
    pub const REPLACE = [2]usize;
    pub const CREATE = [2]usize;
    pub const open_paren = [2]usize;
    pub const UNIQUE = [2]usize;
    pub const greater_than = [2]usize;
    pub const WHEN = [2]usize;
    pub const NOTHING = [2]usize;
    pub const OF = [2]usize;
    pub const semicolon = [2]usize;
    pub const RESTRICT = [2]usize;
    pub const DEFERRABLE = [2]usize;
    pub const NULLS = [2]usize;
    pub const ON = [2]usize;
    pub const close_paren = [2]usize;
    pub const EXPLAIN = [2]usize;
    pub const INTERSECT = [2]usize;
    pub const FULL = [2]usize;
    pub const PLAN = [2]usize;
    pub const PRIMARY = [2]usize;
    pub const name = [2]usize;
    pub const EACH = [2]usize;
    pub const OFFSET = [2]usize;
    pub const ROLLBACK = [2]usize;
    pub const shift_right = [2]usize;
    pub const SET = [2]usize;
    pub const TRANSACTION = [2]usize;
    pub const bitwise_and = [2]usize;
    pub const COMMIT = [2]usize;
    pub const VALUES = [2]usize;
    pub const EXCLUSIVE = [2]usize;
    pub const ALL = [2]usize;
    pub const ADD = [2]usize;
    pub const ACTION = [2]usize;
    pub const dot = [2]usize;
    pub const AFTER = [2]usize;
    pub const CONFLICT = [2]usize;
    pub const DEFAULT = [2]usize;
    pub const INNER = [2]usize;
    pub const IS = [2]usize;
    pub const IMMEDIATE = [2]usize;
    pub const SAVEPOINT = [2]usize;
    pub const FOLLOWING = [2]usize;
    pub const RAISE = [2]usize;
    pub const HAVING = [2]usize;
    pub const TEMP = [2]usize;
    pub const less_than = [2]usize;
    pub const CHECK = [2]usize;
    pub const RETURNING = [2]usize;
    pub const INDEX = [2]usize;
    pub const CONSTRAINT = [2]usize;
    pub const then = [2]usize;
    pub const CURRENT_TIME = [2]usize;
    pub const ISNULL = [2]usize;
    pub const ROW = [2]usize;
    pub const plus = [2]usize;
    pub const FAIL = [2]usize;
    pub const USING = [2]usize;
    pub const NOTNULL = [2]usize;
    pub const CAST = [2]usize;
    pub const AS = [2]usize;
    pub const SELECT = [2]usize;
    pub const COLUMN = [2]usize;
    pub const END = [2]usize;
    pub const IN = [2]usize;
    pub const INDEXED = [2]usize;
    pub const LEFT = [2]usize;
    pub const QUERY = [2]usize;
    pub const BEFORE = [2]usize;
    pub const equal = [2]usize;
    pub const OTHERS = [2]usize;
    pub const REFERENCES = [2]usize;
    pub const ORDER = [2]usize;
    pub const ROWS = [2]usize;
    pub const comma = [2]usize;
    pub const TIES = [2]usize;
    pub const LIMIT = [2]usize;
    pub const bitwise_or = [2]usize;
    pub const ABORT = [2]usize;
    pub const DETACH = [2]usize;
    pub const DROP = [2]usize;
    pub const LAST = [2]usize;
    pub const not_equal = [2]usize;
    pub const INTO = [2]usize;
    pub const CURRENT_TIMESTAMP = [2]usize;
    pub const PRECEDING = [2]usize;
    pub const RANGE = [2]usize;
    pub const MATERIALIZED = [2]usize;
    pub const OUTER = [2]usize;
    pub const GENERATED = [2]usize;
    pub const string_concat = [2]usize;
    pub const REGEXP = [2]usize;
    pub const AUTOINCREMENT = [2]usize;
    pub const CROSS = [2]usize;
    pub const CURRENT_DATE = [2]usize;
    pub const BEGIN = [2]usize;
    pub const ASC = [2]usize;
    pub const EXCEPT = [2]usize;
    pub const OR = [2]usize;
    pub const RIGHT = [2]usize;
    pub const TRIGGER = [2]usize;
    pub const EXCLUDE = [2]usize;
    pub const UPDATE = [2]usize;
    pub const ESCAPE = [2]usize;
    pub const RELEASE = [2]usize;
    pub const LIKE = [2]usize;
    pub const FIRST = [2]usize;
    pub const minus = [2]usize;
    pub const TODO = [2]usize;
    pub const eof = [2]usize;
    pub const WITHOUT = [2]usize;
    pub const GROUPS = [2]usize;
    pub const number = [2]usize;
    pub const GROUP = [2]usize;
    pub const CURRENT = [2]usize;
    pub const FOREIGN = [2]usize;
    pub const KEY = [2]usize;
    pub const DATABASE = [2]usize;
    pub const REINDEX = [2]usize;
    pub const UNION = [2]usize;
    pub const not_less_than = [2]usize;
    pub const OVER = [2]usize;
    pub const RENAME = [2]usize;
    pub const PARTITION = [2]usize;
    pub const forward_slash = [2]usize;
    pub const ANALYZE = [2]usize;
    pub const VACUUM = [2]usize;
    pub const DESC = [2]usize;
    pub const VIRTUAL = [2]usize;
    pub const JOIN = [2]usize;
    pub const NULL = [2]usize;
    pub const ALWAYS = [2]usize;
    pub const TO = [2]usize;
    pub const star = [2]usize;
    pub const MATCH = [2]usize;
    pub const ELSE = [2]usize;
    pub const greater_than_or_equal = [2]usize;
    pub const VIEW = [2]usize;
    pub const CASE = [2]usize;
    pub const ALTER = [2]usize;
    pub const IGNORE = [2]usize;
    pub const TABLE = [2]usize;
    pub const less_than_or_equal = [2]usize;
    pub const NO = [2]usize;
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
    when,
    WINDOW,
    NATURAL,
    BY,
    COLLATE,
    IF,
    DEFERRED,
    WHERE,
    args,
    modulus,
    ATTACH,
    GLOB,
    bitwise_not,
    NOT,
    PRAGMA,
    FILTER,
    THEN,
    tables_or_subqueries_or_join,
    WITH,
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
    WHEN,
    NOTHING,
    OF,
    semicolon,
    RESTRICT,
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
    then,
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
    MATERIALIZED,
    OUTER,
    GENERATED,
    string_concat,
    REGEXP,
    AUTOINCREMENT,
    CROSS,
    CURRENT_DATE,
    BEGIN,
    ASC,
    EXCEPT,
    OR,
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
