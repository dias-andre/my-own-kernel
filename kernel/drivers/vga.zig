const std = @import("std"); // Necessário se quiser usar o Writer no futuro

pub const Color = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    Pink = 13,
    Yellow = 14,
    White = 15,
};

fn vgaEntry(char: u8, color: u8) u16 {
    const c: u16 = char;
    const co: u16 = color;
    return (co << 8) | c;
}

pub const VGA = struct {
    row: usize = 0,
    column: usize = 0,
    color_attr: u8 = 0x0f,
    video_address: usize,
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize, video_address: usize) VGA {
        return VGA{
            .row = 0,
            .column = 0,
            .color_attr = vgaEntry(' ', 0x0F) >> 8, // Pega cor padrão
            .video_address = video_address,
            .width = width,
            .height = height,
        };
    }

    pub fn setColor(self: *VGA, fg: Color, bg: Color) void {
        self.color_attr = (@intFromEnum(bg) << 4) | @intFromEnum(fg);
    }

    pub fn setDefaultColor(self: *VGA) void {
        self.setColor(Color.White, Color.Black);
    }

    pub fn clear(self: *VGA) void {
        // Cast para ponteiro many-item [*]volatile u16
        const buffer: [*]volatile u16 = @ptrFromInt(self.video_address);
        const blank = vgaEntry(' ', self.color_attr);

        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const index = y * self.width + x;
                buffer[index] = blank;
            }
        }
        self.row = 0;
        self.column = 0;
    }

    pub fn print(self: *VGA, str: []const u8) void {
        for (str) |char| {
            self.putChar(char);
        }
    }

    pub fn printHex(self: *VGA, value: u64) void {
        const hex_chars = "0123456789ABCDEF";
        var v = value;

        if (v == 0) {
            self.putChar('0');
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
            self.putChar(buffer[index]);
        }
    }

    pub fn printDec(self: *VGA, value: usize) void {
        if (value == 0) {
            self.putChar('0');
            return;
        }

        var v = value;
        var buffer: [20]u8 = undefined;
        var index: usize = 0;

        while (v > 0) {
            const digit = v % 10;
            buffer[index] = '0' + @as(u8, @intCast(digit));
            index += 1;
            v = v / 10;
        }

        while (index > 0) {
            index -= 1;
            self.putChar(buffer[index]);
        }
    }

    pub fn printError(self: *VGA, value: []const u8) void {
        self.setColor(Color.White, Color.Red);
        self.print(value);
        self.setDefaultColor();
        self.print("\n");
    }

    fn putChar(self: *VGA, c: u8) void {
        if (c == '\n') {
            self.newLine();
            return;
        }

        const index = self.row * self.width + self.column;
        const buffer: [*]volatile u16 = @ptrFromInt(self.video_address);

        buffer[index] = vgaEntry(c, self.color_attr);

        self.column += 1;
        if (self.column >= self.width) {
            self.newLine();
        }
    }

    fn newLine(self: *VGA) void {
        self.column = 0;
        self.row += 1;
        if (self.row >= self.height) {
            self.row = 0;
            self.clear();
        }
    }
};

pub const PanicWriter = struct {
    const BUFFER: [*]volatile u16 = @ptrFromInt(0xb8000);
    const _WIDTH = 80;
    const _HEIGHT = 25;
    const ERROR_COLOR: u16 = 0x4f00;
    var _column: usize = 0;
    var _row: usize = 0;

    fn _putChar(c: u8) void {
        if (c == '\n') {
            _newLine();
            return;
        }
        const index = _row * _WIDTH + _column;
        BUFFER[index] = ERROR_COLOR | @as(u16, c);
        _column += 1;
        if (_column >= _WIDTH) {
            _newLine();
        }
    }

    fn _newLine() void {
        _column = 0;
        _row += 1;
        if (_row >= _HEIGHT) {
            _row = 0;
            cleanError();
        }
    }

    pub fn print(str: []const u8) void {
        for (str) |c| {
            _putChar(c);
        }
    }

    pub fn printHex(value: u64) void {
        const hex = "0123456789ABCDEF";
        PanicWriter.print("0x");
        var i: u8 = 16;
        while (i > 0) {
            i -= 1;
            const shift = @as(u6, @intCast(i)) * 4;
            const nibble = (value >> shift) & 0xF;
            _putChar(hex[nibble]);
        }
    }

    pub fn printDec(value: usize) void {
        if (value == 0) {
            _putChar('0');
            return;
        }

        var v = value;
        var buffer: [20]u8 = undefined;
        var index: usize = 0;

        while (v > 0) {
            const digit = v % 10; // Pega o último dígito
            buffer[index] = '0' + @as(u8, @intCast(digit)); // Converte para char ASCII
            index += 1;
            v = v / 10;
        }

        while (index > 0) {
            index -= 1;
            _putChar(buffer[index]);
        }
    }

    pub fn cleanError() void {
        _column = 0;
        _row = 0;
        var i: usize = 0;
        const space: u16 = ' ';
        while (i < _WIDTH * _HEIGHT) : (i += 1) {
            BUFFER[i] = ERROR_COLOR | space;
        }
    }

    pub fn printAt(msg: []const u8, x: usize, y: usize) void {
        var offset = y * _WIDTH + x;

        for (msg) |c| {
            if (offset >= _WIDTH * _HEIGHT) break;
            BUFFER[offset] = ERROR_COLOR | @as(u16, c);
            offset += 1;
        }
    }

    pub fn printHexAt(value: u64, x: usize, y: usize) void {
        var offset = y * _WIDTH + x;
        const hex = "0123456789ABCDEF";

        BUFFER[offset] = ERROR_COLOR | '0';
        offset += 1;
        BUFFER[offset] = ERROR_COLOR | 'x';
        offset += 1;

        var i: u8 = 16;
        while (i > 0) {
            i -= 1;
            const shift = @as(u6, @intCast(i)) * 4;
            const nibble = (value >> shift) & 0xF;
            BUFFER[offset] = ERROR_COLOR | @as(u16, hex[nibble]);
            offset += 1;
        }
    }
};
