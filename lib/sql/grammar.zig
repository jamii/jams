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
    anon_4: @field(types, "anon_4"),
    anon_5: @field(types, "anon_5"),
    anon_6: @field(types, "anon_6"),
    anon_7: @field(types, "anon_7"),
    anon_8: @field(types, "anon_8"),
    anon_9: @field(types, "anon_9"),
    anon_10: @field(types, "anon_10"),
    select: @field(types, "select"),
    distinct_or_all: @field(types, "distinct_or_all"),
    anon_13: @field(types, "anon_13"),
    result_columns: @field(types, "result_columns"),
    result_column: @field(types, "result_column"),
    anon_16: @field(types, "anon_16"),
    anon_17: @field(types, "anon_17"),
    result_expr: @field(types, "result_expr"),
    table_star: @field(types, "table_star"),
    anon_20: @field(types, "anon_20"),
    from: @field(types, "from"),
    tables_or_subqueries_or_join: @field(types, "tables_or_subqueries_or_join"),
    anon_23: @field(types, "anon_23"),
    tables_or_subqueries: @field(types, "tables_or_subqueries"),
    table_or_subquery: @field(types, "table_or_subquery"),
    anon_26: @field(types, "anon_26"),
    table: @field(types, "table"),
    binding: @field(types, "binding"),
    join_clause: @field(types, "join_clause"),
    where: @field(types, "where"),
    group_by: @field(types, "group_by"),
    having: @field(types, "having"),
    window: @field(types, "window"),
    order_by: @field(types, "order_by"),
    anon_35: @field(types, "anon_35"),
    ordering_terms: @field(types, "ordering_terms"),
    anon_37: @field(types, "anon_37"),
    anon_38: @field(types, "anon_38"),
    anon_39: @field(types, "anon_39"),
    ordering_term: @field(types, "ordering_term"),
    collate: @field(types, "collate"),
    collation_name: @field(types, "collation_name"),
    asc_or_desc: @field(types, "asc_or_desc"),
    nulls_first_or_last: @field(types, "nulls_first_or_last"),
    first_or_last: @field(types, "first_or_last"),
    limit: @field(types, "limit"),
    anon_47: @field(types, "anon_47"),
    values: @field(types, "values"),
    row: @field(types, "row"),
    create: @field(types, "create"),
    anon_51: @field(types, "anon_51"),
    anon_52: @field(types, "anon_52"),
    create_table: @field(types, "create_table"),
    TEMP_OR_TEMPORARY: @field(types, "TEMP_OR_TEMPORARY"),
    IF_NOT_EXISTS: @field(types, "IF_NOT_EXISTS"),
    table_name: @field(types, "table_name"),
    column_name: @field(types, "column_name"),
    anon_58: @field(types, "anon_58"),
    column_defs: @field(types, "column_defs"),
    anon_60: @field(types, "anon_60"),
    anon_61: @field(types, "anon_61"),
    column_def: @field(types, "column_def"),
    anon_63: @field(types, "anon_63"),
    anon_64: @field(types, "anon_64"),
    anon_65: @field(types, "anon_65"),
    anon_66: @field(types, "anon_66"),
    anon_67: @field(types, "anon_67"),
    create_index: @field(types, "create_index"),
    index_name: @field(types, "index_name"),
    anon_70: @field(types, "anon_70"),
    indexed_column: @field(types, "indexed_column"),
    anon_72: @field(types, "anon_72"),
    anon_73: @field(types, "anon_73"),
    anon_74: @field(types, "anon_74"),
    create_view: @field(types, "create_view"),
    anon_76: @field(types, "anon_76"),
    insert: @field(types, "insert"),
    anon_78: @field(types, "anon_78"),
    column_names: @field(types, "column_names"),
    values_or_select: @field(types, "values_or_select"),
    anon_81: @field(types, "anon_81"),
    typ: @field(types, "typ"),
    anon_83: @field(types, "anon_83"),
    anon_84: @field(types, "anon_84"),
    typ_length: @field(types, "typ_length"),
    column_constraint: @field(types, "column_constraint"),
    anon_87: @field(types, "anon_87"),
    primary_key: @field(types, "primary_key"),
    anon_89: @field(types, "anon_89"),
    anon_90: @field(types, "anon_90"),
    update: @field(types, "update"),
    update_from: @field(types, "update_from"),
    update_where: @field(types, "update_where"),
    anon_94: @field(types, "anon_94"),
    delete: @field(types, "delete"),
    delete_where: @field(types, "delete_where"),
    drop: @field(types, "drop"),
    anon_98: @field(types, "anon_98"),
    drop_table: @field(types, "drop_table"),
    anon_100: @field(types, "anon_100"),
    drop_index: @field(types, "drop_index"),
    anon_102: @field(types, "anon_102"),
    drop_view: @field(types, "drop_view"),
    if_exists: @field(types, "if_exists"),
    anon_105: @field(types, "anon_105"),
    exprs: @field(types, "exprs"),
    expr: @field(types, "expr"),
    anon_108: @field(types, "anon_108"),
    anon_109: @field(types, "anon_109"),
    anon_110: @field(types, "anon_110"),
    expr_or: @field(types, "expr_or"),
    anon_112: @field(types, "anon_112"),
    anon_113: @field(types, "anon_113"),
    anon_114: @field(types, "anon_114"),
    expr_and: @field(types, "expr_and"),
    anon_116: @field(types, "anon_116"),
    expr_not: @field(types, "expr_not"),
    anon_118: @field(types, "anon_118"),
    anon_119: @field(types, "anon_119"),
    expr_incomp: @field(types, "expr_incomp"),
    expr_incomp_right: @field(types, "expr_incomp_right"),
    expr_incomp_binop: @field(types, "expr_incomp_binop"),
    anon_123: @field(types, "anon_123"),
    expr_incomp_in: @field(types, "expr_incomp_in"),
    expr_incomp_in_right: @field(types, "expr_incomp_in_right"),
    anon_126: @field(types, "anon_126"),
    expr_incomp_between: @field(types, "expr_incomp_between"),
    anon_128: @field(types, "anon_128"),
    expr_incomp_postop: @field(types, "expr_incomp_postop"),
    anon_130: @field(types, "anon_130"),
    anon_131: @field(types, "anon_131"),
    anon_132: @field(types, "anon_132"),
    expr_comp: @field(types, "expr_comp"),
    anon_134: @field(types, "anon_134"),
    anon_135: @field(types, "anon_135"),
    anon_136: @field(types, "anon_136"),
    expr_add: @field(types, "expr_add"),
    anon_138: @field(types, "anon_138"),
    anon_139: @field(types, "anon_139"),
    anon_140: @field(types, "anon_140"),
    expr_mult: @field(types, "expr_mult"),
    op_incomp: @field(types, "op_incomp"),
    IS_NOT: @field(types, "IS_NOT"),
    IS_DISTINCT_FROM: @field(types, "IS_DISTINCT_FROM"),
    IS_NOT_DISTINCT_FROM: @field(types, "IS_NOT_DISTINCT_FROM"),
    NOT_IN: @field(types, "NOT_IN"),
    NOT_MATCH: @field(types, "NOT_MATCH"),
    NOT_LIKE: @field(types, "NOT_LIKE"),
    NOT_REGEXP: @field(types, "NOT_REGEXP"),
    NOT_GLOB: @field(types, "NOT_GLOB"),
    op_incomp_post: @field(types, "op_incomp_post"),
    NOT_NULL: @field(types, "NOT_NULL"),
    op_comp: @field(types, "op_comp"),
    op_add: @field(types, "op_add"),
    op_mult: @field(types, "op_mult"),
    expr_atom: @field(types, "expr_atom"),
    column_ref: @field(types, "column_ref"),
    table_column_ref: @field(types, "table_column_ref"),
    anon_159: @field(types, "anon_159"),
    subquery_prefix: @field(types, "subquery_prefix"),
    anon_161: @field(types, "anon_161"),
    subquery: @field(types, "subquery"),
    exists_or_not_exists: @field(types, "exists_or_not_exists"),
    NOT_EXISTS: @field(types, "NOT_EXISTS"),
    subexpr: @field(types, "subexpr"),
    anon_166: @field(types, "anon_166"),
    anon_167: @field(types, "anon_167"),
    anon_168: @field(types, "anon_168"),
    case: @field(types, "case"),
    case_when: @field(types, "case_when"),
    case_else: @field(types, "case_else"),
    anon_172: @field(types, "anon_172"),
    function_call: @field(types, "function_call"),
    function_name: @field(types, "function_name"),
    anon_175: @field(types, "anon_175"),
    anon_176: @field(types, "anon_176"),
    anon_177: @field(types, "anon_177"),
    function_args: @field(types, "function_args"),
    value: @field(types, "value"),
    FROM: @field(types, "FROM"),
    string: @field(types, "string"),
    not_greater_than: @field(types, "not_greater_than"),
    DO: @field(types, "DO"),
    INSTEAD: @field(types, "INSTEAD"),
    TEMPORARY: @field(types, "TEMPORARY"),
    DELETE: @field(types, "DELETE"),
    DISTINCT: @field(types, "DISTINCT"),
    NATURAL: @field(types, "NATURAL"),
    WINDOW: @field(types, "WINDOW"),
    BY: @field(types, "BY"),
    COLLATE: @field(types, "COLLATE"),
    IF: @field(types, "IF"),
    DEFERRED: @field(types, "DEFERRED"),
    ATTACH: @field(types, "ATTACH"),
    PRAGMA: @field(types, "PRAGMA"),
    GLOB: @field(types, "GLOB"),
    NOT: @field(types, "NOT"),
    WHERE: @field(types, "WHERE"),
    bitwise_not: @field(types, "bitwise_not"),
    WITH: @field(types, "WITH"),
    FILTER: @field(types, "FILTER"),
    THEN: @field(types, "THEN"),
    UNBOUNDED: @field(types, "UNBOUNDED"),
    FOR: @field(types, "FOR"),
    EXISTS: @field(types, "EXISTS"),
    shift_left: @field(types, "shift_left"),
    INITIALLY: @field(types, "INITIALLY"),
    AND: @field(types, "AND"),
    double_equal: @field(types, "double_equal"),
    BETWEEN: @field(types, "BETWEEN"),
    CASCADE: @field(types, "CASCADE"),
    INSERT: @field(types, "INSERT"),
    RECURSIVE: @field(types, "RECURSIVE"),
    REPLACE: @field(types, "REPLACE"),
    UNIQUE: @field(types, "UNIQUE"),
    open_paren: @field(types, "open_paren"),
    CREATE: @field(types, "CREATE"),
    greater_than: @field(types, "greater_than"),
    NOTHING: @field(types, "NOTHING"),
    OF: @field(types, "OF"),
    RESTRICT: @field(types, "RESTRICT"),
    semicolon: @field(types, "semicolon"),
    WHEN: @field(types, "WHEN"),
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
    COMMIT: @field(types, "COMMIT"),
    INNER: @field(types, "INNER"),
    EXCLUSIVE: @field(types, "EXCLUSIVE"),
    ADD: @field(types, "ADD"),
    ALL: @field(types, "ALL"),
    ACTION: @field(types, "ACTION"),
    dot: @field(types, "dot"),
    AFTER: @field(types, "AFTER"),
    CONFLICT: @field(types, "CONFLICT"),
    DEFAULT: @field(types, "DEFAULT"),
    VALUES: @field(types, "VALUES"),
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
    CURRENT_TIME: @field(types, "CURRENT_TIME"),
    percent: @field(types, "percent"),
    ISNULL: @field(types, "ISNULL"),
    ROW: @field(types, "ROW"),
    plus: @field(types, "plus"),
    FAIL: @field(types, "FAIL"),
    USING: @field(types, "USING"),
    NOTNULL: @field(types, "NOTNULL"),
    AS: @field(types, "AS"),
    CAST: @field(types, "CAST"),
    COLUMN: @field(types, "COLUMN"),
    IN: @field(types, "IN"),
    END: @field(types, "END"),
    INDEXED: @field(types, "INDEXED"),
    LEFT: @field(types, "LEFT"),
    QUERY: @field(types, "QUERY"),
    SELECT: @field(types, "SELECT"),
    BEFORE: @field(types, "BEFORE"),
    equal: @field(types, "equal"),
    OTHERS: @field(types, "OTHERS"),
    REFERENCES: @field(types, "REFERENCES"),
    ORDER: @field(types, "ORDER"),
    ROWS: @field(types, "ROWS"),
    comma: @field(types, "comma"),
    TIES: @field(types, "TIES"),
    bitwise_or: @field(types, "bitwise_or"),
    ABORT: @field(types, "ABORT"),
    LIMIT: @field(types, "LIMIT"),
    DETACH: @field(types, "DETACH"),
    DROP: @field(types, "DROP"),
    LAST: @field(types, "LAST"),
    not_equal: @field(types, "not_equal"),
    CURRENT_TIMESTAMP: @field(types, "CURRENT_TIMESTAMP"),
    INTO: @field(types, "INTO"),
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
    CURRENT: @field(types, "CURRENT"),
    GROUP: @field(types, "GROUP"),
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
    less_than_or_equal: @field(types, "less_than_or_equal"),
    TABLE: @field(types, "TABLE"),
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
            RuleRef{ .field_name = "SELECT", .rule_name = "SELECT" }, RuleRef{ .field_name = "select", .rule_name = "select" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "VALUES", .rule_name = "VALUES" }, RuleRef{ .field_name = "values", .rule_name = "values" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "CREATE", .rule_name = "CREATE" }, RuleRef{ .field_name = "create", .rule_name = "create" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "INSERT", .rule_name = "INSERT" }, RuleRef{ .field_name = "insert", .rule_name = "insert" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "UPDATE", .rule_name = "UPDATE" }, RuleRef{ .field_name = "update", .rule_name = "update" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "DELETE", .rule_name = "DELETE" }, RuleRef{ .field_name = "delete", .rule_name = "delete" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "DROP", .rule_name = "DROP" }, RuleRef{ .field_name = "drop", .rule_name = "drop" },
        } },
    } };
    pub const anon_3 = Rule{ .optional = RuleRef{ .field_name = "distinct_or_all", .rule_name = "distinct_or_all" } };
    pub const anon_4 = Rule{ .optional = RuleRef{ .field_name = "from", .rule_name = "from" } };
    pub const anon_5 = Rule{ .optional = RuleRef{ .field_name = "where", .rule_name = "where" } };
    pub const anon_6 = Rule{ .optional = RuleRef{ .field_name = "group_by", .rule_name = "group_by" } };
    pub const anon_7 = Rule{ .optional = RuleRef{ .field_name = "having", .rule_name = "having" } };
    pub const anon_8 = Rule{ .optional = RuleRef{ .field_name = "window", .rule_name = "window" } };
    pub const anon_9 = Rule{ .optional = RuleRef{ .field_name = "order_by", .rule_name = "order_by" } };
    pub const anon_10 = Rule{ .optional = RuleRef{ .field_name = "limit", .rule_name = "limit" } };
    pub const select = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "SELECT", .rule_name = "SELECT" },
        RuleRef{ .field_name = "distinct_or_all", .rule_name = "anon_3" },
        RuleRef{ .field_name = "result_columns", .rule_name = "result_columns" },
        RuleRef{ .field_name = "from", .rule_name = "anon_4" },
        RuleRef{ .field_name = "where", .rule_name = "anon_5" },
        RuleRef{ .field_name = "group_by", .rule_name = "anon_6" },
        RuleRef{ .field_name = "having", .rule_name = "anon_7" },
        RuleRef{ .field_name = "window", .rule_name = "anon_8" },
        RuleRef{ .field_name = "order_by", .rule_name = "anon_9" },
        RuleRef{ .field_name = "limit", .rule_name = "anon_10" },
    } };
    pub const distinct_or_all = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "DISTINCT", .rule_name = "DISTINCT" } },
        .{ .choice = RuleRef{ .field_name = "ALL", .rule_name = "ALL" } },
    } };
    pub const anon_13 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "result_column", .rule_name = "result_column" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const result_columns = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "result_column", .rule_name = "anon_13" },
    } };
    pub const result_column = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "result_expr", .rule_name = "result_expr" } },
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
        .{ .choice = RuleRef{ .field_name = "table_star", .rule_name = "table_star" } },
    } };
    pub const anon_16 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "AS", .rule_name = "AS" },
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
    } };
    pub const anon_17 = Rule{ .optional = RuleRef{ .field_name = "anon_16", .rule_name = "anon_16" } };
    pub const result_expr = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
        RuleRef{ .field_name = "anon_16", .rule_name = "anon_17" },
    } };
    pub const table_star = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "dot", .rule_name = "dot" },
        RuleRef{ .field_name = "star", .rule_name = "star" },
    } };
    pub const anon_20 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "tables_or_subqueries_or_join" }, .separator = null } };
    pub const from = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "FROM", .rule_name = "FROM" },
        RuleRef{ .field_name = "tables_or_subqueries_or_join", .rule_name = "anon_20" },
    } };
    pub const tables_or_subqueries_or_join = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "tables_or_subqueries", .rule_name = "tables_or_subqueries" } },
        .{ .choice = RuleRef{ .field_name = "join_clause", .rule_name = "join_clause" } },
    } };
    pub const anon_23 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "table_or_subquery", .rule_name = "table_or_subquery" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const tables_or_subqueries = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_or_subquery", .rule_name = "anon_23" },
    } };
    pub const table_or_subquery = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "table", .rule_name = "table" } },
        .{ .choice = RuleRef{ .field_name = "subquery", .rule_name = "subquery" } },
    } };
    pub const anon_26 = Rule{ .optional = RuleRef{ .field_name = "binding", .rule_name = "binding" } };
    pub const table = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "binding", .rule_name = "anon_26" },
    } };
    pub const binding = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "AS", .rule_name = "AS" },
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const join_clause = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "TODO", .rule_name = "TODO" },
    } };
    pub const where = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WHERE", .rule_name = "WHERE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const group_by = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "GROUP", .rule_name = "GROUP" },
        RuleRef{ .field_name = "BY", .rule_name = "BY" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
    } };
    pub const having = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "HAVING", .rule_name = "HAVING" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const window = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WINDOW", .rule_name = "WINDOW" },
        RuleRef{ .field_name = "TODO", .rule_name = "TODO" },
    } };
    pub const order_by = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "ORDER", .rule_name = "ORDER" },
        RuleRef{ .field_name = "BY", .rule_name = "BY" },
        RuleRef{ .field_name = "ordering_terms", .rule_name = "ordering_terms" },
    } };
    pub const anon_35 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "ordering_term", .rule_name = "ordering_term" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const ordering_terms = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "ordering_term", .rule_name = "anon_35" },
    } };
    pub const anon_37 = Rule{ .optional = RuleRef{ .field_name = "collate", .rule_name = "collate" } };
    pub const anon_38 = Rule{ .optional = RuleRef{ .field_name = "asc_or_desc", .rule_name = "asc_or_desc" } };
    pub const anon_39 = Rule{ .optional = RuleRef{ .field_name = "nulls_first_or_last", .rule_name = "nulls_first_or_last" } };
    pub const ordering_term = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "collate", .rule_name = "anon_37" },
        RuleRef{ .field_name = "asc_or_desc", .rule_name = "anon_38" },
        RuleRef{ .field_name = "nulls_first_or_last", .rule_name = "anon_39" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const collate = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "COLLATE", .rule_name = "COLLATE" },
        RuleRef{ .field_name = "collation_name", .rule_name = "collation_name" },
    } };
    pub const collation_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const asc_or_desc = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "ASC", .rule_name = "ASC" } },
        .{ .choice = RuleRef{ .field_name = "DESC", .rule_name = "DESC" } },
    } };
    pub const nulls_first_or_last = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NULLS", .rule_name = "NULLS" },
        RuleRef{ .field_name = "first_or_last", .rule_name = "first_or_last" },
    } };
    pub const first_or_last = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "FIRST", .rule_name = "FIRST" } },
        .{ .choice = RuleRef{ .field_name = "LAST", .rule_name = "LAST" } },
    } };
    pub const limit = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "LIMIT", .rule_name = "LIMIT" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
    } };
    pub const anon_47 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "row", .rule_name = "row" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const values = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "VALUES", .rule_name = "VALUES" },
        RuleRef{ .field_name = "row", .rule_name = "anon_47" },
    } };
    pub const row = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "exprs", .rule_name = "exprs" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const create = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "create_table", .rule_name = "create_table" } },
        .{ .choice = RuleRef{ .field_name = "create_index", .rule_name = "create_index" } },
        .{ .choice = RuleRef{ .field_name = "create_view", .rule_name = "create_view" } },
    } };
    pub const anon_51 = Rule{ .optional = RuleRef{ .field_name = "TEMP_OR_TEMPORARY", .rule_name = "TEMP_OR_TEMPORARY" } };
    pub const anon_52 = Rule{ .optional = RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "IF_NOT_EXISTS" } };
    pub const create_table = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "CREATE", .rule_name = "CREATE" },
        RuleRef{ .field_name = "TEMP_OR_TEMPORARY", .rule_name = "anon_51" },
        RuleRef{ .field_name = "TABLE", .rule_name = "TABLE" },
        RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "anon_52" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "column_defs", .rule_name = "column_defs" },
    } };
    pub const TEMP_OR_TEMPORARY = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "TEMP", .rule_name = "TEMP" } },
        .{ .choice = RuleRef{ .field_name = "TEMPORARY", .rule_name = "TEMPORARY" } },
    } };
    pub const IF_NOT_EXISTS = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "IF", .rule_name = "IF" },
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "EXISTS", .rule_name = "EXISTS" },
    } };
    pub const table_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const column_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_58 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "column_def", .rule_name = "column_def" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const column_defs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "column_def", .rule_name = "anon_58" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const anon_60 = Rule{ .optional = RuleRef{ .field_name = "typ", .rule_name = "typ" } };
    pub const anon_61 = Rule{ .optional = RuleRef{ .field_name = "column_constraint", .rule_name = "column_constraint" } };
    pub const column_def = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
        RuleRef{ .field_name = "typ", .rule_name = "anon_60" },
        RuleRef{ .field_name = "column_constraint", .rule_name = "anon_61" },
    } };
    pub const anon_63 = Rule{ .optional = RuleRef{ .field_name = "UNIQUE", .rule_name = "UNIQUE" } };
    pub const anon_64 = Rule{ .optional = RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "IF_NOT_EXISTS" } };
    pub const anon_65 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "indexed_column", .rule_name = "indexed_column" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const anon_66 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WHERE", .rule_name = "WHERE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_67 = Rule{ .optional = RuleRef{ .field_name = "anon_66", .rule_name = "anon_66" } };
    pub const create_index = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "CREATE", .rule_name = "CREATE" },
        RuleRef{ .field_name = "UNIQUE", .rule_name = "anon_63" },
        RuleRef{ .field_name = "INDEX", .rule_name = "INDEX" },
        RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "anon_64" },
        RuleRef{ .field_name = "index_name", .rule_name = "index_name" },
        RuleRef{ .field_name = "ON", .rule_name = "ON" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "indexed_column", .rule_name = "anon_65" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
        RuleRef{ .field_name = "anon_66", .rule_name = "anon_67" },
    } };
    pub const index_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
    } };
    pub const anon_70 = Rule{ .optional = RuleRef{ .field_name = "asc_or_desc", .rule_name = "asc_or_desc" } };
    pub const indexed_column = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
        RuleRef{ .field_name = "asc_or_desc", .rule_name = "anon_70" },
    } };
    pub const anon_72 = Rule{ .optional = RuleRef{ .field_name = "TEMP_OR_TEMPORARY", .rule_name = "TEMP_OR_TEMPORARY" } };
    pub const anon_73 = Rule{ .optional = RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "IF_NOT_EXISTS" } };
    pub const anon_74 = Rule{ .optional = RuleRef{ .field_name = "column_defs", .rule_name = "column_defs" } };
    pub const create_view = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "CREATE", .rule_name = "CREATE" },
        RuleRef{ .field_name = "TEMP_OR_TEMPORARY", .rule_name = "anon_72" },
        RuleRef{ .field_name = "VIEW", .rule_name = "VIEW" },
        RuleRef{ .field_name = "IF_NOT_EXISTS", .rule_name = "anon_73" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "column_defs", .rule_name = "anon_74" },
        RuleRef{ .field_name = "AS", .rule_name = "AS" },
        RuleRef{ .field_name = "select", .rule_name = "select" },
    } };
    pub const anon_76 = Rule{ .optional = RuleRef{ .field_name = "column_names", .rule_name = "column_names" } };
    pub const insert = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "INSERT", .rule_name = "INSERT" },
        RuleRef{ .field_name = "INTO", .rule_name = "INTO" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "column_names", .rule_name = "anon_76" },
        RuleRef{ .field_name = "values_or_select", .rule_name = "values_or_select" },
    } };
    pub const anon_78 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "column_name", .rule_name = "column_name" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const column_names = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "column_name", .rule_name = "anon_78" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const values_or_select = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = "VALUES", .rule_name = "VALUES" }, RuleRef{ .field_name = "values", .rule_name = "values" },
        } },
        .{ .choice = RuleRef{ .field_name = "select", .rule_name = "select" } },
    } };
    pub const anon_81 = Rule{ .optional = RuleRef{ .field_name = "typ_length", .rule_name = "typ_length" } };
    pub const typ = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
        RuleRef{ .field_name = "typ_length", .rule_name = "anon_81" },
    } };
    pub const anon_83 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "comma", .rule_name = "comma" },
        RuleRef{ .field_name = "number", .rule_name = "number" },
    } };
    pub const anon_84 = Rule{ .optional = RuleRef{ .field_name = "anon_83", .rule_name = "anon_83" } };
    pub const typ_length = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "number", .rule_name = "number" },
        RuleRef{ .field_name = "anon_83", .rule_name = "anon_84" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const column_constraint = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "primary_key", .rule_name = "primary_key" } },
    } };
    pub const anon_87 = Rule{ .optional = RuleRef{ .field_name = "asc_or_desc", .rule_name = "asc_or_desc" } };
    pub const primary_key = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "PRIMARY", .rule_name = "PRIMARY" },
        RuleRef{ .field_name = "KEY", .rule_name = "KEY" },
        RuleRef{ .field_name = "asc_or_desc", .rule_name = "anon_87" },
    } };
    pub const anon_89 = Rule{ .optional = RuleRef{ .field_name = "update_from", .rule_name = "update_from" } };
    pub const anon_90 = Rule{ .optional = RuleRef{ .field_name = "update_where", .rule_name = "update_where" } };
    pub const update = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "UPDATE", .rule_name = "UPDATE" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "SET", .rule_name = "SET" },
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
        RuleRef{ .field_name = "equal", .rule_name = "equal" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
        RuleRef{ .field_name = "update_from", .rule_name = "anon_89" },
        RuleRef{ .field_name = "update_where", .rule_name = "anon_90" },
    } };
    pub const update_from = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "TODO", .rule_name = "TODO" },
    } };
    pub const update_where = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WHERE", .rule_name = "WHERE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_94 = Rule{ .optional = RuleRef{ .field_name = "delete_where", .rule_name = "delete_where" } };
    pub const delete = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "DELETE", .rule_name = "DELETE" },
        RuleRef{ .field_name = "FROM", .rule_name = "FROM" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "delete_where", .rule_name = "anon_94" },
    } };
    pub const delete_where = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WHERE", .rule_name = "WHERE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const drop = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "drop_table", .rule_name = "drop_table" } },
        .{ .choice = RuleRef{ .field_name = "drop_index", .rule_name = "drop_index" } },
        .{ .choice = RuleRef{ .field_name = "drop_view", .rule_name = "drop_view" } },
    } };
    pub const anon_98 = Rule{ .optional = RuleRef{ .field_name = "if_exists", .rule_name = "if_exists" } };
    pub const drop_table = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "DROP", .rule_name = "DROP" },
        RuleRef{ .field_name = "TABLE", .rule_name = "TABLE" },
        RuleRef{ .field_name = "if_exists", .rule_name = "anon_98" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
    } };
    pub const anon_100 = Rule{ .optional = RuleRef{ .field_name = "if_exists", .rule_name = "if_exists" } };
    pub const drop_index = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "DROP", .rule_name = "DROP" },
        RuleRef{ .field_name = "INDEX", .rule_name = "INDEX" },
        RuleRef{ .field_name = "if_exists", .rule_name = "anon_100" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
    } };
    pub const anon_102 = Rule{ .optional = RuleRef{ .field_name = "if_exists", .rule_name = "if_exists" } };
    pub const drop_view = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "DROP", .rule_name = "DROP" },
        RuleRef{ .field_name = "VIEW", .rule_name = "VIEW" },
        RuleRef{ .field_name = "if_exists", .rule_name = "anon_102" },
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
    } };
    pub const if_exists = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "IF", .rule_name = "IF" },
        RuleRef{ .field_name = "EXISTS", .rule_name = "EXISTS" },
    } };
    pub const anon_105 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const exprs = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr", .rule_name = "anon_105" },
    } };
    pub const expr = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr_or", .rule_name = "expr_or" },
    } };
    pub const anon_108 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "OR", .rule_name = "OR" },
        RuleRef{ .field_name = "expr_or", .rule_name = "expr_or" },
    } };
    pub const anon_109 = Rule{ .optional = RuleRef{ .field_name = "anon_108", .rule_name = "anon_108" } };
    pub const anon_110 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "anon_108", .rule_name = "anon_109" },
    } };
    pub const expr_or = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_and" },
        RuleRef{ .field_name = "right", .rule_name = "anon_110" },
    } };
    pub const anon_112 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "AND", .rule_name = "AND" },
        RuleRef{ .field_name = "expr_and", .rule_name = "expr_and" },
    } };
    pub const anon_113 = Rule{ .optional = RuleRef{ .field_name = "anon_112", .rule_name = "anon_112" } };
    pub const anon_114 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "anon_112", .rule_name = "anon_113" },
    } };
    pub const expr_and = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_not" },
        RuleRef{ .field_name = "right", .rule_name = "anon_114" },
    } };
    pub const anon_116 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "NOT", .rule_name = "NOT" }, .separator = null } };
    pub const expr_not = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "anon_116" },
        RuleRef{ .field_name = "expr_incomp", .rule_name = "expr_incomp" },
    } };
    pub const anon_118 = Rule{ .optional = RuleRef{ .field_name = "expr_incomp_right", .rule_name = "expr_incomp_right" } };
    pub const anon_119 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "expr_incomp_right", .rule_name = "anon_118" },
    } };
    pub const expr_incomp = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_comp" },
        RuleRef{ .field_name = "right", .rule_name = "anon_119" },
    } };
    pub const expr_incomp_right = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "expr_incomp_binop", .rule_name = "expr_incomp_binop" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_in", .rule_name = "expr_incomp_in" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_between", .rule_name = "expr_incomp_between" } },
        .{ .choice = RuleRef{ .field_name = "expr_incomp_postop", .rule_name = "expr_incomp_postop" } },
    } };
    pub const expr_incomp_binop = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "op", .rule_name = "op_incomp" },
        RuleRef{ .field_name = "right", .rule_name = "expr_incomp" },
    } };
    pub const anon_123 = Rule{ .optional = RuleRef{ .field_name = "NOT", .rule_name = "NOT" } };
    pub const expr_incomp_in = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "anon_123" },
        RuleRef{ .field_name = "IN", .rule_name = "IN" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "right", .rule_name = "expr_incomp_in_right" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const expr_incomp_in_right = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "exprs", .rule_name = "exprs" } },
        .{ .choice = RuleRef{ .field_name = "select", .rule_name = "select" } },
    } };
    pub const anon_126 = Rule{ .optional = RuleRef{ .field_name = "NOT", .rule_name = "NOT" } };
    pub const expr_incomp_between = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "anon_126" },
        RuleRef{ .field_name = "BETWEEN", .rule_name = "BETWEEN" },
        RuleRef{ .field_name = "start", .rule_name = "expr_comp" },
        RuleRef{ .field_name = "AND", .rule_name = "AND" },
        RuleRef{ .field_name = "end", .rule_name = "expr_incomp" },
    } };
    pub const anon_128 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "op_incomp_post", .rule_name = "op_incomp_post" }, .separator = null } };
    pub const expr_incomp_postop = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "op_incomp_post", .rule_name = "anon_128" },
    } };
    pub const anon_130 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "op", .rule_name = "op_comp" },
        RuleRef{ .field_name = "expr_comp", .rule_name = "expr_comp" },
    } };
    pub const anon_131 = Rule{ .optional = RuleRef{ .field_name = "anon_130", .rule_name = "anon_130" } };
    pub const anon_132 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "anon_130", .rule_name = "anon_131" },
    } };
    pub const expr_comp = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_add" },
        RuleRef{ .field_name = "right", .rule_name = "anon_132" },
    } };
    pub const anon_134 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "op", .rule_name = "op_add" },
        RuleRef{ .field_name = "expr_add", .rule_name = "expr_add" },
    } };
    pub const anon_135 = Rule{ .optional = RuleRef{ .field_name = "anon_134", .rule_name = "anon_134" } };
    pub const anon_136 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "anon_134", .rule_name = "anon_135" },
    } };
    pub const expr_add = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_mult" },
        RuleRef{ .field_name = "right", .rule_name = "anon_136" },
    } };
    pub const anon_138 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "op", .rule_name = "op_mult" },
        RuleRef{ .field_name = "expr_atom", .rule_name = "expr_atom" },
    } };
    pub const anon_139 = Rule{ .optional = RuleRef{ .field_name = "anon_138", .rule_name = "anon_138" } };
    pub const anon_140 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "anon_138", .rule_name = "anon_139" },
    } };
    pub const expr_mult = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "left", .rule_name = "expr_atom" },
        RuleRef{ .field_name = "right", .rule_name = "anon_140" },
    } };
    pub const op_incomp = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "equal", .rule_name = "equal" } },
        .{ .choice = RuleRef{ .field_name = "double_equal", .rule_name = "double_equal" } },
        .{ .choice = RuleRef{ .field_name = "not_equal", .rule_name = "not_equal" } },
        .{ .choice = RuleRef{ .field_name = "IS", .rule_name = "IS" } },
        .{ .choice = RuleRef{ .field_name = "IS_NOT", .rule_name = "IS_NOT" } },
        .{ .choice = RuleRef{ .field_name = "IS_DISTINCT_FROM", .rule_name = "IS_DISTINCT_FROM" } },
        .{ .choice = RuleRef{ .field_name = "IS_NOT_DISTINCT_FROM", .rule_name = "IS_NOT_DISTINCT_FROM" } },
        .{ .choice = RuleRef{ .field_name = "IN", .rule_name = "IN" } },
        .{ .choice = RuleRef{ .field_name = "MATCH", .rule_name = "MATCH" } },
        .{ .choice = RuleRef{ .field_name = "LIKE", .rule_name = "LIKE" } },
        .{ .choice = RuleRef{ .field_name = "REGEXP", .rule_name = "REGEXP" } },
        .{ .choice = RuleRef{ .field_name = "GLOB", .rule_name = "GLOB" } },
        .{ .choice = RuleRef{ .field_name = "NOT_IN", .rule_name = "NOT_IN" } },
        .{ .choice = RuleRef{ .field_name = "NOT_MATCH", .rule_name = "NOT_MATCH" } },
        .{ .choice = RuleRef{ .field_name = "NOT_LIKE", .rule_name = "NOT_LIKE" } },
        .{ .choice = RuleRef{ .field_name = "NOT_REGEXP", .rule_name = "NOT_REGEXP" } },
        .{ .choice = RuleRef{ .field_name = "NOT_GLOB", .rule_name = "NOT_GLOB" } },
    } };
    pub const IS_NOT = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "IS", .rule_name = "IS" },
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
    } };
    pub const IS_DISTINCT_FROM = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "IS", .rule_name = "IS" },
        RuleRef{ .field_name = "DISTINCT", .rule_name = "DISTINCT" },
        RuleRef{ .field_name = "FROM", .rule_name = "FROM" },
    } };
    pub const IS_NOT_DISTINCT_FROM = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "IS", .rule_name = "IS" },
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "DISTINCT", .rule_name = "DISTINCT" },
        RuleRef{ .field_name = "FROM", .rule_name = "FROM" },
    } };
    pub const NOT_IN = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "IN", .rule_name = "IN" },
    } };
    pub const NOT_MATCH = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "MATCH", .rule_name = "MATCH" },
    } };
    pub const NOT_LIKE = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "LIKE", .rule_name = "LIKE" },
    } };
    pub const NOT_REGEXP = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "REGEXP", .rule_name = "REGEXP" },
    } };
    pub const NOT_GLOB = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "GLOB", .rule_name = "GLOB" },
    } };
    pub const op_incomp_post = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "ISNULL", .rule_name = "ISNULL" } },
        .{ .choice = RuleRef{ .field_name = "NOTNULL", .rule_name = "NOTNULL" } },
        .{ .choice = RuleRef{ .field_name = "NOT_NULL", .rule_name = "NOT_NULL" } },
    } };
    pub const NOT_NULL = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "NULL", .rule_name = "NULL" },
    } };
    pub const op_comp = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "less_than", .rule_name = "less_than" } },
        .{ .choice = RuleRef{ .field_name = "greater_than", .rule_name = "greater_than" } },
        .{ .choice = RuleRef{ .field_name = "less_than_or_equal", .rule_name = "less_than_or_equal" } },
        .{ .choice = RuleRef{ .field_name = "greater_than_or_equal", .rule_name = "greater_than_or_equal" } },
    } };
    pub const op_add = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "plus", .rule_name = "plus" } },
        .{ .choice = RuleRef{ .field_name = "minus", .rule_name = "minus" } },
    } };
    pub const op_mult = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
        .{ .choice = RuleRef{ .field_name = "forward_slash", .rule_name = "forward_slash" } },
        .{ .choice = RuleRef{ .field_name = "percent", .rule_name = "percent" } },
    } };
    pub const expr_atom = Rule{ .one_of = &[_]OneOf{
        .{ .committed_choice = .{
            RuleRef{ .field_name = "CASE", .rule_name = "CASE" }, RuleRef{ .field_name = "case", .rule_name = "case" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "subquery_prefix", .rule_name = "subquery_prefix" }, RuleRef{ .field_name = "subquery", .rule_name = "subquery" },
        } },
        .{ .committed_choice = .{
            RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" }, RuleRef{ .field_name = "subexpr", .rule_name = "subexpr" },
        } },
        .{ .choice = RuleRef{ .field_name = "function_call", .rule_name = "function_call" } },
        .{ .choice = RuleRef{ .field_name = "table_column_ref", .rule_name = "table_column_ref" } },
        .{ .choice = RuleRef{ .field_name = "column_ref", .rule_name = "column_ref" } },
        .{ .choice = RuleRef{ .field_name = "value", .rule_name = "value" } },
    } };
    pub const column_ref = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
    } };
    pub const table_column_ref = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "table_name", .rule_name = "table_name" },
        RuleRef{ .field_name = "dot", .rule_name = "dot" },
        RuleRef{ .field_name = "column_name", .rule_name = "column_name" },
    } };
    pub const anon_159 = Rule{ .optional = RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "exists_or_not_exists" } };
    pub const subquery_prefix = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "anon_159" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "SELECT", .rule_name = "SELECT" },
    } };
    pub const anon_161 = Rule{ .optional = RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "exists_or_not_exists" } };
    pub const subquery = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "exists_or_not_exists", .rule_name = "anon_161" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "select", .rule_name = "select" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const exists_or_not_exists = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "EXISTS", .rule_name = "EXISTS" } },
        .{ .choice = RuleRef{ .field_name = "NOT_EXISTS", .rule_name = "NOT_EXISTS" } },
    } };
    pub const NOT_EXISTS = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "NOT", .rule_name = "NOT" },
        RuleRef{ .field_name = "EXISTS", .rule_name = "EXISTS" },
    } };
    pub const subexpr = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const anon_166 = Rule{ .optional = RuleRef{ .field_name = "expr", .rule_name = "expr" } };
    pub const anon_167 = Rule{ .repeat = .{ .min_count = 0, .element = RuleRef{ .field_name = "case_when", .rule_name = "case_when" }, .separator = null } };
    pub const anon_168 = Rule{ .optional = RuleRef{ .field_name = "case_else", .rule_name = "case_else" } };
    pub const case = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "CASE", .rule_name = "CASE" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_166" },
        RuleRef{ .field_name = "case_when", .rule_name = "anon_167" },
        RuleRef{ .field_name = "case_else", .rule_name = "anon_168" },
        RuleRef{ .field_name = "END", .rule_name = "END" },
    } };
    pub const case_when = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "WHEN", .rule_name = "WHEN" },
        RuleRef{ .field_name = "when", .rule_name = "expr" },
        RuleRef{ .field_name = "THEN", .rule_name = "THEN" },
        RuleRef{ .field_name = "then", .rule_name = "expr" },
    } };
    pub const case_else = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "ELSE", .rule_name = "ELSE" },
        RuleRef{ .field_name = "expr", .rule_name = "expr" },
    } };
    pub const anon_172 = Rule{ .optional = RuleRef{ .field_name = "function_args", .rule_name = "function_args" } };
    pub const function_call = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "function_name", .rule_name = "function_name" },
        RuleRef{ .field_name = "open_paren", .rule_name = "open_paren" },
        RuleRef{ .field_name = "function_args", .rule_name = "anon_172" },
        RuleRef{ .field_name = "close_paren", .rule_name = "close_paren" },
    } };
    pub const function_name = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "name", .rule_name = "name" },
    } };
    pub const anon_175 = Rule{ .optional = RuleRef{ .field_name = "DISTINCT", .rule_name = "DISTINCT" } };
    pub const anon_176 = Rule{ .repeat = .{ .min_count = 1, .element = RuleRef{ .field_name = "expr", .rule_name = "expr" }, .separator = RuleRef{ .field_name = "comma", .rule_name = "comma" } } };
    pub const anon_177 = Rule{ .all_of = &[_]RuleRef{
        RuleRef{ .field_name = "DISTINCT", .rule_name = "anon_175" },
        RuleRef{ .field_name = "expr", .rule_name = "anon_176" },
    } };
    pub const function_args = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "args", .rule_name = "anon_177" } },
        .{ .choice = RuleRef{ .field_name = "star", .rule_name = "star" } },
    } };
    pub const value = Rule{ .one_of = &[_]OneOf{
        .{ .choice = RuleRef{ .field_name = "number", .rule_name = "number" } },
        .{ .choice = RuleRef{ .field_name = "string", .rule_name = "string" } },
        .{ .choice = RuleRef{ .field_name = "NULL", .rule_name = "NULL" } },
    } };
    pub const FROM = Rule{ .token = .FROM };
    pub const string = Rule{ .token = .string };
    pub const not_greater_than = Rule{ .token = .not_greater_than };
    pub const DO = Rule{ .token = .DO };
    pub const INSTEAD = Rule{ .token = .INSTEAD };
    pub const TEMPORARY = Rule{ .token = .TEMPORARY };
    pub const DELETE = Rule{ .token = .DELETE };
    pub const DISTINCT = Rule{ .token = .DISTINCT };
    pub const NATURAL = Rule{ .token = .NATURAL };
    pub const WINDOW = Rule{ .token = .WINDOW };
    pub const BY = Rule{ .token = .BY };
    pub const COLLATE = Rule{ .token = .COLLATE };
    pub const IF = Rule{ .token = .IF };
    pub const DEFERRED = Rule{ .token = .DEFERRED };
    pub const ATTACH = Rule{ .token = .ATTACH };
    pub const PRAGMA = Rule{ .token = .PRAGMA };
    pub const GLOB = Rule{ .token = .GLOB };
    pub const NOT = Rule{ .token = .NOT };
    pub const WHERE = Rule{ .token = .WHERE };
    pub const bitwise_not = Rule{ .token = .bitwise_not };
    pub const WITH = Rule{ .token = .WITH };
    pub const FILTER = Rule{ .token = .FILTER };
    pub const THEN = Rule{ .token = .THEN };
    pub const UNBOUNDED = Rule{ .token = .UNBOUNDED };
    pub const FOR = Rule{ .token = .FOR };
    pub const EXISTS = Rule{ .token = .EXISTS };
    pub const shift_left = Rule{ .token = .shift_left };
    pub const INITIALLY = Rule{ .token = .INITIALLY };
    pub const AND = Rule{ .token = .AND };
    pub const double_equal = Rule{ .token = .double_equal };
    pub const BETWEEN = Rule{ .token = .BETWEEN };
    pub const CASCADE = Rule{ .token = .CASCADE };
    pub const INSERT = Rule{ .token = .INSERT };
    pub const RECURSIVE = Rule{ .token = .RECURSIVE };
    pub const REPLACE = Rule{ .token = .REPLACE };
    pub const UNIQUE = Rule{ .token = .UNIQUE };
    pub const open_paren = Rule{ .token = .open_paren };
    pub const CREATE = Rule{ .token = .CREATE };
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
    pub const INNER = Rule{ .token = .INNER };
    pub const EXCLUSIVE = Rule{ .token = .EXCLUSIVE };
    pub const ADD = Rule{ .token = .ADD };
    pub const ALL = Rule{ .token = .ALL };
    pub const ACTION = Rule{ .token = .ACTION };
    pub const dot = Rule{ .token = .dot };
    pub const AFTER = Rule{ .token = .AFTER };
    pub const CONFLICT = Rule{ .token = .CONFLICT };
    pub const DEFAULT = Rule{ .token = .DEFAULT };
    pub const VALUES = Rule{ .token = .VALUES };
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
    pub const percent = Rule{ .token = .percent };
    pub const ISNULL = Rule{ .token = .ISNULL };
    pub const ROW = Rule{ .token = .ROW };
    pub const plus = Rule{ .token = .plus };
    pub const FAIL = Rule{ .token = .FAIL };
    pub const USING = Rule{ .token = .USING };
    pub const NOTNULL = Rule{ .token = .NOTNULL };
    pub const AS = Rule{ .token = .AS };
    pub const CAST = Rule{ .token = .CAST };
    pub const COLUMN = Rule{ .token = .COLUMN };
    pub const IN = Rule{ .token = .IN };
    pub const END = Rule{ .token = .END };
    pub const INDEXED = Rule{ .token = .INDEXED };
    pub const LEFT = Rule{ .token = .LEFT };
    pub const QUERY = Rule{ .token = .QUERY };
    pub const SELECT = Rule{ .token = .SELECT };
    pub const BEFORE = Rule{ .token = .BEFORE };
    pub const equal = Rule{ .token = .equal };
    pub const OTHERS = Rule{ .token = .OTHERS };
    pub const REFERENCES = Rule{ .token = .REFERENCES };
    pub const ORDER = Rule{ .token = .ORDER };
    pub const ROWS = Rule{ .token = .ROWS };
    pub const comma = Rule{ .token = .comma };
    pub const TIES = Rule{ .token = .TIES };
    pub const bitwise_or = Rule{ .token = .bitwise_or };
    pub const ABORT = Rule{ .token = .ABORT };
    pub const LIMIT = Rule{ .token = .LIMIT };
    pub const DETACH = Rule{ .token = .DETACH };
    pub const DROP = Rule{ .token = .DROP };
    pub const LAST = Rule{ .token = .LAST };
    pub const not_equal = Rule{ .token = .not_equal };
    pub const CURRENT_TIMESTAMP = Rule{ .token = .CURRENT_TIMESTAMP };
    pub const INTO = Rule{ .token = .INTO };
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
    pub const CURRENT = Rule{ .token = .CURRENT };
    pub const GROUP = Rule{ .token = .GROUP };
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
    pub const less_than_or_equal = Rule{ .token = .less_than_or_equal };
    pub const TABLE = Rule{ .token = .TABLE };
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
        update: sql.Parser.NodeId("update"),
        delete: sql.Parser.NodeId("delete"),
        drop: sql.Parser.NodeId("drop"),
    };
    pub const anon_3 = ?sql.Parser.NodeId("distinct_or_all");
    pub const anon_4 = ?sql.Parser.NodeId("from");
    pub const anon_5 = ?sql.Parser.NodeId("where");
    pub const anon_6 = ?sql.Parser.NodeId("group_by");
    pub const anon_7 = ?sql.Parser.NodeId("having");
    pub const anon_8 = ?sql.Parser.NodeId("window");
    pub const anon_9 = ?sql.Parser.NodeId("order_by");
    pub const anon_10 = ?sql.Parser.NodeId("limit");
    pub const select = struct {
        SELECT: sql.Parser.NodeId("SELECT"),
        distinct_or_all: sql.Parser.NodeId("anon_3"),
        result_columns: sql.Parser.NodeId("result_columns"),
        from: sql.Parser.NodeId("anon_4"),
        where: sql.Parser.NodeId("anon_5"),
        group_by: sql.Parser.NodeId("anon_6"),
        having: sql.Parser.NodeId("anon_7"),
        window: sql.Parser.NodeId("anon_8"),
        order_by: sql.Parser.NodeId("anon_9"),
        limit: sql.Parser.NodeId("anon_10"),
    };
    pub const distinct_or_all = union(enum) {
        DISTINCT: sql.Parser.NodeId("DISTINCT"),
        ALL: sql.Parser.NodeId("ALL"),
    };
    pub const anon_13 = []const sql.Parser.NodeId("result_column");
    pub const result_columns = struct {
        result_column: sql.Parser.NodeId("anon_13"),
    };
    pub const result_column = union(enum) {
        result_expr: sql.Parser.NodeId("result_expr"),
        star: sql.Parser.NodeId("star"),
        table_star: sql.Parser.NodeId("table_star"),
    };
    pub const anon_16 = struct {
        AS: sql.Parser.NodeId("AS"),
        column_name: sql.Parser.NodeId("column_name"),
    };
    pub const anon_17 = ?sql.Parser.NodeId("anon_16");
    pub const result_expr = struct {
        expr: sql.Parser.NodeId("expr"),
        anon_16: sql.Parser.NodeId("anon_17"),
    };
    pub const table_star = struct {
        table_name: sql.Parser.NodeId("table_name"),
        dot: sql.Parser.NodeId("dot"),
        star: sql.Parser.NodeId("star"),
    };
    pub const anon_20 = []const sql.Parser.NodeId("tables_or_subqueries_or_join");
    pub const from = struct {
        FROM: sql.Parser.NodeId("FROM"),
        tables_or_subqueries_or_join: sql.Parser.NodeId("anon_20"),
    };
    pub const tables_or_subqueries_or_join = union(enum) {
        tables_or_subqueries: sql.Parser.NodeId("tables_or_subqueries"),
        join_clause: sql.Parser.NodeId("join_clause"),
    };
    pub const anon_23 = []const sql.Parser.NodeId("table_or_subquery");
    pub const tables_or_subqueries = struct {
        table_or_subquery: sql.Parser.NodeId("anon_23"),
    };
    pub const table_or_subquery = union(enum) {
        table: sql.Parser.NodeId("table"),
        subquery: sql.Parser.NodeId("subquery"),
    };
    pub const anon_26 = ?sql.Parser.NodeId("binding");
    pub const table = struct {
        name: sql.Parser.NodeId("name"),
        binding: sql.Parser.NodeId("anon_26"),
    };
    pub const binding = struct {
        AS: sql.Parser.NodeId("AS"),
        name: sql.Parser.NodeId("name"),
    };
    pub const join_clause = struct {
        TODO: sql.Parser.NodeId("TODO"),
    };
    pub const where = struct {
        WHERE: sql.Parser.NodeId("WHERE"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const group_by = struct {
        GROUP: sql.Parser.NodeId("GROUP"),
        BY: sql.Parser.NodeId("BY"),
        exprs: sql.Parser.NodeId("exprs"),
    };
    pub const having = struct {
        HAVING: sql.Parser.NodeId("HAVING"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const window = struct {
        WINDOW: sql.Parser.NodeId("WINDOW"),
        TODO: sql.Parser.NodeId("TODO"),
    };
    pub const order_by = struct {
        ORDER: sql.Parser.NodeId("ORDER"),
        BY: sql.Parser.NodeId("BY"),
        ordering_terms: sql.Parser.NodeId("ordering_terms"),
    };
    pub const anon_35 = []const sql.Parser.NodeId("ordering_term");
    pub const ordering_terms = struct {
        ordering_term: sql.Parser.NodeId("anon_35"),
    };
    pub const anon_37 = ?sql.Parser.NodeId("collate");
    pub const anon_38 = ?sql.Parser.NodeId("asc_or_desc");
    pub const anon_39 = ?sql.Parser.NodeId("nulls_first_or_last");
    pub const ordering_term = struct {
        collate: sql.Parser.NodeId("anon_37"),
        asc_or_desc: sql.Parser.NodeId("anon_38"),
        nulls_first_or_last: sql.Parser.NodeId("anon_39"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const collate = struct {
        COLLATE: sql.Parser.NodeId("COLLATE"),
        collation_name: sql.Parser.NodeId("collation_name"),
    };
    pub const collation_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const asc_or_desc = union(enum) {
        ASC: sql.Parser.NodeId("ASC"),
        DESC: sql.Parser.NodeId("DESC"),
    };
    pub const nulls_first_or_last = struct {
        NULLS: sql.Parser.NodeId("NULLS"),
        first_or_last: sql.Parser.NodeId("first_or_last"),
    };
    pub const first_or_last = union(enum) {
        FIRST: sql.Parser.NodeId("FIRST"),
        LAST: sql.Parser.NodeId("LAST"),
    };
    pub const limit = struct {
        LIMIT: sql.Parser.NodeId("LIMIT"),
        exprs: sql.Parser.NodeId("exprs"),
    };
    pub const anon_47 = []const sql.Parser.NodeId("row");
    pub const values = struct {
        VALUES: sql.Parser.NodeId("VALUES"),
        row: sql.Parser.NodeId("anon_47"),
    };
    pub const row = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        exprs: sql.Parser.NodeId("exprs"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const create = union(enum) {
        create_table: sql.Parser.NodeId("create_table"),
        create_index: sql.Parser.NodeId("create_index"),
        create_view: sql.Parser.NodeId("create_view"),
    };
    pub const anon_51 = ?sql.Parser.NodeId("TEMP_OR_TEMPORARY");
    pub const anon_52 = ?sql.Parser.NodeId("IF_NOT_EXISTS");
    pub const create_table = struct {
        CREATE: sql.Parser.NodeId("CREATE"),
        TEMP_OR_TEMPORARY: sql.Parser.NodeId("anon_51"),
        TABLE: sql.Parser.NodeId("TABLE"),
        IF_NOT_EXISTS: sql.Parser.NodeId("anon_52"),
        table_name: sql.Parser.NodeId("table_name"),
        column_defs: sql.Parser.NodeId("column_defs"),
    };
    pub const TEMP_OR_TEMPORARY = union(enum) {
        TEMP: sql.Parser.NodeId("TEMP"),
        TEMPORARY: sql.Parser.NodeId("TEMPORARY"),
    };
    pub const IF_NOT_EXISTS = struct {
        IF: sql.Parser.NodeId("IF"),
        NOT: sql.Parser.NodeId("NOT"),
        EXISTS: sql.Parser.NodeId("EXISTS"),
    };
    pub const table_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const column_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const anon_58 = []const sql.Parser.NodeId("column_def");
    pub const column_defs = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        column_def: sql.Parser.NodeId("anon_58"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const anon_60 = ?sql.Parser.NodeId("typ");
    pub const anon_61 = ?sql.Parser.NodeId("column_constraint");
    pub const column_def = struct {
        column_name: sql.Parser.NodeId("column_name"),
        typ: sql.Parser.NodeId("anon_60"),
        column_constraint: sql.Parser.NodeId("anon_61"),
    };
    pub const anon_63 = ?sql.Parser.NodeId("UNIQUE");
    pub const anon_64 = ?sql.Parser.NodeId("IF_NOT_EXISTS");
    pub const anon_65 = []const sql.Parser.NodeId("indexed_column");
    pub const anon_66 = struct {
        WHERE: sql.Parser.NodeId("WHERE"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_67 = ?sql.Parser.NodeId("anon_66");
    pub const create_index = struct {
        CREATE: sql.Parser.NodeId("CREATE"),
        UNIQUE: sql.Parser.NodeId("anon_63"),
        INDEX: sql.Parser.NodeId("INDEX"),
        IF_NOT_EXISTS: sql.Parser.NodeId("anon_64"),
        index_name: sql.Parser.NodeId("index_name"),
        ON: sql.Parser.NodeId("ON"),
        table_name: sql.Parser.NodeId("table_name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        indexed_column: sql.Parser.NodeId("anon_65"),
        close_paren: sql.Parser.NodeId("close_paren"),
        anon_66: sql.Parser.NodeId("anon_67"),
    };
    pub const index_name = struct {
        table_name: sql.Parser.NodeId("table_name"),
    };
    pub const anon_70 = ?sql.Parser.NodeId("asc_or_desc");
    pub const indexed_column = struct {
        column_name: sql.Parser.NodeId("column_name"),
        asc_or_desc: sql.Parser.NodeId("anon_70"),
    };
    pub const anon_72 = ?sql.Parser.NodeId("TEMP_OR_TEMPORARY");
    pub const anon_73 = ?sql.Parser.NodeId("IF_NOT_EXISTS");
    pub const anon_74 = ?sql.Parser.NodeId("column_defs");
    pub const create_view = struct {
        CREATE: sql.Parser.NodeId("CREATE"),
        TEMP_OR_TEMPORARY: sql.Parser.NodeId("anon_72"),
        VIEW: sql.Parser.NodeId("VIEW"),
        IF_NOT_EXISTS: sql.Parser.NodeId("anon_73"),
        table_name: sql.Parser.NodeId("table_name"),
        column_defs: sql.Parser.NodeId("anon_74"),
        AS: sql.Parser.NodeId("AS"),
        select: sql.Parser.NodeId("select"),
    };
    pub const anon_76 = ?sql.Parser.NodeId("column_names");
    pub const insert = struct {
        INSERT: sql.Parser.NodeId("INSERT"),
        INTO: sql.Parser.NodeId("INTO"),
        table_name: sql.Parser.NodeId("table_name"),
        column_names: sql.Parser.NodeId("anon_76"),
        values_or_select: sql.Parser.NodeId("values_or_select"),
    };
    pub const anon_78 = []const sql.Parser.NodeId("column_name");
    pub const column_names = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        column_name: sql.Parser.NodeId("anon_78"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const values_or_select = union(enum) {
        values: sql.Parser.NodeId("values"),
        select: sql.Parser.NodeId("select"),
    };
    pub const anon_81 = ?sql.Parser.NodeId("typ_length");
    pub const typ = struct {
        name: sql.Parser.NodeId("name"),
        typ_length: sql.Parser.NodeId("anon_81"),
    };
    pub const anon_83 = struct {
        comma: sql.Parser.NodeId("comma"),
        number: sql.Parser.NodeId("number"),
    };
    pub const anon_84 = ?sql.Parser.NodeId("anon_83");
    pub const typ_length = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        number: sql.Parser.NodeId("number"),
        anon_83: sql.Parser.NodeId("anon_84"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const column_constraint = union(enum) {
        primary_key: sql.Parser.NodeId("primary_key"),
    };
    pub const anon_87 = ?sql.Parser.NodeId("asc_or_desc");
    pub const primary_key = struct {
        PRIMARY: sql.Parser.NodeId("PRIMARY"),
        KEY: sql.Parser.NodeId("KEY"),
        asc_or_desc: sql.Parser.NodeId("anon_87"),
    };
    pub const anon_89 = ?sql.Parser.NodeId("update_from");
    pub const anon_90 = ?sql.Parser.NodeId("update_where");
    pub const update = struct {
        UPDATE: sql.Parser.NodeId("UPDATE"),
        table_name: sql.Parser.NodeId("table_name"),
        SET: sql.Parser.NodeId("SET"),
        column_name: sql.Parser.NodeId("column_name"),
        equal: sql.Parser.NodeId("equal"),
        expr: sql.Parser.NodeId("expr"),
        update_from: sql.Parser.NodeId("anon_89"),
        update_where: sql.Parser.NodeId("anon_90"),
    };
    pub const update_from = struct {
        TODO: sql.Parser.NodeId("TODO"),
    };
    pub const update_where = struct {
        WHERE: sql.Parser.NodeId("WHERE"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_94 = ?sql.Parser.NodeId("delete_where");
    pub const delete = struct {
        DELETE: sql.Parser.NodeId("DELETE"),
        FROM: sql.Parser.NodeId("FROM"),
        table_name: sql.Parser.NodeId("table_name"),
        delete_where: sql.Parser.NodeId("anon_94"),
    };
    pub const delete_where = struct {
        WHERE: sql.Parser.NodeId("WHERE"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const drop = union(enum) {
        drop_table: sql.Parser.NodeId("drop_table"),
        drop_index: sql.Parser.NodeId("drop_index"),
        drop_view: sql.Parser.NodeId("drop_view"),
    };
    pub const anon_98 = ?sql.Parser.NodeId("if_exists");
    pub const drop_table = struct {
        DROP: sql.Parser.NodeId("DROP"),
        TABLE: sql.Parser.NodeId("TABLE"),
        if_exists: sql.Parser.NodeId("anon_98"),
        table_name: sql.Parser.NodeId("table_name"),
    };
    pub const anon_100 = ?sql.Parser.NodeId("if_exists");
    pub const drop_index = struct {
        DROP: sql.Parser.NodeId("DROP"),
        INDEX: sql.Parser.NodeId("INDEX"),
        if_exists: sql.Parser.NodeId("anon_100"),
        table_name: sql.Parser.NodeId("table_name"),
    };
    pub const anon_102 = ?sql.Parser.NodeId("if_exists");
    pub const drop_view = struct {
        DROP: sql.Parser.NodeId("DROP"),
        VIEW: sql.Parser.NodeId("VIEW"),
        if_exists: sql.Parser.NodeId("anon_102"),
        table_name: sql.Parser.NodeId("table_name"),
    };
    pub const if_exists = struct {
        IF: sql.Parser.NodeId("IF"),
        EXISTS: sql.Parser.NodeId("EXISTS"),
    };
    pub const anon_105 = []const sql.Parser.NodeId("expr");
    pub const exprs = struct {
        expr: sql.Parser.NodeId("anon_105"),
    };
    pub const expr = struct {
        expr_or: sql.Parser.NodeId("expr_or"),
    };
    pub const anon_108 = struct {
        OR: sql.Parser.NodeId("OR"),
        expr_or: sql.Parser.NodeId("expr_or"),
    };
    pub const anon_109 = ?sql.Parser.NodeId("anon_108");
    pub const anon_110 = struct {
        anon_108: sql.Parser.NodeId("anon_109"),
    };
    pub const expr_or = struct {
        left: sql.Parser.NodeId("expr_and"),
        right: sql.Parser.NodeId("anon_110"),
    };
    pub const anon_112 = struct {
        AND: sql.Parser.NodeId("AND"),
        expr_and: sql.Parser.NodeId("expr_and"),
    };
    pub const anon_113 = ?sql.Parser.NodeId("anon_112");
    pub const anon_114 = struct {
        anon_112: sql.Parser.NodeId("anon_113"),
    };
    pub const expr_and = struct {
        left: sql.Parser.NodeId("expr_not"),
        right: sql.Parser.NodeId("anon_114"),
    };
    pub const anon_116 = []const sql.Parser.NodeId("NOT");
    pub const expr_not = struct {
        NOT: sql.Parser.NodeId("anon_116"),
        expr_incomp: sql.Parser.NodeId("expr_incomp"),
    };
    pub const anon_118 = ?sql.Parser.NodeId("expr_incomp_right");
    pub const anon_119 = struct {
        expr_incomp_right: sql.Parser.NodeId("anon_118"),
    };
    pub const expr_incomp = struct {
        left: sql.Parser.NodeId("expr_comp"),
        right: sql.Parser.NodeId("anon_119"),
    };
    pub const expr_incomp_right = union(enum) {
        expr_incomp_binop: sql.Parser.NodeId("expr_incomp_binop"),
        expr_incomp_in: sql.Parser.NodeId("expr_incomp_in"),
        expr_incomp_between: sql.Parser.NodeId("expr_incomp_between"),
        expr_incomp_postop: sql.Parser.NodeId("expr_incomp_postop"),
    };
    pub const expr_incomp_binop = struct {
        op: sql.Parser.NodeId("op_incomp"),
        right: sql.Parser.NodeId("expr_incomp"),
    };
    pub const anon_123 = ?sql.Parser.NodeId("NOT");
    pub const expr_incomp_in = struct {
        NOT: sql.Parser.NodeId("anon_123"),
        IN: sql.Parser.NodeId("IN"),
        open_paren: sql.Parser.NodeId("open_paren"),
        right: sql.Parser.NodeId("expr_incomp_in_right"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const expr_incomp_in_right = union(enum) {
        exprs: sql.Parser.NodeId("exprs"),
        select: sql.Parser.NodeId("select"),
    };
    pub const anon_126 = ?sql.Parser.NodeId("NOT");
    pub const expr_incomp_between = struct {
        NOT: sql.Parser.NodeId("anon_126"),
        BETWEEN: sql.Parser.NodeId("BETWEEN"),
        start: sql.Parser.NodeId("expr_comp"),
        AND: sql.Parser.NodeId("AND"),
        end: sql.Parser.NodeId("expr_incomp"),
    };
    pub const anon_128 = []const sql.Parser.NodeId("op_incomp_post");
    pub const expr_incomp_postop = struct {
        op_incomp_post: sql.Parser.NodeId("anon_128"),
    };
    pub const anon_130 = struct {
        op: sql.Parser.NodeId("op_comp"),
        expr_comp: sql.Parser.NodeId("expr_comp"),
    };
    pub const anon_131 = ?sql.Parser.NodeId("anon_130");
    pub const anon_132 = struct {
        anon_130: sql.Parser.NodeId("anon_131"),
    };
    pub const expr_comp = struct {
        left: sql.Parser.NodeId("expr_add"),
        right: sql.Parser.NodeId("anon_132"),
    };
    pub const anon_134 = struct {
        op: sql.Parser.NodeId("op_add"),
        expr_add: sql.Parser.NodeId("expr_add"),
    };
    pub const anon_135 = ?sql.Parser.NodeId("anon_134");
    pub const anon_136 = struct {
        anon_134: sql.Parser.NodeId("anon_135"),
    };
    pub const expr_add = struct {
        left: sql.Parser.NodeId("expr_mult"),
        right: sql.Parser.NodeId("anon_136"),
    };
    pub const anon_138 = struct {
        op: sql.Parser.NodeId("op_mult"),
        expr_atom: sql.Parser.NodeId("expr_atom"),
    };
    pub const anon_139 = ?sql.Parser.NodeId("anon_138");
    pub const anon_140 = struct {
        anon_138: sql.Parser.NodeId("anon_139"),
    };
    pub const expr_mult = struct {
        left: sql.Parser.NodeId("expr_atom"),
        right: sql.Parser.NodeId("anon_140"),
    };
    pub const op_incomp = union(enum) {
        equal: sql.Parser.NodeId("equal"),
        double_equal: sql.Parser.NodeId("double_equal"),
        not_equal: sql.Parser.NodeId("not_equal"),
        IS: sql.Parser.NodeId("IS"),
        IS_NOT: sql.Parser.NodeId("IS_NOT"),
        IS_DISTINCT_FROM: sql.Parser.NodeId("IS_DISTINCT_FROM"),
        IS_NOT_DISTINCT_FROM: sql.Parser.NodeId("IS_NOT_DISTINCT_FROM"),
        IN: sql.Parser.NodeId("IN"),
        MATCH: sql.Parser.NodeId("MATCH"),
        LIKE: sql.Parser.NodeId("LIKE"),
        REGEXP: sql.Parser.NodeId("REGEXP"),
        GLOB: sql.Parser.NodeId("GLOB"),
        NOT_IN: sql.Parser.NodeId("NOT_IN"),
        NOT_MATCH: sql.Parser.NodeId("NOT_MATCH"),
        NOT_LIKE: sql.Parser.NodeId("NOT_LIKE"),
        NOT_REGEXP: sql.Parser.NodeId("NOT_REGEXP"),
        NOT_GLOB: sql.Parser.NodeId("NOT_GLOB"),
    };
    pub const IS_NOT = struct {
        IS: sql.Parser.NodeId("IS"),
        NOT: sql.Parser.NodeId("NOT"),
    };
    pub const IS_DISTINCT_FROM = struct {
        IS: sql.Parser.NodeId("IS"),
        DISTINCT: sql.Parser.NodeId("DISTINCT"),
        FROM: sql.Parser.NodeId("FROM"),
    };
    pub const IS_NOT_DISTINCT_FROM = struct {
        IS: sql.Parser.NodeId("IS"),
        NOT: sql.Parser.NodeId("NOT"),
        DISTINCT: sql.Parser.NodeId("DISTINCT"),
        FROM: sql.Parser.NodeId("FROM"),
    };
    pub const NOT_IN = struct {
        NOT: sql.Parser.NodeId("NOT"),
        IN: sql.Parser.NodeId("IN"),
    };
    pub const NOT_MATCH = struct {
        NOT: sql.Parser.NodeId("NOT"),
        MATCH: sql.Parser.NodeId("MATCH"),
    };
    pub const NOT_LIKE = struct {
        NOT: sql.Parser.NodeId("NOT"),
        LIKE: sql.Parser.NodeId("LIKE"),
    };
    pub const NOT_REGEXP = struct {
        NOT: sql.Parser.NodeId("NOT"),
        REGEXP: sql.Parser.NodeId("REGEXP"),
    };
    pub const NOT_GLOB = struct {
        NOT: sql.Parser.NodeId("NOT"),
        GLOB: sql.Parser.NodeId("GLOB"),
    };
    pub const op_incomp_post = union(enum) {
        ISNULL: sql.Parser.NodeId("ISNULL"),
        NOTNULL: sql.Parser.NodeId("NOTNULL"),
        NOT_NULL: sql.Parser.NodeId("NOT_NULL"),
    };
    pub const NOT_NULL = struct {
        NOT: sql.Parser.NodeId("NOT"),
        NULL: sql.Parser.NodeId("NULL"),
    };
    pub const op_comp = union(enum) {
        less_than: sql.Parser.NodeId("less_than"),
        greater_than: sql.Parser.NodeId("greater_than"),
        less_than_or_equal: sql.Parser.NodeId("less_than_or_equal"),
        greater_than_or_equal: sql.Parser.NodeId("greater_than_or_equal"),
    };
    pub const op_add = union(enum) {
        plus: sql.Parser.NodeId("plus"),
        minus: sql.Parser.NodeId("minus"),
    };
    pub const op_mult = union(enum) {
        star: sql.Parser.NodeId("star"),
        forward_slash: sql.Parser.NodeId("forward_slash"),
        percent: sql.Parser.NodeId("percent"),
    };
    pub const expr_atom = union(enum) {
        case: sql.Parser.NodeId("case"),
        subquery: sql.Parser.NodeId("subquery"),
        subexpr: sql.Parser.NodeId("subexpr"),
        function_call: sql.Parser.NodeId("function_call"),
        table_column_ref: sql.Parser.NodeId("table_column_ref"),
        column_ref: sql.Parser.NodeId("column_ref"),
        value: sql.Parser.NodeId("value"),
    };
    pub const column_ref = struct {
        column_name: sql.Parser.NodeId("column_name"),
    };
    pub const table_column_ref = struct {
        table_name: sql.Parser.NodeId("table_name"),
        dot: sql.Parser.NodeId("dot"),
        column_name: sql.Parser.NodeId("column_name"),
    };
    pub const anon_159 = ?sql.Parser.NodeId("exists_or_not_exists");
    pub const subquery_prefix = struct {
        exists_or_not_exists: sql.Parser.NodeId("anon_159"),
        open_paren: sql.Parser.NodeId("open_paren"),
        SELECT: sql.Parser.NodeId("SELECT"),
    };
    pub const anon_161 = ?sql.Parser.NodeId("exists_or_not_exists");
    pub const subquery = struct {
        exists_or_not_exists: sql.Parser.NodeId("anon_161"),
        open_paren: sql.Parser.NodeId("open_paren"),
        select: sql.Parser.NodeId("select"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const exists_or_not_exists = union(enum) {
        EXISTS: sql.Parser.NodeId("EXISTS"),
        NOT_EXISTS: sql.Parser.NodeId("NOT_EXISTS"),
    };
    pub const NOT_EXISTS = struct {
        NOT: sql.Parser.NodeId("NOT"),
        EXISTS: sql.Parser.NodeId("EXISTS"),
    };
    pub const subexpr = struct {
        open_paren: sql.Parser.NodeId("open_paren"),
        expr: sql.Parser.NodeId("expr"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const anon_166 = ?sql.Parser.NodeId("expr");
    pub const anon_167 = []const sql.Parser.NodeId("case_when");
    pub const anon_168 = ?sql.Parser.NodeId("case_else");
    pub const case = struct {
        CASE: sql.Parser.NodeId("CASE"),
        expr: sql.Parser.NodeId("anon_166"),
        case_when: sql.Parser.NodeId("anon_167"),
        case_else: sql.Parser.NodeId("anon_168"),
        END: sql.Parser.NodeId("END"),
    };
    pub const case_when = struct {
        WHEN: sql.Parser.NodeId("WHEN"),
        when: sql.Parser.NodeId("expr"),
        THEN: sql.Parser.NodeId("THEN"),
        then: sql.Parser.NodeId("expr"),
    };
    pub const case_else = struct {
        ELSE: sql.Parser.NodeId("ELSE"),
        expr: sql.Parser.NodeId("expr"),
    };
    pub const anon_172 = ?sql.Parser.NodeId("function_args");
    pub const function_call = struct {
        function_name: sql.Parser.NodeId("function_name"),
        open_paren: sql.Parser.NodeId("open_paren"),
        function_args: sql.Parser.NodeId("anon_172"),
        close_paren: sql.Parser.NodeId("close_paren"),
    };
    pub const function_name = struct {
        name: sql.Parser.NodeId("name"),
    };
    pub const anon_175 = ?sql.Parser.NodeId("DISTINCT");
    pub const anon_176 = []const sql.Parser.NodeId("expr");
    pub const anon_177 = struct {
        DISTINCT: sql.Parser.NodeId("anon_175"),
        expr: sql.Parser.NodeId("anon_176"),
    };
    pub const function_args = union(enum) {
        args: sql.Parser.NodeId("anon_177"),
        star: sql.Parser.NodeId("star"),
    };
    pub const value = union(enum) {
        number: sql.Parser.NodeId("number"),
        string: sql.Parser.NodeId("string"),
        NULL: sql.Parser.NodeId("NULL"),
    };
    pub const FROM = void;
    pub const string = void;
    pub const not_greater_than = void;
    pub const DO = void;
    pub const INSTEAD = void;
    pub const TEMPORARY = void;
    pub const DELETE = void;
    pub const DISTINCT = void;
    pub const NATURAL = void;
    pub const WINDOW = void;
    pub const BY = void;
    pub const COLLATE = void;
    pub const IF = void;
    pub const DEFERRED = void;
    pub const ATTACH = void;
    pub const PRAGMA = void;
    pub const GLOB = void;
    pub const NOT = void;
    pub const WHERE = void;
    pub const bitwise_not = void;
    pub const WITH = void;
    pub const FILTER = void;
    pub const THEN = void;
    pub const UNBOUNDED = void;
    pub const FOR = void;
    pub const EXISTS = void;
    pub const shift_left = void;
    pub const INITIALLY = void;
    pub const AND = void;
    pub const double_equal = void;
    pub const BETWEEN = void;
    pub const CASCADE = void;
    pub const INSERT = void;
    pub const RECURSIVE = void;
    pub const REPLACE = void;
    pub const UNIQUE = void;
    pub const open_paren = void;
    pub const CREATE = void;
    pub const greater_than = void;
    pub const NOTHING = void;
    pub const OF = void;
    pub const RESTRICT = void;
    pub const semicolon = void;
    pub const WHEN = void;
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
    pub const COMMIT = void;
    pub const INNER = void;
    pub const EXCLUSIVE = void;
    pub const ADD = void;
    pub const ALL = void;
    pub const ACTION = void;
    pub const dot = void;
    pub const AFTER = void;
    pub const CONFLICT = void;
    pub const DEFAULT = void;
    pub const VALUES = void;
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
    pub const CURRENT_TIME = void;
    pub const percent = void;
    pub const ISNULL = void;
    pub const ROW = void;
    pub const plus = void;
    pub const FAIL = void;
    pub const USING = void;
    pub const NOTNULL = void;
    pub const AS = void;
    pub const CAST = void;
    pub const COLUMN = void;
    pub const IN = void;
    pub const END = void;
    pub const INDEXED = void;
    pub const LEFT = void;
    pub const QUERY = void;
    pub const SELECT = void;
    pub const BEFORE = void;
    pub const equal = void;
    pub const OTHERS = void;
    pub const REFERENCES = void;
    pub const ORDER = void;
    pub const ROWS = void;
    pub const comma = void;
    pub const TIES = void;
    pub const bitwise_or = void;
    pub const ABORT = void;
    pub const LIMIT = void;
    pub const DETACH = void;
    pub const DROP = void;
    pub const LAST = void;
    pub const not_equal = void;
    pub const CURRENT_TIMESTAMP = void;
    pub const INTO = void;
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
    pub const CURRENT = void;
    pub const GROUP = void;
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
    pub const less_than_or_equal = void;
    pub const TABLE = void;
    pub const NO = void;
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
    NATURAL,
    WINDOW,
    BY,
    COLLATE,
    IF,
    DEFERRED,
    ATTACH,
    PRAGMA,
    GLOB,
    NOT,
    WHERE,
    bitwise_not,
    WITH,
    FILTER,
    THEN,
    UNBOUNDED,
    FOR,
    EXISTS,
    shift_left,
    INITIALLY,
    AND,
    double_equal,
    BETWEEN,
    CASCADE,
    INSERT,
    RECURSIVE,
    REPLACE,
    UNIQUE,
    open_paren,
    CREATE,
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
    INNER,
    EXCLUSIVE,
    ADD,
    ALL,
    ACTION,
    dot,
    AFTER,
    CONFLICT,
    DEFAULT,
    VALUES,
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
    percent,
    ISNULL,
    ROW,
    plus,
    FAIL,
    USING,
    NOTNULL,
    AS,
    CAST,
    COLUMN,
    IN,
    END,
    INDEXED,
    LEFT,
    QUERY,
    SELECT,
    BEFORE,
    equal,
    OTHERS,
    REFERENCES,
    ORDER,
    ROWS,
    comma,
    TIES,
    bitwise_or,
    ABORT,
    LIMIT,
    DETACH,
    DROP,
    LAST,
    not_equal,
    CURRENT_TIMESTAMP,
    INTO,
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
    CURRENT,
    GROUP,
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
    less_than_or_equal,
    TABLE,
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
