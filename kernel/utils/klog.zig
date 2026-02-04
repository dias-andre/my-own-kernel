const video = @import("../drivers/vga.zig");

pub var screen = video.VGA.init(80, 25, 0xb8000);

pub const Logger = struct {
    pub fn info(comptime fmt: []const u8, args: anytype) void {
        printHeader("INFO", video.Color.Cyan);
        formatPrint(fmt, args);
        screen.print("\n");
    }

    pub fn debug(comptime fmt: []const u8, args: anytype) void {
        printHeader("INFO", video.Color.LightGray);
        formatPrint(fmt, args);
        screen.print("\n");
    }

    pub fn ok(comptime fmt: []const u8, args: anytype) void {
        printHeader(" OK ", video.Color.Green);
        formatPrint(fmt, args);
        screen.print("\n");
    }

    pub fn spec(comptime fmt: []const u8, args: anytype) void {
        printHeader("TEST", video.Color.Blue);
        formatPrint(fmt, args);
        screen.print("\n");
    }

    pub fn failed(comptime fmt: []const u8, args: anytype) void {
        printHeader("FAIL", video.Color.Red);
        formatPrint(fmt, args);
        screen.print("\n");
    }

    pub fn println(comptime fmt: []const u8, args: anytype) void {
        screen.print(" ");
        formatPrint(fmt, args);
        screen.print("\n");
    }

    fn printHeader(text: []const u8, color: video.Color) void {
        screen.print("[ ");
        screen.setColor(color, video.Color.Black);
        screen.print(text);
        screen.setDefaultColor();
        screen.print(" ] ");
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
            screen.print(fmt[start..i]);

            printArg(arg);

            if (i < fmt.len) {
                i += 2; 
            }
        }
        if (i < fmt.len) {
            screen.print(fmt[i..]);
        }
    }

    fn printArg(arg: anytype) void {
        const T = @TypeOf(arg);
        
        switch (@typeInfo(T)) {
            .int, .comptime_int => {
                screen.printDec(@intCast(arg));
            },
            
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    screen.print(arg);
                } 
                else {
                    screen.print("0x");
                    screen.printHex(@intFromPtr(arg));
                }
            },
            
            .bool => {
                if (arg) screen.print("true") else screen.print("false");
            },

            .optional => {
                if (arg) |val| {
                    printArg(val);
                } else {
                    screen.print("null");
                }
            },
            else => {
                screen.print("?");
            },
        }
    }
};