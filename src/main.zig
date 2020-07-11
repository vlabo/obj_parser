const std = @import("std");
const process = std.process;
const log = std.log;
const expectEqual = @import("std").testing.expectEqual;
const warn = @import("std").debug.warn;
const Allocator = std.mem.Allocator;

const File = std.fs.File;

const Command = @import("command.zig");
const ObjFile = Command.ObjFile;

pub const log_level: std.log.Level = .err;

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().outStream();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var args_it = process.args();
    const exe_name = try args_it.next(allocator) orelse unreachable;
    const mach_o_file = try (args_it.next(allocator) orelse std.debug.panic("Usage {} [MachO file]", .{exe_name}));

    const file = std.fs.cwd().openFile(mach_o_file, .{ .read = true, .write = false }) catch |err| label: {
        std.debug.panic(" Unable to open File: {}\n", .{err});
    };

    var obj = try ObjFile.read(file, allocator);
    defer obj.free(allocator);

    obj.header.print(stdout) catch {};
    obj.print(stdout) catch {};
}
