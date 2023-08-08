pub const Kind = enum(u32) {
    number = 0,
    string = 1,
    map = 2,
};

export fn add(x: usize) callconv(.C) usize {
    return x + 1;
}
