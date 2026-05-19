pub const Writer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (ctx: *anyopaque, data: []const u8) void,
        put: *const fn (ctx: *anyopaque, data: u8) void,
    };

    pub fn write(self: Writer, data: []const u8) void {
        self.vtable.write(self.ptr, data);
    }

    pub fn put(self: Writer, data: u8) void {
        self.vtable.put(self.ptr, data);
    }
};

pub const MultiWriter = struct {
    writers: []const Writer,

    pub fn flush(ctx: *anyopaque, data: []const u8) void {
        const self: *MultiWriter = @ptrCast(@alignCast(ctx));
        for (self.writers) |w| {
            w.write(data);
        }
    }
};

pub const FormatWriter = struct {
    inner: Writer,

    pub fn write(self: FormatWriter, data: []const u8) void {
        self.inner.write(data);
    }

    pub fn print(self: FormatWriter, data: []const u8) void {
        self.inner.write(data);
    }

    pub fn printHex(self: FormatWriter, value: u64) void {
        const hex_chars = "0123456789ABCDEF";
        var v = value;

        if (v == 0) {
            self.inner.write("0");
            return;
        }

        var buffer: [20]u8 = undefined;
        var index: usize = 0;

        while (v > 0) {
            const nibble = v % 16;
            buffer[index] = hex_chars[nibble];
            index += 1;
            v = v / 16;
        }

        while (index > 0) {
            index -= 1;
            // self.inner.write(.{buffer[index]});
            self.inner.put(buffer[index]);
        }
    }

    pub fn printDec(self: FormatWriter, value: usize) void {
        var v = value;
        if (v == 0) return self.inner.write("0");
        var buf: [20]u8 = undefined;
        var i: usize = 0;
        while (v > 0) {
            buf[i] = '0' + @as(u8, @intCast(v % 10));
            i += 1;
            v /= 10;
        }
        while (i > 0) {
            i -= 1;
            self.inner.write(buf[i .. i + 1]);
        }
    }
};
