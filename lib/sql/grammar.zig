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

pub const Node = union(enum) {
    anon_0: @field(types, "anon_0"),
    root: @field(types, "root"),
    statement_or_query: @field(types, "statement_or_query"),
    anon_3: @field(types, "anon_3"),
    create: @field(types, "create"),
    create_table: @field(types, "create_table"),
    insert: @field(types, "insert"),
    table_expr: @field(types, "table_expr"),
    values: @field(types, "values"),
    anon_9: @field(types, "anon_9"),
    column_specs: @field(types, "column_specs"),
    anon_11: @field(types, "anon_11"),
    column_spec: @field(types, "column_spec"),
    typ: @field(types, "typ"),
    anon_14: @field(types, "anon_14"),
    anon_15: @field(types, "anon_15"),
    anon_16: @field(types, "anon_16"),
    anon_17: @field(types, "anon_17"),
    anon_18: @field(types, "anon_18"),
    anon_19: @field(types, "anon_19"),
    anon_20: @field(types, "anon_20"),
    anon_21: @field(types, "anon_21"),
    select: @field(types, "select"),
    distinct_or_all: @field(types, "distinct_or_all"),
    anon_24: @field(types, "anon_24"),
    result_columns: @field(types, "result_columns"),
    result_column: @field(types, "result_column"),
    anon_27: @field(types, "anon_27"),
    from: @field(types, "from"),
    table_or_subquery_or_join: @field(types, "table_or_subquery_or_join"),
    anon_30: @field(types, "anon_30"),
    tables_or_subqueries: @field(types, "tables_or_subqueries"),
    table_or_subquery: @field(types, "table_or_subquery"),
    where: @field(types, "where"),
    group_by: @field(types, "group_by"),
    having: @field(types, "having"),
    window: @field(types, "window"),
    order_by: @field(types, "order_by"),
    ordering_term: @field(types, "ordering_term"),
    limit: @field(types, "limit"),
    anon_40: @field(types, "anon_40"),
    exprs: @field(types, "exprs"),
    expr: @field(types, "expr"),
    expr_plus: @field(types, "expr_plus"),
    anon_44: @field(types, "anon_44"),
    anon_45: @field(types, "anon_45"),
    anon_46: @field(types, "anon_46"),
    case: @field(types, "case"),
    case_when: @field(types, "case_when"),
    case_else: @field(types, "case_else"),
    anon_50: @field(types, "anon_50"),
    function_call: @field(types, "function_call"),
    function_name: @field(types, "function_name"),
    anon_53: @field(types, "anon_53"),
    anon_54: @field(types, "anon_54"),
    anon_55: @field(types, "anon_55"),
    function_args: @field(types, "function_args"),
    value: @field(types, "value"),
    tokens: @field(types, "tokens"),
    FROM: @field(types, "FROM"),
    string: @field(types, "string"),
    not_greater_than: @field(types, "not_greater_than"),
    DO: @field(types, "DO"),
    INSTEAD: @field(types, "INSTEAD"),
    TEMPORARY: @field(types, "TEMPORARY"),
    DELETE: @field(types, "DELETE"),
    DISTINCT: @field(types, "DISTINCT"),
    when: @field(types, "when"),
    WINDOW: @field(types, "WINDOW"),
    NATURAL: @field(types, "NATURAL"),
    right: @field(types, "right"),
    BY: @field(types, "BY"),
    COLLATE: @field(types, "COLLATE"),
    IF: @field(types, "IF"),
    DEFERRED: @field(types, "DEFERRED"),
    WHERE: @field(types, "WHERE"),
    args: @field(types, "args"),
    left: @field(types, "left"),
    modulus: @field(types, "modulus"),
    ATTACH: @field(types, "ATTACH"),
    bitwise_not: @field(types, "bitwise_not"),
    GLOB: @field(types, "GLOB"),
    NOT: @field(types, "NOT"),
    FILTER: @field(types, "FILTER"),
    THEN: @field(types, "THEN"),
    tables_or_subqueries_or_join: @field(types, "tables_or_subqueries_or_join"),
    PRAGMA: @field(types, "PRAGMA"),
    UNBOUNDED: @field(types, "UNBOUNDED"),
    FOR: @field(types, "FOR"),
    join_clause: @field(types, "join_clause"),
    shift_left: @field(types, "shift_left"),
    EXISTS: @field(types, "EXISTS"),
    AND: @field(types, "AND"),
    double_equal: @field(types, "double_equal"),
    BETWEEN: @field(types, "BETWEEN"),
    INSERT: @field(types, "INSERT"),
    CASCADE: @field(types, "CASCADE"),
    INITIALLY: @field(types, "INITIALLY"),
    RECURSIVE: @field(types, "RECURSIVE"),
    REPLACE: @field(types, "REPLACE"),
    CREATE: @field(types, "CREATE"),
    open_paren: @field(types, "open_paren"),
    UNIQUE: @field(types, "UNIQUE"),
    greater_than: @field(types, "greater_than"),
    WHEN: @field(types, "WHEN"),
    NOTHING: @field(types, "NOTHING"),
    OF: @field(types, "OF"),
    semicolon: @field(types, "semicolon"),
    RESTRICT: @field(types, "RESTRICT"),
    DEFERRABLE: @field(types, "DEFERRABLE"),
    NULLS: @field(types, "NULLS"),
    ON: @field(types, "ON"),
    close_paren: @field(types, "close_paren"),
    EXPLAIN: @field(types, "EXPLAIN"),
    INTERSECT: @field(types, "INTERSECT"),
    FULL: @field(types, "FULL"),
    PLAN: @field(types, "PLAN"),
    PRIMARY: @field(types, "PRIMARY"),
    name: @field(types, "name"),
    EACH: @field(types, "EACH"),
    OFFSET: @field(types, "OFFSET"),
    ROLLBACK: @field(types, "ROLLBACK"),
    shift_right: @field(types, "shift_right"),
    SET: @field(types, "SET"),
    TRANSACTION: @field(types, "TRANSACTION"),
    bitwise_and: @field(types, "bitwise_and"),
    WITH: @field(types, "WITH"),
    COMMIT: @field(types, "COMMIT"),
    VALUES: @field(types, "VALUES"),
    EXCLUSIVE: @field(types, "EXCLUSIVE"),
    ALL: @field(types, "ALL"),
    ADD: @field(types, "ADD"),
    ACTION: @field(types, "ACTION"),
    dot: @field(types, "dot"),
    AFTER: @field(types, "AFTER"),
    CONFLICT: @field(types, "CONFLICT"),
    DEFAULT: @field(types, "DEFAULT"),
    INNER: @field(types, "INNER"),
    IS: @field(types, "IS"),
    IMMEDIATE: @field(types, "IMMEDIATE"),
    SAVEPOINT: @field(types, "SAVEPOINT"),
    FOLLOWING: @field(types, "FOLLOWING"),
    RAISE: @field(types, "RAISE"),
    HAVING: @field(types, "HAVING"),
    TEMP: @field(types, "TEMP"),
    less_than: @field(types, "less_than"),
    CHECK: @field(types, "CHECK"),
    RETURNING: @field(types, "RETURNING"),
    INDEX: @field(types, "INDEX"),
    CONSTRAINT: @field(types, "CONSTRAINT"),
    then: @field(types, "then"),
    CURRENT_TIME: @field(types, "CURRENT_TIME"),
    ISNULL: @field(types, "ISNULL"),
    ROW: @field(types, "ROW"),
    plus: @field(types, "plus"),
    FAIL: @field(types, "FAIL"),
    USING: @field(types, "USING"),
    NOTNULL: @field(types, "NOTNULL"),
    CAST: @field(types, "CAST"),
    AS: @field(types, "AS"),
    SELECT: @field(types, "SELECT"),
    COLUMN: @field(types, "COLUMN"),
    END: @field(types, "END"),
    IN: @field(types, "IN"),
    INDEXED: @field(types, "INDEXED"),
    LEFT: @field(types, "LEFT"),
    QUERY: @field(types, "QUERY"),
    BEFORE: @field(types, "BEFORE"),
    equal: @field(types, "equal"),
    OTHERS: @field(types, "OTHERS"),
    REFERENCES: @field(types, "REFERENCES"),
    ORDER: @field(types, "ORDER"),
    ROWS: @field(types, "ROWS"),
    comma: @field(types, "comma"),
    TIES: @field(types, "TIES"),
    LIMIT: @field(types, "LIMIT"),
    bitwise_or: @field(types, "bitwise_or"),
    ABORT: @field(types, "ABORT"),
    DETACH: @field(types, "DETACH"),
    DROP: @field(types, "DROP"),
    LAST: @field(types, "LAST"),
    not_equal: @field(types, "not_equal"),
    INTO: @field(types, "INTO"),
    CURRENT_TIMESTAMP: @field(types, "CURRENT_TIMESTAMP"),
    PRECEDING: @field(types, "PRECEDING"),
    RANGE: @field(types, "RANGE"),
    MATERIALIZED: @field(types, "MATERIALIZED"),
    OUTER: @field(types, "OUTER"),
    GENERATED: @field(types, "GENERATED"),
    string_concat: @field(types, "string_concat"),
    REGEXP: @field(types, "REGEXP"),
    AUTOINCREMENT: @field(types, "AUTOINCREMENT"),
    CROSS: @field(types, "CROSS"),
    CURRENT_DATE: @field(types, "CURRENT_DATE"),
    BEGIN: @field(types, "BEGIN"),
    ASC: @field(types, "ASC"),
    EXCEPT: @field(types, "EXCEPT"),
    OR: @field(types, "OR"),
    RIGHT: @field(types, "RIGHT"),
    TRIGGER: @field(types, "TRIGGER"),
    EXCLUDE: @field(types, "EXCLUDE"),
    UPDATE: @field(types, "UPDATE"),
    ESCAPE: @field(types, "ESCAPE"),
    RELEASE: @field(types, "RELEASE"),
    LIKE: @field(types, "LIKE"),
    FIRST: @field(types, "FIRST"),
    minus: @field(types, "minus"),
    TODO: @field(types, "TODO"),
    eof: @field(types, "eof"),
    WITHOUT: @field(types, "WITHOUT"),
    GROUPS: @field(types, "GROUPS"),
    number: @field(types, "number"),
    GROUP: @field(types, "GROUP"),
    CURRENT: @field(types, "CURRENT"),
    FOREIGN: @field(types, "FOREIGN"),
    KEY: @field(types, "KEY"),
    DATABASE: @field(types, "DATABASE"),
    REINDEX: @field(types, "REINDEX"),
    UNION: @field(types, "UNION"),
    not_less_than: @field(types, "not_less_than"),
    OVER: @field(types, "OVER"),
    RENAME: @field(types, "RENAME"),
    PARTITION: @field(types, "PARTITION"),
    forward_slash: @field(types, "forward_slash"),
    ANALYZE: @field(types, "ANALYZE"),
    VACUUM: @field(types, "VACUUM"),
    DESC: @field(types, "DESC"),
    VIRTUAL: @field(types, "VIRTUAL"),
    JOIN: @field(types, "JOIN"),
    NULL: @field(types, "NULL"),
    ALWAYS: @field(types, "ALWAYS"),
    TO: @field(types, "TO"),
    star: @field(types, "star"),
    MATCH: @field(types, "MATCH"),
    ELSE: @field(types, "ELSE"),
    greater_than_or_equal: @field(types, "greater_than_or_equal"),
    VIEW: @field(types, "VIEW"),
    CASE: @field(types, "CASE"),
    ALTER: @field(types, "ALTER"),
    IGNORE: @field(types, "IGNORE"),
    TABLE: @field(types, "TABLE"),
    less_than_or_equal: @field(types, "less_than_or_equal"),
    NO: @field(types, "NO"),
};

pub const rules = struct {
    pub const anon_0 = Rule{ .optional = RuleRef{ .field_name = "semicolon", .rule_name = "semicolon" } };
    pub const root = Rule{ .all_of = &[_]RuleRef{
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
        .{ .choice = RuleRef{ .field_name = "expr_plus", .rule_name = "expr_plus" } },
        .{ .choice = RuleRef{ .field_name = "value", .rule_name = "value" } },
    } };
    pub const expr_plus = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr" },
        RuleRef{ .field_name = "plus", .rule_name = "plus" },
        RuleRef{ .field_name = "right", .rule_name = "expr" },
    } };
    pub const anon_44 = Rule{ .optional = RuleRef{ .field_name = "expr", .rule_name = "expr" } };
    pub const anon_45 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "case_when", .rule_name = "case_when" }, .separator = null } };
    pub const anon_46 = Rule{ .optional = RuleRef{ .field_name = "case_else", .rule_name = "case_else" } };
    pub const case = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "CASE" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_44" },
        RuleRef{ .field_name = "case_when", .rule_name = "anon_45" },
        RuleRef{ .field_name = "case_else", .rule_name = "anon_46" },
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
    pub const anon_50 = Rule{ .optional = RuleRef{ .field_name = "function_args", .rule_name = "function_args" } };
    pub const function_call = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "function_name", .rule_name = "function_name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "function_args", .rule_name = "anon_50" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const function_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_53 = Rule{ .optional = RuleRef{ .field_name = null, .rule_name = "DISTINCT" } };
    pub const anon_54 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const anon_55 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "anon_53" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_54" },
    } };
    pub const function_args = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "args", .rule_name = "anon_55" } },
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
    pub const right = Rule{ .token = .right };
    pub const BY = Rule{ .token = .BY };
    pub const COLLATE = Rule{ .token = .COLLATE };
    pub const IF = Rule{ .token = .IF };
    pub const DEFERRED = Rule{ .token = .DEFERRED };
    pub const WHERE = Rule{ .token = .WHERE };
    pub const args = Rule{ .token = .args };
    pub const left = Rule{ .token = .left };
    pub const modulus = Rule{ .token = .modulus };
    pub const ATTACH = Rule{ .token = .ATTACH };
    pub const bitwise_not = Rule{ .token = .bitwise_not };
    pub const GLOB = Rule{ .token = .GLOB };
    pub const NOT = Rule{ .token = .NOT };
    pub const FILTER = Rule{ .token = .FILTER };
    pub const THEN = Rule{ .token = .THEN };
    pub const tables_or_subqueries_or_join = Rule{ .token = .tables_or_subqueries_or_join };
    pub const PRAGMA = Rule{ .token = .PRAGMA };
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
    pub const WITH = Rule{ .token = .WITH };
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
    pub const anon_0 = ?sql.Parser.NodeId("semicolon");
    pub const root = struct {
        statement_or_query: sql.Parser.NodeId("statement_or_query"),
        semicolon: sql.Parser.NodeId("anon_0"),
        eof: sql.Parser.NodeId("eof"),
    };
    pub const statement_or_query = union(enum) {
        select: sql.Parser.NodeId("select"),
        values: sql.Parser.NodeId("values"),
        create: sql.Parser.NodeId("create"),
        insert: sql.Parser.NodeId("insert"),
    };
    pub const anon_3 = struct {};
    pub const create = union(enum) {
        create_table: sql.Parser.NodeId("create_table"),
    };
    pub const create_table = struct {
        name: sql.Parser.NodeId("name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        column_specs: sql.Parser.NodeId("column_specs"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const insert = struct {
        name: sql.Parser.NodeId("name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        column_specs: sql.Parser.NodeId("column_specs"),
        close_paren: sql.Parser.NodeId("close_paren"),
        table_expr: sql.Parser.NodeId("table_expr"),
    };
    pub const table_expr = union(enum) {
        values: sql.Parser.NodeId("values"),
    };
    pub const values = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        exprs: sql.Parser.NodeId("exprs"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const anon_9 = []const sql.Parser.NodeId("column_spec");
    pub const column_specs = struct {
        column_spec: sql.Parser.NodeId("anon_9"),
    };
    pub const anon_11 = ?sql.Parser.NodeId("typ");
    pub const column_spec = struct {
        name: sql.Parser.NodeId("name"),
        typ: sql.Parser.NodeId("anon_11"),
    };
    pub const typ = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const anon_14 = ?sql.Parser.NodeId("distinct_or_all");
    pub const anon_15 = ?sql.Parser.NodeId("from");
    pub const anon_16 = ?sql.Parser.NodeId("where");
    pub const anon_17 = ?sql.Parser.NodeId("group_by");
    pub const anon_18 = ?sql.Parser.NodeId("having");
    pub const anon_19 = ?sql.Parser.NodeId("window");
    pub const anon_20 = ?sql.Parser.NodeId("order_by");
    pub const anon_21 = ?sql.Parser.NodeId("limit");
    pub const select = struct {
        distinct_or_all: sql.Parser.NodeId("anon_14"),
        result_columns: sql.Parser.NodeId("result_columns"),
        from: sql.Parser.NodeId("anon_15"),
        where: sql.Parser.NodeId("anon_16"),
        group_by: sql.Parser.NodeId("anon_17"),
        having: sql.Parser.NodeId("anon_18"),
        window: sql.Parser.NodeId("anon_19"),
        order_by: sql.Parser.NodeId("anon_20"),
        limit: sql.Parser.NodeId("anon_21"),
    };
    pub const distinct_or_all = enum {
        DISTINCT,
        ALL,
    };
    pub const anon_24 = []const sql.Parser.NodeId("result_column");
    pub const result_columns = struct {
        result_column: sql.Parser.NodeId("anon_24"),
    };
    pub const result_column = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_27 = []const sql.Parser.NodeId("tables_or_subqueries_or_join");
    pub const from = struct {
        tables_or_subqueries_or_join: sql.Parser.NodeId("anon_27"),
    };
    pub const table_or_subquery_or_join = union(enum) {
        tables_or_subqueries: sql.Parser.NodeId("tables_or_subqueries"),
        join_clause: sql.Parser.NodeId("join_clause"),
    };
    pub const anon_30 = []const sql.Parser.NodeId("table_or_subquery");
    pub const tables_or_subqueries = struct {
        table_or_subquery: sql.Parser.NodeId("anon_30"),
    };
    pub const table_or_subquery = struct {};
    pub const where = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const group_by = struct {
        exprs: sql.Parser.NodeId("exprs"),
    };
    pub const having = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const window = struct {};
    pub const order_by = struct {
        ordering_term: sql.Parser.NodeId("ordering_term"),
    };
    pub const ordering_term = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const limit = struct {
        exprs: sql.Parser.NodeId("exprs"),
    };
    pub const anon_40 = []const sql.Parser.NodeId("expr");
    pub const exprs = struct {
        expr: sql.Parser.NodeId("anon_40"),
    };
    pub const expr = union(enum) {
        case: sql.Parser.NodeId("case"),
        function_call: sql.Parser.NodeId("function_call"),
        expr_plus: sql.Parser.NodeId("expr_plus"),
        value: sql.Parser.NodeId("value"),
    };
    pub const expr_plus = struct {
        left: sql.Parser.NodeId("expr"),
        plus: sql.Parser.NodeId("plus"),
        right: sql.Parser.NodeId("expr"),
    };
    pub const anon_44 = ?sql.Parser.NodeId("expr");
    pub const anon_45 = []const sql.Parser.NodeId("case_when");
    pub const anon_46 = ?sql.Parser.NodeId("case_else");
    pub const case = struct {
        expr: sql.Parser.NodeId("anon_44"),
        case_when: sql.Parser.NodeId("anon_45"),
        case_else: sql.Parser.NodeId("anon_46"),
    };
    pub const case_when = struct {
        when: sql.Parser.NodeId("expr"),
        then: sql.Parser.NodeId("expr"),
    };
    pub const case_else = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_50 = ?sql.Parser.NodeId("function_args");
    pub const function_call = struct {
        function_name: sql.Parser.NodeId("function_name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        function_args: sql.Parser.NodeId("anon_50"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const function_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const anon_53 = ?sql.Parser.NodeId("DISTINCT");
    pub const anon_54 = []const sql.Parser.NodeId("expr");
    pub const anon_55 = struct {
        expr: sql.Parser.NodeId("anon_54"),
    };
    pub const function_args = union(enum) {
        args: sql.Parser.NodeId("anon_55"),
        star: sql.Parser.NodeId("star"),
    };
    pub const value = union(enum) {
        number: sql.Parser.NodeId("number"),
        string: sql.Parser.NodeId("string"),
    };
    pub const tokens = union(enum) {
        less_than: sql.Parser.NodeId("less_than"),
        greater_than: sql.Parser.NodeId("greater_than"),
        less_than_or_equal: sql.Parser.NodeId("less_than_or_equal"),
        greater_than_or_equal: sql.Parser.NodeId("greater_than_or_equal"),
        not_less_than: sql.Parser.NodeId("not_less_than"),
        not_greater_than: sql.Parser.NodeId("not_greater_than"),
        equal: sql.Parser.NodeId("equal"),
        double_equal: sql.Parser.NodeId("double_equal"),
        not_equal: sql.Parser.NodeId("not_equal"),
        plus: sql.Parser.NodeId("plus"),
        minus: sql.Parser.NodeId("minus"),
        star: sql.Parser.NodeId("star"),
        forward_slash: sql.Parser.NodeId("forward_slash"),
        dot: sql.Parser.NodeId("dot"),
        modulus: sql.Parser.NodeId("modulus"),
        bitwise_and: sql.Parser.NodeId("bitwise_and"),
        bitwise_or: sql.Parser.NodeId("bitwise_or"),
        bitwise_not: sql.Parser.NodeId("bitwise_not"),
        string_concat: sql.Parser.NodeId("string_concat"),
        shift_left: sql.Parser.NodeId("shift_left"),
        shift_right: sql.Parser.NodeId("shift_right"),
    };
    pub const FROM = void;
    pub const string = void;
    pub const not_greater_than = void;
    pub const DO = void;
    pub const INSTEAD = void;
    pub const TEMPORARY = void;
    pub const DELETE = void;
    pub const DISTINCT = void;
    pub const when = void;
    pub const WINDOW = void;
    pub const NATURAL = void;
    pub const right = void;
    pub const BY = void;
    pub const COLLATE = void;
    pub const IF = void;
    pub const DEFERRED = void;
    pub const WHERE = void;
    pub const args = void;
    pub const left = void;
    pub const modulus = void;
    pub const ATTACH = void;
    pub const bitwise_not = void;
    pub const GLOB = void;
    pub const NOT = void;
    pub const FILTER = void;
    pub const THEN = void;
    pub const tables_or_subqueries_or_join = void;
    pub const PRAGMA = void;
    pub const UNBOUNDED = void;
    pub const FOR = void;
    pub const join_clause = void;
    pub const shift_left = void;
    pub const EXISTS = void;
    pub const AND = void;
    pub const double_equal = void;
    pub const BETWEEN = void;
    pub const INSERT = void;
    pub const CASCADE = void;
    pub const INITIALLY = void;
    pub const RECURSIVE = void;
    pub const REPLACE = void;
    pub const CREATE = void;
    pub const open_paren = void;
    pub const UNIQUE = void;
    pub const greater_than = void;
    pub const WHEN = void;
    pub const NOTHING = void;
    pub const OF = void;
    pub const semicolon = void;
    pub const RESTRICT = void;
    pub const DEFERRABLE = void;
    pub const NULLS = void;
    pub const ON = void;
    pub const close_paren = void;
    pub const EXPLAIN = void;
    pub const INTERSECT = void;
    pub const FULL = void;
    pub const PLAN = void;
    pub const PRIMARY = void;
    pub const name = void;
    pub const EACH = void;
    pub const OFFSET = void;
    pub const ROLLBACK = void;
    pub const shift_right = void;
    pub const SET = void;
    pub const TRANSACTION = void;
    pub const bitwise_and = void;
    pub const WITH = void;
    pub const COMMIT = void;
    pub const VALUES = void;
    pub const EXCLUSIVE = void;
    pub const ALL = void;
    pub const ADD = void;
    pub const ACTION = void;
    pub const dot = void;
    pub const AFTER = void;
    pub const CONFLICT = void;
    pub const DEFAULT = void;
    pub const INNER = void;
    pub const IS = void;
    pub const IMMEDIATE = void;
    pub const SAVEPOINT = void;
    pub const FOLLOWING = void;
    pub const RAISE = void;
    pub const HAVING = void;
    pub const TEMP = void;
    pub const less_than = void;
    pub const CHECK = void;
    pub const RETURNING = void;
    pub const INDEX = void;
    pub const CONSTRAINT = void;
    pub const then = void;
    pub const CURRENT_TIME = void;
    pub const ISNULL = void;
    pub const ROW = void;
    pub const plus = void;
    pub const FAIL = void;
    pub const USING = void;
    pub const NOTNULL = void;
    pub const CAST = void;
    pub const AS = void;
    pub const SELECT = void;
    pub const COLUMN = void;
    pub const END = void;
    pub const IN = void;
    pub const INDEXED = void;
    pub const LEFT = void;
    pub const QUERY = void;
    pub const BEFORE = void;
    pub const equal = void;
    pub const OTHERS = void;
    pub const REFERENCES = void;
    pub const ORDER = void;
    pub const ROWS = void;
    pub const comma = void;
    pub const TIES = void;
    pub const LIMIT = void;
    pub const bitwise_or = void;
    pub const ABORT = void;
    pub const DETACH = void;
    pub const DROP = void;
    pub const LAST = void;
    pub const not_equal = void;
    pub const INTO = void;
    pub const CURRENT_TIMESTAMP = void;
    pub const PRECEDING = void;
    pub const RANGE = void;
    pub const MATERIALIZED = void;
    pub const OUTER = void;
    pub const GENERATED = void;
    pub const string_concat = void;
    pub const REGEXP = void;
    pub const AUTOINCREMENT = void;
    pub const CROSS = void;
    pub const CURRENT_DATE = void;
    pub const BEGIN = void;
    pub const ASC = void;
    pub const EXCEPT = void;
    pub const OR = void;
    pub const RIGHT = void;
    pub const TRIGGER = void;
    pub const EXCLUDE = void;
    pub const UPDATE = void;
    pub const ESCAPE = void;
    pub const RELEASE = void;
    pub const LIKE = void;
    pub const FIRST = void;
    pub const minus = void;
    pub const TODO = void;
    pub const eof = void;
    pub const WITHOUT = void;
    pub const GROUPS = void;
    pub const number = void;
    pub const GROUP = void;
    pub const CURRENT = void;
    pub const FOREIGN = void;
    pub const KEY = void;
    pub const DATABASE = void;
    pub const REINDEX = void;
    pub const UNION = void;
    pub const not_less_than = void;
    pub const OVER = void;
    pub const RENAME = void;
    pub const PARTITION = void;
    pub const forward_slash = void;
    pub const ANALYZE = void;
    pub const VACUUM = void;
    pub const DESC = void;
    pub const VIRTUAL = void;
    pub const JOIN = void;
    pub const NULL = void;
    pub const ALWAYS = void;
    pub const TO = void;
    pub const star = void;
    pub const MATCH = void;
    pub const ELSE = void;
    pub const greater_than_or_equal = void;
    pub const VIEW = void;
    pub const CASE = void;
    pub const ALTER = void;
    pub const IGNORE = void;
    pub const TABLE = void;
    pub const less_than_or_equal = void;
    pub const NO = void;
};

pub const is_left_recursive = struct {
    pub const anon_0 = false;
    pub const root = false;
    pub const statement_or_query = false;
    pub const anon_3 = false;
    pub const create = false;
    pub const create_table = false;
    pub const insert = false;
    pub const table_expr = false;
    pub const values = false;
    pub const anon_9 = false;
    pub const column_specs = false;
    pub const anon_11 = false;
    pub const column_spec = false;
    pub const typ = false;
    pub const anon_14 = false;
    pub const anon_15 = false;
    pub const anon_16 = false;
    pub const anon_17 = false;
    pub const anon_18 = false;
    pub const anon_19 = false;
    pub const anon_20 = false;
    pub const anon_21 = false;
    pub const select = false;
    pub const distinct_or_all = false;
    pub const anon_24 = false;
    pub const result_columns = false;
    pub const result_column = false;
    pub const anon_27 = false;
    pub const from = false;
    pub const table_or_subquery_or_join = false;
    pub const anon_30 = false;
    pub const tables_or_subqueries = false;
    pub const table_or_subquery = false;
    pub const where = false;
    pub const group_by = false;
    pub const having = false;
    pub const window = false;
    pub const order_by = false;
    pub const ordering_term = false;
    pub const limit = false;
    pub const anon_40 = false;
    pub const exprs = false;
    pub const expr = true;
    pub const expr_plus = true;
    pub const anon_44 = false;
    pub const anon_45 = false;
    pub const anon_46 = false;
    pub const case = false;
    pub const case_when = false;
    pub const case_else = false;
    pub const anon_50 = false;
    pub const function_call = false;
    pub const function_name = false;
    pub const anon_53 = false;
    pub const anon_54 = false;
    pub const anon_55 = false;
    pub const function_args = false;
    pub const value = false;
    pub const tokens = false;
    pub const FROM = false;
    pub const string = false;
    pub const not_greater_than = false;
    pub const DO = false;
    pub const INSTEAD = false;
    pub const TEMPORARY = false;
    pub const DELETE = false;
    pub const DISTINCT = false;
    pub const when = false;
    pub const WINDOW = false;
    pub const NATURAL = false;
    pub const right = false;
    pub const BY = false;
    pub const COLLATE = false;
    pub const IF = false;
    pub const DEFERRED = false;
    pub const WHERE = false;
    pub const args = false;
    pub const left = false;
    pub const modulus = false;
    pub const ATTACH = false;
    pub const bitwise_not = false;
    pub const GLOB = false;
    pub const NOT = false;
    pub const FILTER = false;
    pub const THEN = false;
    pub const tables_or_subqueries_or_join = false;
    pub const PRAGMA = false;
    pub const UNBOUNDED = false;
    pub const FOR = false;
    pub const join_clause = false;
    pub const shift_left = false;
    pub const EXISTS = false;
    pub const AND = false;
    pub const double_equal = false;
    pub const BETWEEN = false;
    pub const INSERT = false;
    pub const CASCADE = false;
    pub const INITIALLY = false;
    pub const RECURSIVE = false;
    pub const REPLACE = false;
    pub const CREATE = false;
    pub const open_paren = false;
    pub const UNIQUE = false;
    pub const greater_than = false;
    pub const WHEN = false;
    pub const NOTHING = false;
    pub const OF = false;
    pub const semicolon = false;
    pub const RESTRICT = false;
    pub const DEFERRABLE = false;
    pub const NULLS = false;
    pub const ON = false;
    pub const close_paren = false;
    pub const EXPLAIN = false;
    pub const INTERSECT = false;
    pub const FULL = false;
    pub const PLAN = false;
    pub const PRIMARY = false;
    pub const name = false;
    pub const EACH = false;
    pub const OFFSET = false;
    pub const ROLLBACK = false;
    pub const shift_right = false;
    pub const SET = false;
    pub const TRANSACTION = false;
    pub const bitwise_and = false;
    pub const WITH = false;
    pub const COMMIT = false;
    pub const VALUES = false;
    pub const EXCLUSIVE = false;
    pub const ALL = false;
    pub const ADD = false;
    pub const ACTION = false;
    pub const dot = false;
    pub const AFTER = false;
    pub const CONFLICT = false;
    pub const DEFAULT = false;
    pub const INNER = false;
    pub const IS = false;
    pub const IMMEDIATE = false;
    pub const SAVEPOINT = false;
    pub const FOLLOWING = false;
    pub const RAISE = false;
    pub const HAVING = false;
    pub const TEMP = false;
    pub const less_than = false;
    pub const CHECK = false;
    pub const RETURNING = false;
    pub const INDEX = false;
    pub const CONSTRAINT = false;
    pub const then = false;
    pub const CURRENT_TIME = false;
    pub const ISNULL = false;
    pub const ROW = false;
    pub const plus = false;
    pub const FAIL = false;
    pub const USING = false;
    pub const NOTNULL = false;
    pub const CAST = false;
    pub const AS = false;
    pub const SELECT = false;
    pub const COLUMN = false;
    pub const END = false;
    pub const IN = false;
    pub const INDEXED = false;
    pub const LEFT = false;
    pub const QUERY = false;
    pub const BEFORE = false;
    pub const equal = false;
    pub const OTHERS = false;
    pub const REFERENCES = false;
    pub const ORDER = false;
    pub const ROWS = false;
    pub const comma = false;
    pub const TIES = false;
    pub const LIMIT = false;
    pub const bitwise_or = false;
    pub const ABORT = false;
    pub const DETACH = false;
    pub const DROP = false;
    pub const LAST = false;
    pub const not_equal = false;
    pub const INTO = false;
    pub const CURRENT_TIMESTAMP = false;
    pub const PRECEDING = false;
    pub const RANGE = false;
    pub const MATERIALIZED = false;
    pub const OUTER = false;
    pub const GENERATED = false;
    pub const string_concat = false;
    pub const REGEXP = false;
    pub const AUTOINCREMENT = false;
    pub const CROSS = false;
    pub const CURRENT_DATE = false;
    pub const BEGIN = false;
    pub const ASC = false;
    pub const EXCEPT = false;
    pub const OR = false;
    pub const RIGHT = false;
    pub const TRIGGER = false;
    pub const EXCLUDE = false;
    pub const UPDATE = false;
    pub const ESCAPE = false;
    pub const RELEASE = false;
    pub const LIKE = false;
    pub const FIRST = false;
    pub const minus = false;
    pub const TODO = false;
    pub const eof = false;
    pub const WITHOUT = false;
    pub const GROUPS = false;
    pub const number = false;
    pub const GROUP = false;
    pub const CURRENT = false;
    pub const FOREIGN = false;
    pub const KEY = false;
    pub const DATABASE = false;
    pub const REINDEX = false;
    pub const UNION = false;
    pub const not_less_than = false;
    pub const OVER = false;
    pub const RENAME = false;
    pub const PARTITION = false;
    pub const forward_slash = false;
    pub const ANALYZE = false;
    pub const VACUUM = false;
    pub const DESC = false;
    pub const VIRTUAL = false;
    pub const JOIN = false;
    pub const NULL = false;
    pub const ALWAYS = false;
    pub const TO = false;
    pub const star = false;
    pub const MATCH = false;
    pub const ELSE = false;
    pub const greater_than_or_equal = false;
    pub const VIEW = false;
    pub const CASE = false;
    pub const ALTER = false;
    pub const IGNORE = false;
    pub const TABLE = false;
    pub const less_than_or_equal = false;
    pub const NO = false;
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
    right,
    BY,
    COLLATE,
    IF,
    DEFERRED,
    WHERE,
    args,
    left,
    modulus,
    ATTACH,
    bitwise_not,
    GLOB,
    NOT,
    FILTER,
    THEN,
    tables_or_subqueries_or_join,
    PRAGMA,
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
    WITH,
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
