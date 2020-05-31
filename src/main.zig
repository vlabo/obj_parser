const std = @import("std");
const process = std.process;

const Header = packed struct {
    magic: u32 = 0,
    cpu_type: u32 = 0,
    cpu_sub_type: u32 = 0,
    file_type: u32 = 0,
    number_of_load_commands: u32 = 0,
    size_of_load_commands: u32 = 0,
    flags: u32 = 0,
    reserved: u32 = 0,
};

const Segment = packed struct {
    cmd: u32 = 0,
    cmdsize: u32 = 0,
    segname: [16]u8 = [_]u8{0} ** 16,
};

fn print_header(stdout: std.fs.File.OutStream, h: Header) !void {
    try stdout.print(
        \\ Magic: 0x{x}
        \\ CPU Type: 0x{x}
        \\ CPU Sub Type: 0x{x}
        \\ File type: 0x{x}
        \\ Number of commands: {}
        \\ Size of load commands: {}
        \\ Flags: 0x{x}
        \\
    , .{ h.magic, h.cpu_type, h.cpu_sub_type, h.file_type, h.number_of_load_commands, h.size_of_load_commands, h.flags });
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().outStream();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var args_it = process.args();
    const exe_name = try args_it.next(allocator) orelse unreachable;
    const mach_o_file = try (args_it.next(allocator) orelse std.debug.panic("Usage {} [MachO file]", .{exe_name}));

    const file = std.fs.cwd().openFile(mach_o_file, .{ .read = true, .write = false }) catch |err| label: {
        std.debug.panic("unable to open file: {}\n", .{err});
    };

    var stream = file.inStream();
    var header = stream.readStruct(Header) catch Header{};
    print_header(stdout, header) catch {};

    var i: usize = 0;
    while (i < header.number_of_load_commands) : (i += 1) {
        var segment = stream.readStruct(Segment) catch Segment{};
        if (segment.cmd == 0x19) {
            stdout.print("{}\n", .{ segment.segname }) catch {};
        }

        if (segment.cmdsize > @sizeOf(Segment)) {
            const offset: u32 = segment.cmdsize - @sizeOf(Segment);
            if (offset > 0) {
                stream.skipBytes(offset) catch {};
            }
        }
    }
}
