const vga = @import("../vga.zig"); // Ajuste o import conforme necessário

pub const Logger = struct {
    pub fn info(comptime fmt: []const u8, args: anytype) void {
        printHeader("INFO", vga.Color.Cyan);
        formatPrint(fmt, args);
        vga.print("\n");
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        printHeader(" OK ", vga.Color.Green);
        formatPrint(fmt, args);
        vga.print("\n");
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        printHeader("FAIL", vga.Color.Red);
        formatPrint(fmt, args);
        vga.print("\n");
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        vga.print(" ");
        formatPrint(fmt, args);
        vga.print("\n");
    }

    fn printHeader(text: []const u8, color: vga.Color) void {
        vga.print("[ ");
        vga.setColor(color, vga.Color.Black);
        vga.print(text);
        vga.setDefaultColor();
        vga.print(" ] ");
    }

    fn formatPrint(comptime fmt: []const u8, args: anytype) void {
        var i: usize = 0;
        inline for (args) |arg| {
            const start = i;
            while (i < fmt.len) : (i += 1) {
                if (fmt[i] == '{' and i + 1 < fmt.len and fmt[i+1] == '}') {
                    break;
                }
            }
            vga.print(fmt[start..i]);

            printArg(arg);

            if (i < fmt.len) {
                i += 2; 
            }
        }
        if (i < fmt.len) {
            vga.print(fmt[i..]);
        }
    }

    fn printArg(arg: anytype) void {
        const T = @TypeOf(arg);
        
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                vga.printDec(@intCast(arg));
            },
            
            .pointer => |ptr_info| {
                // Se for Slice de bytes ([]u8 ou []const u8) -> String
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    vga.print(arg);
                } 
                // Se for ponteiro normal -> Hexadecimal
                else {
                    vga.print("0x");
                    vga.printHex(@intFromPtr(arg));
                }
            },
            
            .bool => {
                if (arg) vga.print("true") else vga.print("false");
            },

            .optional => {
                if (arg) |val| {
                    printArg(val);
                } else {
                    vga.print("null");
                }
            },
            else => {
                vga.print("?");
            },
        }
    }
};