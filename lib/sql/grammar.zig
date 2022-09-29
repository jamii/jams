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
    tables_or_subqueries_or_join: @field(types, "tables_or_subqueries_or_join"),
    anon_30: @field(types, "anon_30"),
    tables_or_subqueries: @field(types, "tables_or_subqueries"),
    table_or_subquery: @field(types, "table_or_subquery"),
    anon_33: @field(types, "anon_33"),
    table: @field(types, "table"),
    binding: @field(types, "binding"),
    where: @field(types, "where"),
    group_by: @field(types, "group_by"),
    having: @field(types, "having"),
    window: @field(types, "window"),
    order_by: @field(types, "order_by"),
    anon_41: @field(types, "anon_41"),
    ordering_terms: @field(types, "ordering_terms"),
    anon_43: @field(types, "anon_43"),
    anon_44: @field(types, "anon_44"),
    anon_45: @field(types, "anon_45"),
    ordering_term: @field(types, "ordering_term"),
    collate: @field(types, "collate"),
    collation_name: @field(types, "collation_name"),
    asc_or_desc: @field(types, "asc_or_desc"),
    nulls_first_or_last: @field(types, "nulls_first_or_last"),
    first_or_last: @field(types, "first_or_last"),
    limit: @field(types, "limit"),
    anon_53: @field(types, "anon_53"),
    exprs: @field(types, "exprs"),
    expr: @field(types, "expr"),
    expr_or_prec: @field(types, "expr_or_prec"),
    expr_or: @field(types, "expr_or"),
    expr_and_prec: @field(types, "expr_and_prec"),
    expr_and: @field(types, "expr_and"),
    expr_not_prec: @field(types, "expr_not_prec"),
    expr_not: @field(types, "expr_not"),
    expr_incomp_prec: @field(types, "expr_incomp_prec"),
    expr_incomp: @field(types, "expr_incomp"),
    expr_incomp_complex: @field(types, "expr_incomp_complex"),
    anon_65: @field(types, "anon_65"),
    expr_incomp_between: @field(types, "expr_incomp_between"),
    anon_67: @field(types, "anon_67"),
    expr_income_binop: @field(types, "expr_income_binop"),
    IS_NOT: @field(types, "IS_NOT"),
    IS_DISTINCT_FROM: @field(types, "IS_DISTINCT_FROM"),
    IS_NOT_DISTINCT_FROM: @field(types, "IS_NOT_DISTINCT_FROM"),
    anon_72: @field(types, "anon_72"),
    anon_73: @field(types, "anon_73"),
    expr_income_not_binop: @field(types, "expr_income_not_binop"),
    anon_75: @field(types, "anon_75"),
    expr_incomp_postop: @field(types, "expr_incomp_postop"),
    NOT_NULL: @field(types, "NOT_NULL"),
    expr_comp_prec: @field(types, "expr_comp_prec"),
    anon_79: @field(types, "anon_79"),
    expr_comp: @field(types, "expr_comp"),
    expr_add_prec: @field(types, "expr_add_prec"),
    anon_82: @field(types, "anon_82"),
    expr_add: @field(types, "expr_add"),
    expr_mult_prec: @field(types, "expr_mult_prec"),
    anon_85: @field(types, "anon_85"),
    expr_mult: @field(types, "expr_mult"),
    expr_atom: @field(types, "expr_atom"),
    table_column_ref: @field(types, "table_column_ref"),
    column_ref: @field(types, "column_ref"),
    expr_paren: @field(types, "expr_paren"),
    anon_91: @field(types, "anon_91"),
    subquery: @field(types, "subquery"),
    exists_or_not_exists: @field(types, "exists_or_not_exists"),
    NOT_EXISTS: @field(types, "NOT_EXISTS"),
    subexpr: @field(types, "subexpr"),
    anon_96: @field(types, "anon_96"),
    anon_97: @field(types, "anon_97"),
    anon_98: @field(types, "anon_98"),
    case: @field(types, "case"),
    case_when: @field(types, "case_when"),
    case_else: @field(types, "case_else"),
    anon_102: @field(types, "anon_102"),
    function_call: @field(types, "function_call"),
    function_name: @field(types, "function_name"),
    anon_105: @field(types, "anon_105"),
    anon_106: @field(types, "anon_106"),
    anon_107: @field(types, "anon_107"),
    function_args: @field(types, "function_args"),
    value: @field(types, "value"),
    tokens: @field(types, "tokens"),
    FROM: @field(types, "FROM"),
    expr_incomp_binop: @field(types, "expr_incomp_binop"),
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
    NOT: @field(types, "NOT"),
    GLOB: @field(types, "GLOB"),
    bitwise_not: @field(types, "bitwise_not"),
    ATTACH: @field(types, "ATTACH"),
    PRAGMA: @field(types, "PRAGMA"),
    FILTER: @field(types, "FILTER"),
    THEN: @field(types, "THEN"),
    WITH: @field(types, "WITH"),
    UNBOUNDED: @field(types, "UNBOUNDED"),
    FOR: @field(types, "FOR"),
    join_clause: @field(types, "join_clause"),
    expr_incomp_not_binop: @field(types, "expr_incomp_not_binop"),
    EXISTS: @field(types, "EXISTS"),
    AND: @field(types, "AND"),
    double_equal: @field(types, "double_equal"),
    BETWEEN: @field(types, "BETWEEN"),
    INSERT: @field(types, "INSERT"),
    null_first_or_last: @field(types, "null_first_or_last"),
    shift_left: @field(types, "shift_left"),
    CASCADE: @field(types, "CASCADE"),
    INITIALLY: @field(types, "INITIALLY"),
    CREATE: @field(types, "CREATE"),
    open_paren: @field(types, "open_paren"),
    RECURSIVE: @field(types, "RECURSIVE"),
    greater_than: @field(types, "greater_than"),
    WHEN: @field(types, "WHEN"),
    NOTHING: @field(types, "NOTHING"),
    OF: @field(types, "OF"),
    semicolon: @field(types, "semicolon"),
    greater_than_equal: @field(types, "greater_than_equal"),
    NULLS: @field(types, "NULLS"),
    DEFERRABLE: @field(types, "DEFERRABLE"),
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
    REPLACE: @field(types, "REPLACE"),
    shift_right: @field(types, "shift_right"),
    RESTRICT: @field(types, "RESTRICT"),
    ROLLBACK: @field(types, "ROLLBACK"),
    bitwise_and: @field(types, "bitwise_and"),
    SET: @field(types, "SET"),
    TRANSACTION: @field(types, "TRANSACTION"),
    UNIQUE: @field(types, "UNIQUE"),
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
    start: @field(types, "start"),
    IS: @field(types, "IS"),
    IMMEDIATE: @field(types, "IMMEDIATE"),
    SAVEPOINT: @field(types, "SAVEPOINT"),
    FOLLOWING: @field(types, "FOLLOWING"),
    RAISE: @field(types, "RAISE"),
    HAVING: @field(types, "HAVING"),
    TEMP: @field(types, "TEMP"),
    end: @field(types, "end"),
    less_than: @field(types, "less_than"),
    CHECK: @field(types, "CHECK"),
    RETURNING: @field(types, "RETURNING"),
    INDEX: @field(types, "INDEX"),
    ISNULL: @field(types, "ISNULL"),
    then: @field(types, "then"),
    percent: @field(types, "percent"),
    CONSTRAINT: @field(types, "CONSTRAINT"),
    CURRENT_TIME: @field(types, "CURRENT_TIME"),
    ROW: @field(types, "ROW"),
    plus: @field(types, "plus"),
    FAIL: @field(types, "FAIL"),
    USING: @field(types, "USING"),
    NOTNULL: @field(types, "NOTNULL"),
    CAST: @field(types, "CAST"),
    AS: @field(types, "AS"),
    SELECT: @field(types, "SELECT"),
    IN: @field(types, "IN"),
    END: @field(types, "END"),
    COLUMN: @field(types, "COLUMN"),
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
    LAST: @field(types, "LAST"),
    DETACH: @field(types, "DETACH"),
    DROP: @field(types, "DROP"),
    not_equal: @field(types, "not_equal"),
    INTO: @field(types, "INTO"),
    CURRENT_TIMESTAMP: @field(types, "CURRENT_TIMESTAMP"),
    PRECEDING: @field(types, "PRECEDING"),
    RANGE: @field(types, "RANGE"),
    REGEXP: @field(types, "REGEXP"),
    MATERIALIZED: @field(types, "MATERIALIZED"),
    GENERATED: @field(types, "GENERATED"),
    string_concat: @field(types, "string_concat"),
    OUTER: @field(types, "OUTER"),
    AUTOINCREMENT: @field(types, "AUTOINCREMENT"),
    CROSS: @field(types, "CROSS"),
    CURRENT_DATE: @field(types, "CURRENT_DATE"),
    BEGIN: @field(types, "BEGIN"),
    ASC: @field(types, "ASC"),
    OR: @field(types, "OR"),
    EXCEPT: @field(types, "EXCEPT"),
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
    column: @field(types, "column"),
    ELSE: @field(types, "ELSE"),
    op: @field(types, "op"),
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
    pub const tables_or_subqueries_or_join = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "tables_or_subqueries", .rule_name = "tables_or_subqueries" } },
        .{ .choice = RuleRef{ .field_name = "join_clause", .rule_name = "join_clause" } },
    } };
    pub const anon_30 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "table_or_subquery", .rule_name = "table_or_subquery" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const tables_or_subqueries = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_or_subquery", .rule_name = "anon_30" },
    } };
    pub const table_or_subquery = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "table", .rule_name = "table" } },
        .{ .choice = RuleRef{ .field_name = "subquery", .rule_name = "subquery" } },
    } };
    pub const anon_33 = Rule{ .optional = RuleRef{ .field_name = "binding", .rule_name = "binding" } };
    pub const table = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "binding", .rule_name = "anon_33" },
    } };
    pub const binding = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "AS" },
        RuleRef{ .field_name = "name", .rule_name = "name" },
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
        RuleRef{ .field_name = "ordering_terms", .rule_name = "ordering_terms" },
    } };
    pub const anon_41 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "ordering_term", .rule_name = "ordering_term" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const ordering_terms = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "ordering_term", .rule_name = "anon_41" },
    } };
    pub const anon_43 = Rule{ .optional = RuleRef{ .field_name = "collate", .rule_name = "collate" } };
    pub const anon_44 = Rule{ .optional = RuleRef{ .field_name = "asc_or_desc", .rule_name = "asc_or_desc" } };
    pub const anon_45 = Rule{ .optional = RuleRef{ .field_name = "null_first_or_last", .rule_name = "null_first_or_last" } };
    pub const ordering_term = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "collate", .rule_name = "anon_43" },
        RuleRef{ .field_name = "asc_or_desc", .rule_name = "anon_44" },
        RuleRef{ .field_name = "null_first_or_last", .rule_name = "anon_45" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const collate = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "COLLATE" },
        RuleRef{ .field_name = "collation_name", .rule_name = "collation_name" },
    } };
    pub const collation_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const asc_or_desc = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "ASC" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "DESC" } },
    } };
    pub const nulls_first_or_last = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "NULLS" },
        RuleRef{ .field_name = "first_or_last", .rule_name = "first_or_last" },
    } };
    pub const first_or_last = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "FIRST" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "LAST" } },
    } };
    pub const limit = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "LIMIT" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
    } };
    pub const anon_53 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const exprs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "anon_53" },
    } };
    pub const expr = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr_or_prec", .rule_name = "expr_or_prec" },
    } };
    pub const expr_or_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_or", .rule_name = "expr_or" } },
        .{ .choice = RuleRef{ .field_name = "expr_and_prec", .rule_name = "expr_and_prec" } },
    } };
    pub const expr_or = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_and_prec" },
        RuleRef{ .field_name = null, .rule_name = "OR" },
        RuleRef{ .field_name = "right", .rule_name = "expr_or_prec" },
    } };
    pub const expr_and_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_and", .rule_name = "expr_and" } },
        .{ .choice = RuleRef{ .field_name = "expr_not_prec", .rule_name = "expr_not_prec" } },
    } };
    pub const expr_and = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_not_prec" },
        RuleRef{ .field_name = null, .rule_name = "AND" },
        RuleRef{ .field_name = "right", .rule_name = "expr_and_prec" },
    } };
    pub const expr_not_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_not", .rule_name = "expr_not" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_prec", .rule_name = "expr_incomp_prec" } },
    } };
    pub const expr_not = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "NOT" },
        RuleRef{ .field_name = "right", .rule_name = "expr_not_prec" },
    } };
    pub const expr_incomp_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_incomp", .rule_name = "expr_incomp" } },
        .{ .choice = RuleRef{ .field_name = "expr_comp_prec", .rule_name = "expr_comp_prec" } },
    } };
    pub const expr_incomp = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_incomp_binop", .rule_name = "expr_incomp_binop" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_complex", .rule_name = "expr_incomp_complex" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_postop", .rule_name = "expr_incomp_postop" } },
    } };
    pub const expr_incomp_complex = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_incomp_between", .rule_name = "expr_incomp_between" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_not_binop", .rule_name = "expr_incomp_not_binop" } },
    } };
    pub const anon_65 = Rule{ .optional = RuleRef{ .field_name = null, .rule_name = "NOT" } };
    pub const expr_incomp_between = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_comp_prec" },
        RuleRef{ .field_name = null, .rule_name = "anon_65" },
        RuleRef{ .field_name = null, .rule_name = "BETWEEN" },
        RuleRef{ .field_name = "start", .rule_name = "expr" },
        RuleRef{ .field_name = null, .rule_name = "AND" },
        RuleRef{ .field_name = "end", .rule_name = "expr" },
    } };
    pub const anon_67 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "equal", .rule_name = "equal" } },
        .{ .choice = RuleRef{ .field_name = "double_equal", .rule_name = "double_equal" } },
        .{ .choice = RuleRef{ .field_name = "not_equal", .rule_name = "not_equal" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "IS" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "IS_NOT" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "IS_DISTINCT_FROM" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "IS_NOT_DISTINCT_FROM" } },
    } };
    pub const expr_income_binop = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_comp_prec" },
        RuleRef{ .field_name = "op", .rule_name = "anon_67" },
        RuleRef{ .field_name = "right", .rule_name = "expr_incomp_prec" },
    } };
    pub const IS_NOT = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "IS" },
        RuleRef{ .field_name = null, .rule_name = "NOT" },
    } };
    pub const IS_DISTINCT_FROM = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "IS_DISTINCT_FROM" },
    } };
    pub const IS_NOT_DISTINCT_FROM = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "IS_NOT_DISTINCT_FROM" },
    } };
    pub const anon_72 = Rule{ .optional = RuleRef{ .field_name = null, .rule_name = "NOT" } };
    pub const anon_73 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "IN" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "MATCH" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "LIKE" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "REGEXP" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "GLOB" } },
    } };
    pub const expr_income_not_binop = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_comp_prec" },
        RuleRef{ .field_name = null, .rule_name = "anon_72" },
        RuleRef{ .field_name = "op", .rule_name = "anon_73" },
        RuleRef{ .field_name = "right", .rule_name = "expr_incomp_prec" },
    } };
    pub const anon_75 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "ISNULL" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "NOTNULL" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "NOT_NULL" } },
    } };
    pub const expr_incomp_postop = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_comp_prec" },
        RuleRef{ .field_name = "op", .rule_name = "anon_75" },
    } };
    pub const NOT_NULL = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "NOT" },
        RuleRef{ .field_name = null, .rule_name = "NULL" },
    } };
    pub const expr_comp_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_comp", .rule_name = "expr_comp" } },
        .{ .choice = RuleRef{ .field_name = "expr_add_prec", .rule_name = "expr_add_prec" } },
    } };
    pub const anon_79 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "less_than", .rule_name = "less_than" } },
        .{ .choice = RuleRef{ .field_name = "greater_than", .rule_name = "greater_than" } },
        .{ .choice = RuleRef{ .field_name = "less_than_or_equal", .rule_name = "less_than_or_equal" } },
        .{ .choice = RuleRef{ .field_name = "greater_than_equal", .rule_name = "greater_than_equal" } },
    } };
    pub const expr_comp = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_add_prec" },
        RuleRef{ .field_name = "op", .rule_name = "anon_79" },
        RuleRef{ .field_name = "right", .rule_name = "expr_comp_prec" },
    } };
    pub const expr_add_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_add", .rule_name = "expr_add" } },
        .{ .choice = RuleRef{ .field_name = "expr_mult_prec", .rule_name = "expr_mult_prec" } },
    } };
    pub const anon_82 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "plus", .rule_name = "plus" } },
        .{ .choice = RuleRef{ .field_name = "minus", .rule_name = "minus" } },
    } };
    pub const expr_add = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_mult_prec" },
        RuleRef{ .field_name = "op", .rule_name = "anon_82" },
        RuleRef{ .field_name = "right", .rule_name = "expr_add_prec" },
    } };
    pub const expr_mult_prec = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_mult", .rule_name = "expr_mult" } },
        .{ .choice = RuleRef{ .field_name = "expr_atom", .rule_name = "expr_atom" } },
    } };
    pub const anon_85 = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
        .{ .choice = RuleRef{ .field_name = "forward_slash", .rule_name = "forward_slash" } },
        .{ .choice = RuleRef{ .field_name = "percent", .rule_name = "percent" } },
    } };
    pub const expr_mult = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_atom" },
        RuleRef{ .field_name = "op", .rule_name = "anon_85" },
        RuleRef{ .field_name = "right", .rule_name = "expr_mult_prec" },
    } };
    pub const expr_atom = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = null, .rule_name = "CASE" }, RuleRef{ .field_name = "case", .rule_name = "case" },
        } },
        .{ .choice = RuleRef{ .field_name = "expr_paren", .rule_name = "expr_paren" } },
        .{ .choice = RuleRef{ .field_name = "function_call", .rule_name = "function_call" } },
        .{ .choice = RuleRef{ .field_name = "table_column_ref", .rule_name = "table_column_ref" } },
        .{ .choice = RuleRef{ .field_name = "column_ref", .rule_name = "column_ref" } },
        .{ .choice = RuleRef{ .field_name = "value", .rule_name = "value" } },
    } };
    pub const table_column_ref = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table", .rule_name = "name" },
        RuleRef{ .field_name = "dot", .rule_name = "dot" },
        RuleRef{ .field_name = "column", .rule_name = "name" },
    } };
    pub const column_ref = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const expr_paren = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "subquery", .rule_name = "subquery" } },
        .{ .choice = RuleRef{ .field_name = "subexpr", .rule_name = "subexpr" } },
    } };
    pub const anon_91 = Rule{ .optional = RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "exists_or_not_exists" } };
    pub const subquery = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "anon_91" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "select", .rule_name = "select" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const exists_or_not_exists = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "EXISTS" } },
        .{ .choice = RuleRef{ .field_name = null, .rule_name = "NOT_EXISTS" } },
    } };
    pub const NOT_EXISTS = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "NOT" },
        RuleRef{ .field_name = null, .rule_name = "EXISTS" },
    } };
    pub const subexpr = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const anon_96 = Rule{ .optional = RuleRef{ .field_name = "expr", .rule_name = "expr" } };
    pub const anon_97 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "case_when", .rule_name = "case_when" }, .separator = null } };
    pub const anon_98 = Rule{ .optional = RuleRef{ .field_name = "case_else", .rule_name = "case_else" } };
    pub const case = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "CASE" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_96" },
        RuleRef{ .field_name = "case_when", .rule_name = "anon_97" },
        RuleRef{ .field_name = "case_else", .rule_name = "anon_98" },
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
    pub const anon_102 = Rule{ .optional = RuleRef{ .field_name = "function_args", .rule_name = "function_args" } };
    pub const function_call = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "function_name", .rule_name = "function_name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "function_args", .rule_name = "anon_102" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const function_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_105 = Rule{ .optional = RuleRef{ .field_name = null, .rule_name = "DISTINCT" } };
    pub const anon_106 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = null, .rule_name = "comma" } } };
    pub const anon_107 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = null, .rule_name = "anon_105" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_106" },
    } };
    pub const function_args = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "args", .rule_name = "anon_107" } },
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
        .{ .choice = RuleRef{ .field_name = "percent", .rule_name = "percent" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_and", .rule_name = "bitwise_and" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_or", .rule_name = "bitwise_or" } },
        .{ .choice = RuleRef{ .field_name = "bitwise_not", .rule_name = "bitwise_not" } },
        .{ .choice = RuleRef{ .field_name = "string_concat", .rule_name = "string_concat" } },
        .{ .choice = RuleRef{ .field_name = "shift_left", .rule_name = "shift_left" } },
        .{ .choice = RuleRef{ .field_name = "shift_right", .rule_name = "shift_right" } },
    } };
    pub const FROM = Rule{ .token = .FROM };
    pub const expr_incomp_binop = Rule{ .token = .expr_incomp_binop };
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
    pub const NOT = Rule{ .token = .NOT };
    pub const GLOB = Rule{ .token = .GLOB };
    pub const bitwise_not = Rule{ .token = .bitwise_not };
    pub const ATTACH = Rule{ .token = .ATTACH };
    pub const PRAGMA = Rule{ .token = .PRAGMA };
    pub const FILTER = Rule{ .token = .FILTER };
    pub const THEN = Rule{ .token = .THEN };
    pub const WITH = Rule{ .token = .WITH };
    pub const UNBOUNDED = Rule{ .token = .UNBOUNDED };
    pub const FOR = Rule{ .token = .FOR };
    pub const join_clause = Rule{ .token = .join_clause };
    pub const expr_incomp_not_binop = Rule{ .token = .expr_incomp_not_binop };
    pub const EXISTS = Rule{ .token = .EXISTS };
    pub const AND = Rule{ .token = .AND };
    pub const double_equal = Rule{ .token = .double_equal };
    pub const BETWEEN = Rule{ .token = .BETWEEN };
    pub const INSERT = Rule{ .token = .INSERT };
    pub const null_first_or_last = Rule{ .token = .null_first_or_last };
    pub const shift_left = Rule{ .token = .shift_left };
    pub const CASCADE = Rule{ .token = .CASCADE };
    pub const INITIALLY = Rule{ .token = .INITIALLY };
    pub const CREATE = Rule{ .token = .CREATE };
    pub const open_paren = Rule{ .token = .open_paren };
    pub const RECURSIVE = Rule{ .token = .RECURSIVE };
    pub const greater_than = Rule{ .token = .greater_than };
    pub const WHEN = Rule{ .token = .WHEN };
    pub const NOTHING = Rule{ .token = .NOTHING };
    pub const OF = Rule{ .token = .OF };
    pub const semicolon = Rule{ .token = .semicolon };
    pub const greater_than_equal = Rule{ .token = .greater_than_equal };
    pub const NULLS = Rule{ .token = .NULLS };
    pub const DEFERRABLE = Rule{ .token = .DEFERRABLE };
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
    pub const REPLACE = Rule{ .token = .REPLACE };
    pub const shift_right = Rule{ .token = .shift_right };
    pub const RESTRICT = Rule{ .token = .RESTRICT };
    pub const ROLLBACK = Rule{ .token = .ROLLBACK };
    pub const bitwise_and = Rule{ .token = .bitwise_and };
    pub const SET = Rule{ .token = .SET };
    pub const TRANSACTION = Rule{ .token = .TRANSACTION };
    pub const UNIQUE = Rule{ .token = .UNIQUE };
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
    pub const start = Rule{ .token = .start };
    pub const IS = Rule{ .token = .IS };
    pub const IMMEDIATE = Rule{ .token = .IMMEDIATE };
    pub const SAVEPOINT = Rule{ .token = .SAVEPOINT };
    pub const FOLLOWING = Rule{ .token = .FOLLOWING };
    pub const RAISE = Rule{ .token = .RAISE };
    pub const HAVING = Rule{ .token = .HAVING };
    pub const TEMP = Rule{ .token = .TEMP };
    pub const end = Rule{ .token = .end };
    pub const less_than = Rule{ .token = .less_than };
    pub const CHECK = Rule{ .token = .CHECK };
    pub const RETURNING = Rule{ .token = .RETURNING };
    pub const INDEX = Rule{ .token = .INDEX };
    pub const ISNULL = Rule{ .token = .ISNULL };
    pub const then = Rule{ .token = .then };
    pub const percent = Rule{ .token = .percent };
    pub const CONSTRAINT = Rule{ .token = .CONSTRAINT };
    pub const CURRENT_TIME = Rule{ .token = .CURRENT_TIME };
    pub const ROW = Rule{ .token = .ROW };
    pub const plus = Rule{ .token = .plus };
    pub const FAIL = Rule{ .token = .FAIL };
    pub const USING = Rule{ .token = .USING };
    pub const NOTNULL = Rule{ .token = .NOTNULL };
    pub const CAST = Rule{ .token = .CAST };
    pub const AS = Rule{ .token = .AS };
    pub const SELECT = Rule{ .token = .SELECT };
    pub const IN = Rule{ .token = .IN };
    pub const END = Rule{ .token = .END };
    pub const COLUMN = Rule{ .token = .COLUMN };
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
    pub const LAST = Rule{ .token = .LAST };
    pub const DETACH = Rule{ .token = .DETACH };
    pub const DROP = Rule{ .token = .DROP };
    pub const not_equal = Rule{ .token = .not_equal };
    pub const INTO = Rule{ .token = .INTO };
    pub const CURRENT_TIMESTAMP = Rule{ .token = .CURRENT_TIMESTAMP };
    pub const PRECEDING = Rule{ .token = .PRECEDING };
    pub const RANGE = Rule{ .token = .RANGE };
    pub const REGEXP = Rule{ .token = .REGEXP };
    pub const MATERIALIZED = Rule{ .token = .MATERIALIZED };
    pub const GENERATED = Rule{ .token = .GENERATED };
    pub const string_concat = Rule{ .token = .string_concat };
    pub const OUTER = Rule{ .token = .OUTER };
    pub const AUTOINCREMENT = Rule{ .token = .AUTOINCREMENT };
    pub const CROSS = Rule{ .token = .CROSS };
    pub const CURRENT_DATE = Rule{ .token = .CURRENT_DATE };
    pub const BEGIN = Rule{ .token = .BEGIN };
    pub const ASC = Rule{ .token = .ASC };
    pub const OR = Rule{ .token = .OR };
    pub const EXCEPT = Rule{ .token = .EXCEPT };
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
    pub const column = Rule{ .token = .column };
    pub const ELSE = Rule{ .token = .ELSE };
    pub const op = Rule{ .token = .op };
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
    pub const tables_or_subqueries_or_join = union(enum) {
        tables_or_subqueries: sql.Parser.NodeId("tables_or_subqueries"),
        join_clause: sql.Parser.NodeId("join_clause"),
    };
    pub const anon_30 = []const sql.Parser.NodeId("table_or_subquery");
    pub const tables_or_subqueries = struct {
        table_or_subquery: sql.Parser.NodeId("anon_30"),
    };
    pub const table_or_subquery = union(enum) {
        table: sql.Parser.NodeId("table"),
        subquery: sql.Parser.NodeId("subquery"),
    };
    pub const anon_33 = ?sql.Parser.NodeId("binding");
    pub const table = struct {
        name: sql.Parser.NodeId("name"),
        binding: sql.Parser.NodeId("anon_33"),
    };
    pub const binding = struct {
        name: sql.Parser.NodeId("name"),
    };
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
        ordering_terms: sql.Parser.NodeId("ordering_terms"),
    };
    pub const anon_41 = []const sql.Parser.NodeId("ordering_term");
    pub const ordering_terms = struct {
        ordering_term: sql.Parser.NodeId("anon_41"),
    };
    pub const anon_43 = ?sql.Parser.NodeId("collate");
    pub const anon_44 = ?sql.Parser.NodeId("asc_or_desc");
    pub const anon_45 = ?sql.Parser.NodeId("null_first_or_last");
    pub const ordering_term = struct {
        collate: sql.Parser.NodeId("anon_43"),
        asc_or_desc: sql.Parser.NodeId("anon_44"),
        null_first_or_last: sql.Parser.NodeId("anon_45"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const collate = struct {
        collation_name: sql.Parser.NodeId("collation_name"),
    };
    pub const collation_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const asc_or_desc = enum {
        ASC,
        DESC,
    };
    pub const nulls_first_or_last = struct {
        first_or_last: sql.Parser.NodeId("first_or_last"),
    };
    pub const first_or_last = enum {
        FIRST,
        LAST,
    };
    pub const limit = struct {
        exprs: sql.Parser.NodeId("exprs"),
    };
    pub const anon_53 = []const sql.Parser.NodeId("expr");
    pub const exprs = struct {
        expr: sql.Parser.NodeId("anon_53"),
    };
    pub const expr = struct {
        expr_or_prec: sql.Parser.NodeId("expr_or_prec"),
    };
    pub const expr_or_prec = union(enum) {
        expr_or: sql.Parser.NodeId("expr_or"),
        expr_and_prec: sql.Parser.NodeId("expr_and_prec"),
    };
    pub const expr_or = struct {
        left: sql.Parser.NodeId("expr_and_prec"),
        right: sql.Parser.NodeId("expr_or_prec"),
    };
    pub const expr_and_prec = union(enum) {
        expr_and: sql.Parser.NodeId("expr_and"),
        expr_not_prec: sql.Parser.NodeId("expr_not_prec"),
    };
    pub const expr_and = struct {
        left: sql.Parser.NodeId("expr_not_prec"),
        right: sql.Parser.NodeId("expr_and_prec"),
    };
    pub const expr_not_prec = union(enum) {
        expr_not: sql.Parser.NodeId("expr_not"),
        expr_incomp_prec: sql.Parser.NodeId("expr_incomp_prec"),
    };
    pub const expr_not = struct {
        right: sql.Parser.NodeId("expr_not_prec"),
    };
    pub const expr_incomp_prec = union(enum) {
        expr_incomp: sql.Parser.NodeId("expr_incomp"),
        expr_comp_prec: sql.Parser.NodeId("expr_comp_prec"),
    };
    pub const expr_incomp = union(enum) {
        expr_incomp_binop: sql.Parser.NodeId("expr_incomp_binop"),
        expr_incomp_complex: sql.Parser.NodeId("expr_incomp_complex"),
        expr_incomp_postop: sql.Parser.NodeId("expr_incomp_postop"),
    };
    pub const expr_incomp_complex = union(enum) {
        expr_incomp_between: sql.Parser.NodeId("expr_incomp_between"),
        expr_incomp_not_binop: sql.Parser.NodeId("expr_incomp_not_binop"),
    };
    pub const anon_65 = ?sql.Parser.NodeId("NOT");
    pub const expr_incomp_between = struct {
        left: sql.Parser.NodeId("expr_comp_prec"),
        start: sql.Parser.NodeId("expr"),
        end: sql.Parser.NodeId("expr"),
    };
    pub const anon_67 = union(enum) {
        equal: sql.Parser.NodeId("equal"),
        double_equal: sql.Parser.NodeId("double_equal"),
        not_equal: sql.Parser.NodeId("not_equal"),
        IS,
        IS_NOT,
        IS_DISTINCT_FROM,
        IS_NOT_DISTINCT_FROM,
    };
    pub const expr_income_binop = struct {
        left: sql.Parser.NodeId("expr_comp_prec"),
        op: sql.Parser.NodeId("anon_67"),
        right: sql.Parser.NodeId("expr_incomp_prec"),
    };
    pub const IS_NOT = struct {};
    pub const IS_DISTINCT_FROM = struct {};
    pub const IS_NOT_DISTINCT_FROM = struct {};
    pub const anon_72 = ?sql.Parser.NodeId("NOT");
    pub const anon_73 = enum {
        IN,
        MATCH,
        LIKE,
        REGEXP,
        GLOB,
    };
    pub const expr_income_not_binop = struct {
        left: sql.Parser.NodeId("expr_comp_prec"),
        op: sql.Parser.NodeId("anon_73"),
        right: sql.Parser.NodeId("expr_incomp_prec"),
    };
    pub const anon_75 = enum {
        ISNULL,
        NOTNULL,
        NOT_NULL,
    };
    pub const expr_incomp_postop = struct {
        left: sql.Parser.NodeId("expr_comp_prec"),
        op: sql.Parser.NodeId("anon_75"),
    };
    pub const NOT_NULL = struct {};
    pub const expr_comp_prec = union(enum) {
        expr_comp: sql.Parser.NodeId("expr_comp"),
        expr_add_prec: sql.Parser.NodeId("expr_add_prec"),
    };
    pub const anon_79 = union(enum) {
        less_than: sql.Parser.NodeId("less_than"),
        greater_than: sql.Parser.NodeId("greater_than"),
        less_than_or_equal: sql.Parser.NodeId("less_than_or_equal"),
        greater_than_equal: sql.Parser.NodeId("greater_than_equal"),
    };
    pub const expr_comp = struct {
        left: sql.Parser.NodeId("expr_add_prec"),
        op: sql.Parser.NodeId("anon_79"),
        right: sql.Parser.NodeId("expr_comp_prec"),
    };
    pub const expr_add_prec = union(enum) {
        expr_add: sql.Parser.NodeId("expr_add"),
        expr_mult_prec: sql.Parser.NodeId("expr_mult_prec"),
    };
    pub const anon_82 = union(enum) {
        plus: sql.Parser.NodeId("plus"),
        minus: sql.Parser.NodeId("minus"),
    };
    pub const expr_add = struct {
        left: sql.Parser.NodeId("expr_mult_prec"),
        op: sql.Parser.NodeId("anon_82"),
        right: sql.Parser.NodeId("expr_add_prec"),
    };
    pub const expr_mult_prec = union(enum) {
        expr_mult: sql.Parser.NodeId("expr_mult"),
        expr_atom: sql.Parser.NodeId("expr_atom"),
    };
    pub const anon_85 = union(enum) {
        star: sql.Parser.NodeId("star"),
        forward_slash: sql.Parser.NodeId("forward_slash"),
        percent: sql.Parser.NodeId("percent"),
    };
    pub const expr_mult = struct {
        left: sql.Parser.NodeId("expr_atom"),
        op: sql.Parser.NodeId("anon_85"),
        right: sql.Parser.NodeId("expr_mult_prec"),
    };
    pub const expr_atom = union(enum) {
        case: sql.Parser.NodeId("case"),
        expr_paren: sql.Parser.NodeId("expr_paren"),
        function_call: sql.Parser.NodeId("function_call"),
        table_column_ref: sql.Parser.NodeId("table_column_ref"),
        column_ref: sql.Parser.NodeId("column_ref"),
        value: sql.Parser.NodeId("value"),
    };
    pub const table_column_ref = struct {
        table: sql.Parser.NodeId("name"),
        dot: sql.Parser.NodeId("dot"),
        column: sql.Parser.NodeId("name"),
    };
    pub const column_ref = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const expr_paren = union(enum) {
        subquery: sql.Parser.NodeId("subquery"),
        subexpr: sql.Parser.NodeId("subexpr"),
    };
    pub const anon_91 = ?sql.Parser.NodeId("exists_or_not_exists");
    pub const subquery = struct {
        exists_or_not_exists: sql.Parser.NodeId("anon_91"),
        open_paren: sql.Parser.NodeId("open_paren"),
        select: sql.Parser.NodeId("select"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const exists_or_not_exists = enum {
        EXISTS,
        NOT_EXISTS,
    };
    pub const NOT_EXISTS = struct {};
    pub const subexpr = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        expr: sql.Parser.NodeId("expr"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const anon_96 = ?sql.Parser.NodeId("expr");
    pub const anon_97 = []const sql.Parser.NodeId("case_when");
    pub const anon_98 = ?sql.Parser.NodeId("case_else");
    pub const case = struct {
        expr: sql.Parser.NodeId("anon_96"),
        case_when: sql.Parser.NodeId("anon_97"),
        case_else: sql.Parser.NodeId("anon_98"),
    };
    pub const case_when = struct {
        when: sql.Parser.NodeId("expr"),
        then: sql.Parser.NodeId("expr"),
    };
    pub const case_else = struct {
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_102 = ?sql.Parser.NodeId("function_args");
    pub const function_call = struct {
        function_name: sql.Parser.NodeId("function_name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        function_args: sql.Parser.NodeId("anon_102"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const function_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const anon_105 = ?sql.Parser.NodeId("DISTINCT");
    pub const anon_106 = []const sql.Parser.NodeId("expr");
    pub const anon_107 = struct {
        expr: sql.Parser.NodeId("anon_106"),
    };
    pub const function_args = union(enum) {
        args: sql.Parser.NodeId("anon_107"),
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
        percent: sql.Parser.NodeId("percent"),
        bitwise_and: sql.Parser.NodeId("bitwise_and"),
        bitwise_or: sql.Parser.NodeId("bitwise_or"),
        bitwise_not: sql.Parser.NodeId("bitwise_not"),
        string_concat: sql.Parser.NodeId("string_concat"),
        shift_left: sql.Parser.NodeId("shift_left"),
        shift_right: sql.Parser.NodeId("shift_right"),
    };
    pub const FROM = void;
    pub const expr_incomp_binop = void;
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
    pub const NOT = void;
    pub const GLOB = void;
    pub const bitwise_not = void;
    pub const ATTACH = void;
    pub const PRAGMA = void;
    pub const FILTER = void;
    pub const THEN = void;
    pub const WITH = void;
    pub const UNBOUNDED = void;
    pub const FOR = void;
    pub const join_clause = void;
    pub const expr_incomp_not_binop = void;
    pub const EXISTS = void;
    pub const AND = void;
    pub const double_equal = void;
    pub const BETWEEN = void;
    pub const INSERT = void;
    pub const null_first_or_last = void;
    pub const shift_left = void;
    pub const CASCADE = void;
    pub const INITIALLY = void;
    pub const CREATE = void;
    pub const open_paren = void;
    pub const RECURSIVE = void;
    pub const greater_than = void;
    pub const WHEN = void;
    pub const NOTHING = void;
    pub const OF = void;
    pub const semicolon = void;
    pub const greater_than_equal = void;
    pub const NULLS = void;
    pub const DEFERRABLE = void;
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
    pub const REPLACE = void;
    pub const shift_right = void;
    pub const RESTRICT = void;
    pub const ROLLBACK = void;
    pub const bitwise_and = void;
    pub const SET = void;
    pub const TRANSACTION = void;
    pub const UNIQUE = void;
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
    pub const start = void;
    pub const IS = void;
    pub const IMMEDIATE = void;
    pub const SAVEPOINT = void;
    pub const FOLLOWING = void;
    pub const RAISE = void;
    pub const HAVING = void;
    pub const TEMP = void;
    pub const end = void;
    pub const less_than = void;
    pub const CHECK = void;
    pub const RETURNING = void;
    pub const INDEX = void;
    pub const ISNULL = void;
    pub const then = void;
    pub const percent = void;
    pub const CONSTRAINT = void;
    pub const CURRENT_TIME = void;
    pub const ROW = void;
    pub const plus = void;
    pub const FAIL = void;
    pub const USING = void;
    pub const NOTNULL = void;
    pub const CAST = void;
    pub const AS = void;
    pub const SELECT = void;
    pub const IN = void;
    pub const END = void;
    pub const COLUMN = void;
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
    pub const LAST = void;
    pub const DETACH = void;
    pub const DROP = void;
    pub const not_equal = void;
    pub const INTO = void;
    pub const CURRENT_TIMESTAMP = void;
    pub const PRECEDING = void;
    pub const RANGE = void;
    pub const REGEXP = void;
    pub const MATERIALIZED = void;
    pub const GENERATED = void;
    pub const string_concat = void;
    pub const OUTER = void;
    pub const AUTOINCREMENT = void;
    pub const CROSS = void;
    pub const CURRENT_DATE = void;
    pub const BEGIN = void;
    pub const ASC = void;
    pub const OR = void;
    pub const EXCEPT = void;
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
    pub const column = void;
    pub const ELSE = void;
    pub const op = void;
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
    pub const tables_or_subqueries_or_join = false;
    pub const anon_30 = false;
    pub const tables_or_subqueries = false;
    pub const table_or_subquery = false;
    pub const anon_33 = false;
    pub const table = false;
    pub const binding = false;
    pub const where = false;
    pub const group_by = false;
    pub const having = false;
    pub const window = false;
    pub const order_by = false;
    pub const anon_41 = false;
    pub const ordering_terms = false;
    pub const anon_43 = false;
    pub const anon_44 = false;
    pub const anon_45 = false;
    pub const ordering_term = false;
    pub const collate = false;
    pub const collation_name = false;
    pub const asc_or_desc = false;
    pub const nulls_first_or_last = false;
    pub const first_or_last = false;
    pub const limit = false;
    pub const anon_53 = false;
    pub const exprs = false;
    pub const expr = false;
    pub const expr_or_prec = false;
    pub const expr_or = false;
    pub const expr_and_prec = false;
    pub const expr_and = false;
    pub const expr_not_prec = false;
    pub const expr_not = false;
    pub const expr_incomp_prec = false;
    pub const expr_incomp = false;
    pub const expr_incomp_complex = false;
    pub const anon_65 = false;
    pub const expr_incomp_between = false;
    pub const anon_67 = false;
    pub const expr_income_binop = false;
    pub const IS_NOT = false;
    pub const IS_DISTINCT_FROM = true;
    pub const IS_NOT_DISTINCT_FROM = true;
    pub const anon_72 = false;
    pub const anon_73 = false;
    pub const expr_income_not_binop = false;
    pub const anon_75 = false;
    pub const expr_incomp_postop = false;
    pub const NOT_NULL = false;
    pub const expr_comp_prec = false;
    pub const anon_79 = false;
    pub const expr_comp = false;
    pub const expr_add_prec = false;
    pub const anon_82 = false;
    pub const expr_add = false;
    pub const expr_mult_prec = false;
    pub const anon_85 = false;
    pub const expr_mult = false;
    pub const expr_atom = false;
    pub const table_column_ref = false;
    pub const column_ref = false;
    pub const expr_paren = false;
    pub const anon_91 = false;
    pub const subquery = false;
    pub const exists_or_not_exists = false;
    pub const NOT_EXISTS = false;
    pub const subexpr = false;
    pub const anon_96 = false;
    pub const anon_97 = false;
    pub const anon_98 = false;
    pub const case = false;
    pub const case_when = false;
    pub const case_else = false;
    pub const anon_102 = false;
    pub const function_call = false;
    pub const function_name = false;
    pub const anon_105 = false;
    pub const anon_106 = false;
    pub const anon_107 = false;
    pub const function_args = false;
    pub const value = false;
    pub const tokens = false;
    pub const FROM = false;
    pub const expr_incomp_binop = false;
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
    pub const NOT = false;
    pub const GLOB = false;
    pub const bitwise_not = false;
    pub const ATTACH = false;
    pub const PRAGMA = false;
    pub const FILTER = false;
    pub const THEN = false;
    pub const WITH = false;
    pub const UNBOUNDED = false;
    pub const FOR = false;
    pub const join_clause = false;
    pub const expr_incomp_not_binop = false;
    pub const EXISTS = false;
    pub const AND = false;
    pub const double_equal = false;
    pub const BETWEEN = false;
    pub const INSERT = false;
    pub const null_first_or_last = false;
    pub const shift_left = false;
    pub const CASCADE = false;
    pub const INITIALLY = false;
    pub const CREATE = false;
    pub const open_paren = false;
    pub const RECURSIVE = false;
    pub const greater_than = false;
    pub const WHEN = false;
    pub const NOTHING = false;
    pub const OF = false;
    pub const semicolon = false;
    pub const greater_than_equal = false;
    pub const NULLS = false;
    pub const DEFERRABLE = false;
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
    pub const REPLACE = false;
    pub const shift_right = false;
    pub const RESTRICT = false;
    pub const ROLLBACK = false;
    pub const bitwise_and = false;
    pub const SET = false;
    pub const TRANSACTION = false;
    pub const UNIQUE = false;
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
    pub const start = false;
    pub const IS = false;
    pub const IMMEDIATE = false;
    pub const SAVEPOINT = false;
    pub const FOLLOWING = false;
    pub const RAISE = false;
    pub const HAVING = false;
    pub const TEMP = false;
    pub const end = false;
    pub const less_than = false;
    pub const CHECK = false;
    pub const RETURNING = false;
    pub const INDEX = false;
    pub const ISNULL = false;
    pub const then = false;
    pub const percent = false;
    pub const CONSTRAINT = false;
    pub const CURRENT_TIME = false;
    pub const ROW = false;
    pub const plus = false;
    pub const FAIL = false;
    pub const USING = false;
    pub const NOTNULL = false;
    pub const CAST = false;
    pub const AS = false;
    pub const SELECT = false;
    pub const IN = false;
    pub const END = false;
    pub const COLUMN = false;
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
    pub const LAST = false;
    pub const DETACH = false;
    pub const DROP = false;
    pub const not_equal = false;
    pub const INTO = false;
    pub const CURRENT_TIMESTAMP = false;
    pub const PRECEDING = false;
    pub const RANGE = false;
    pub const REGEXP = false;
    pub const MATERIALIZED = false;
    pub const GENERATED = false;
    pub const string_concat = false;
    pub const OUTER = false;
    pub const AUTOINCREMENT = false;
    pub const CROSS = false;
    pub const CURRENT_DATE = false;
    pub const BEGIN = false;
    pub const ASC = false;
    pub const OR = false;
    pub const EXCEPT = false;
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
    pub const column = false;
    pub const ELSE = false;
    pub const op = false;
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
    expr_incomp_binop,
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
    NOT,
    GLOB,
    bitwise_not,
    ATTACH,
    PRAGMA,
    FILTER,
    THEN,
    WITH,
    UNBOUNDED,
    FOR,
    join_clause,
    expr_incomp_not_binop,
    EXISTS,
    AND,
    double_equal,
    BETWEEN,
    INSERT,
    null_first_or_last,
    shift_left,
    CASCADE,
    INITIALLY,
    CREATE,
    open_paren,
    RECURSIVE,
    greater_than,
    WHEN,
    NOTHING,
    OF,
    semicolon,
    greater_than_equal,
    NULLS,
    DEFERRABLE,
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
    REPLACE,
    shift_right,
    RESTRICT,
    ROLLBACK,
    bitwise_and,
    SET,
    TRANSACTION,
    UNIQUE,
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
    start,
    IS,
    IMMEDIATE,
    SAVEPOINT,
    FOLLOWING,
    RAISE,
    HAVING,
    TEMP,
    end,
    less_than,
    CHECK,
    RETURNING,
    INDEX,
    ISNULL,
    then,
    percent,
    CONSTRAINT,
    CURRENT_TIME,
    ROW,
    plus,
    FAIL,
    USING,
    NOTNULL,
    CAST,
    AS,
    SELECT,
    IN,
    END,
    COLUMN,
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
    LAST,
    DETACH,
    DROP,
    not_equal,
    INTO,
    CURRENT_TIMESTAMP,
    PRECEDING,
    RANGE,
    REGEXP,
    MATERIALIZED,
    GENERATED,
    string_concat,
    OUTER,
    AUTOINCREMENT,
    CROSS,
    CURRENT_DATE,
    BEGIN,
    ASC,
    OR,
    EXCEPT,
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
    column,
    ELSE,
    op,
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
