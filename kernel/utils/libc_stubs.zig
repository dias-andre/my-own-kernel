export fn memcpy(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) ?[*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }
    return dest;
}

export fn memset(dest: [*]u8, val: u8, n: usize) callconv(.c) ?[*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = val;
    }
    return dest;
}

export fn memmove(dest: [*]u8, src: [*]const u8, n: usize) callconv(.c) ?[*]u8 {
    if (@intFromPtr(dest) < @intFromPtr(src)) {
        return memcpy(dest, src, n);
    }

    var i: usize = n;
    while (i > 0) {
        i -= 1;
        dest[i] = src[i];
    }
    return dest;
}