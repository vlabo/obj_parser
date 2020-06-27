const std = @import("std");
const process = std.process;
const log = std.log;
const cpu = @import("cpu.zig");
const expectEqual = @import("std").testing.expectEqual;
const warn = @import("std").debug.warn;
const Allocator = std.mem.Allocator;
const Vector = std.meta.Vector;

const File = std.fs.File;

const Command = @import("command.zig");

pub const log_level: std.log.Level = .err;

const FileType = enum(u32) {
    object = 0x1,
    executable = 0x2,
    fvmlib = 0x3,
    core = 0x4,
    preload = 0x5,
    dylib = 0x6,
    dylink = 0x7,
    bundle = 0x8,
    sulib_stub = 0x9,
    dsym = 0xA,
    kext_bundle = 0xB,
};

const Header = packed struct {
    magic: u32 = 0,
    cpu_type: cpu.Type = .any,
    cpu_sub_type: u32 = 0,
    file_type: FileType = .object,
    number_of_load_commands: u32 = 0,
    size_of_load_commands: u32 = 0,
    flags: u32 = 0,
    reserved: u32 = 0,
};

fn print_header(stdout: File.OutStream, h: Header) !void {
    try stdout.print(
        \\Header:
        \\ Magic: 0x{x}
        \\ CPU Type: {}
        \\ CPU Sub Type: 0x{x}
        \\ File type: {}
        \\ Number of commands: {}
        \\ Size of load commands: {}
        \\ Flags: 0x{x}
        \\ 
        \\
    , .{ h.magic, h.cpu_type, h.cpu_sub_type, h.file_type, h.number_of_load_commands, h.size_of_load_commands, h.flags });
}

const ObjFile = struct {
    header: Header,
    load_commands: []usize,

    const Self = ObjFile;
    fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var header = try stream.readStruct(Header);
        var i: u32 = 0;
        var load_commands = try allocator.alloc(usize, header.number_of_load_commands);

        while (i < header.number_of_load_commands) : (i += 1) {
            var cmdInt = try stream.readIntNative(u32);
            var cmd = @intToEnum(Command.Type, cmdInt);
            switch (cmd) {
                .segment64 => {
                    load_commands[i] = try Self.create_command(Command.Segment64, stream, allocator);
                },
                .symtab => {
                    load_commands[i] = try Self.create_command(Command.Symtab, stream, allocator);
                },
                .dysymtab => {
                    load_commands[i] = try Self.create_command(Command.Dysymtab, stream, allocator);
                },
                .dyld_info_only => {
                    load_commands[i] = try Self.create_command(Command.DylibInfoOnly, stream, allocator);
                },
                .load_dylinker => {
                    load_commands[i] = try Self.create_command(Command.LoadDylinker, stream, allocator);
                },
                .version_min_macosx => {
                    load_commands[i] = try Self.create_command(Command.VersionMinMacOSX, stream, allocator);
                },
                .source_version => {
                    load_commands[i] = try Self.create_command(Command.SourceVersion, stream, allocator);
                },
                .main => {
                    load_commands[i] = try Self.create_command(Command.Main, stream, allocator);
                },
                .load_dylib => {
                    load_commands[i] = try Self.create_command(Command.LoadDlib, stream, allocator);
                },
                .function_starts => {
                    load_commands[i] = try Self.create_command(Command.FunctionStarts, stream, allocator);
                },
                .data_in_code => {
                    load_commands[i] = try Self.create_command(Command.DataInCode, stream, allocator);
                },
                .uuid => {
                    load_commands[i] = try Self.create_command(Command.UUID, stream, allocator);
                },
                else => {
                    load_commands[i] = 0;
                    var size = try stream.readIntNative(u32);
                    try stream.skipBytes(size - 8);
                },
            }
        }
        return Self{
            .header = header,
            .load_commands = load_commands,
        };
    }

    fn create_command(comptime command_type: type, stream: File.Reader, allocator: *Allocator) !usize {
       var command = try allocator.create(command_type);
       command.* = try command_type.read(stream, allocator);
       return @ptrToInt(command);
    }

    fn free(self: Self, allocator: *Allocator) void {
        // TODO: clear load commands
        allocator.free(self.load_commands);
    }
};

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

    var stream = file.inStream();
    var obj = try ObjFile.read(stream, allocator);
    defer obj.free(allocator);

    print_header(stdout, obj.header) catch {};

    for (obj.load_commands) |load_command| {
        if (load_command != 0) {
            var command_type = @intToPtr(*Command.Type, load_command);

            switch (command_type.*) {
                .segment64 => {
                    var command = @intToPtr(*Command.Segment64, load_command);
                    stdout.print(" Segment 64 - {}\n", .{command.segment_name}) catch {};

                    var sections_count = command.number_of_sections;
                    for (command.sections) |section| {
                        stdout.print("\t SegmentHeader - {}\n", .{section.section_name}) catch {};
                    }
                },
                .symtab => {
                    var command = @intToPtr(*Command.Symtab, load_command);
                    stdout.print(" Symtab \n", .{}) catch {};
                },
                .dysymtab => {
                    var command = @intToPtr(*Command.Dysymtab, load_command);
                    stdout.print(" Dysymtab \n", .{}) catch {};
                },
                .dyld_info_only => {
                    var command = @intToPtr(*Command.DylibInfoOnly, load_command);
                    stdout.print(" SegmentDylibInfoOnly \n", .{}) catch {};
                },
                .load_dylinker => {
                    var command = @intToPtr(*Command.LoadDylinker, load_command); 
                    stdout.print(" SegmentLoadDylinker - {} \n", .{command.name}) catch {};
                },
                .version_min_macosx => {
                    var command = @intToPtr(*Command.VersionMinMacOSX, load_command);
                    stdout.print(" VersionMinMacOSX - {} \n", .{command.version}) catch {};
                },
                .source_version => {
                    var command = @intToPtr(*Command.SourceVersion, load_command);
                    stdout.print(" SourceVersion - {} \n", .{command.version}) catch {};
                },
                .main => {
                    var command = @intToPtr(*Command.Main, load_command);
                    stdout.print(" Main - {}\n", .{command.entry_offset}) catch {};
                },
                .load_dylib => {
                    var command = @intToPtr(*Command.LoadDlib,load_command);
                    stdout.print(" LoadDlib - {} \n", .{command.name}) catch {};
                },
                .function_starts => {
                    var command = @intToPtr(*Command.FunctionStarts, load_command);
                    stdout.print(" FunctionStarts\n", .{}) catch {};
                },
                .data_in_code => {
                    var command = @intToPtr(*Command.DataInCode, load_command);
                    stdout.print(" DataInCode\n", .{}) catch {};
                },
                .uuid => {
                    var command = @intToPtr(*Command.UUID, load_command);
                    stdout.print(" UUID\n", .{}) catch {};
                },
                .undef => {
                    std.debug.panic("Undefined command\n", .{});
                },

                else => {},
            }
        }
    }
 }
