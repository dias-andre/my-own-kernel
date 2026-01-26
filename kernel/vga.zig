pub const Color = enum(u8) { Black = 0, Blue = 1, Green = 2, Cyan = 3, Red = 4, Magenta = 5, Brown = 6, LightGray = 7, DarkGray = 8, LightBlue = 9, LightGreen = 10, LightCyan = 11, LightRed = 12, Pink = 13, Yellow = 14, White = 15 };

const WIDTH = 80;
const HEIGHT = 25;
const VIDEO_ADDRESS = 0xB8000;

var row: usize = 0;
var column: usize = 0;
var color_attr: u8 = 0x0f;

fn vgaEntry(char: u8, color: u8) u16 {
    const c: u16 = char;
    const co: u16 = color;

    return (co << 8) | c;
}

// PUBLIC API

pub fn setColor(fg: Color, bg: Color) void {
    color_attr = (@intFromEnum(bg) << 4) | @intFromEnum(fg);
}

pub fn clear() void {
    const buffer: [*]volatile u16 = @ptrFromInt(VIDEO_ADDRESS);

    var y: usize = 0;
    while (y < HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < WIDTH) : (x += 1) {
            const index = y * WIDTH + x;
            buffer[index] = vgaEntry(' ', color_attr);
        }
    }
    row = 0;
    column = 0;
}

pub fn print(str: []const u8) void {
    for (str) |char| {
        putChar(char);
    }
}

fn putChar(c: u8) void {
    if (c == '\n') {
        newLine();
        return;
    }

    const index = row * WIDTH + column;
    const buffer: [*]volatile u16 = @ptrFromInt(VIDEO_ADDRESS);
    buffer[index] = vgaEntry(c, color_attr);
    column += 1;
    if (column >= WIDTH) {
        newLine();
    }
}

fn newLine() void {
    column = 0;
    row += 1;
    if (row >= HEIGHT) {
        row = 0;
        clear();
    }
}

pub const PanicWriter = struct {
    const BUFFER: [*] volatile u16 = @ptrFromInt(0xb8000);
    const xWIDTH = 80;
    const xHEIGHT = 25;
    const ERROR_COLOR: u16 = 0x4f00;

    pub fn cleanError() void {
        var i: usize = 0;
        const space: u16 = ' ';
        while (i < xWIDTH * xHEIGHT) : (i += 1) {
            BUFFER[i] = ERROR_COLOR | space;
        }
    }

    pub fn printAt(msg: []const u8, x: usize, y: usize) void {
        var offset = y * xWIDTH + x;

        for (msg) |c| {
            if (offset >= xWIDTH * xHEIGHT) break;
            BUFFER[offset] = ERROR_COLOR | @as(u16, c);
            offset += 1;
        }
    }

    pub fn printHexAt(value: u64, x: usize, y: usize) void {
        var offset = y * WIDTH + x;
        const hex = "0123456789ABCDEF";

        BUFFER[offset] = ERROR_COLOR | '0'; offset += 1;
        BUFFER[offset] = ERROR_COLOR | 'x'; offset += 1;

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
