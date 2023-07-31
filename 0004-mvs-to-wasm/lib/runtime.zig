export fn add(x: usize) callconv(.C) usize {
    return x + 1;
}
