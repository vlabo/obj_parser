const std = @import("std");
const process = std.process;
const log = std.log;
const cpu = @import("cpu.zig");
const expectEqual = @import("std").testing.expectEqual;
const warn = @import("std").debug.warn;
const Allocator = std.mem.Allocator;

const File = std.fs.File;

const command = @import("command.zig");

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
        \\ Magic: 0x{x}
        \\ CPU Type: {}
        \\ CPU Sub Type: 0x{x}
        \\ File type: {}
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
    var i = header.number_of_load_commands;
    while (i > 0) : (i -= 1) {
        var cmdInt = stream.readIntNative(u32) catch 0;
        var cmd = @intToEnum(command.Type, cmdInt);

        switch(cmd) {
                .segment_64 => {
                    var segment = command.Segment64.read(stream) catch {
                        @panic("Faild to read segment");
                    };
                    stdout.print("Segment 64 - {}\n", .{segment.segname}) catch {};

                    var sections_count = segment.number_of_sections;
                    while(sections_count > 0) : (sections_count-=1) {
                        var segment_header = command.Segment64Header.read(stream) catch {
                            @panic("Failed to read segment header");
                        };

                        stdout.print("\t SegmentHeader - {}\n", .{segment_header.section_name}) catch {};
                    }

                },
                .symtab => {
                    var segment = command.Symtab.read(stream) catch {
                        @panic("Faild to read SegmentSymtab");
                    };
                    stdout.print("Symtab \n", .{}) catch {};
                },
                .dysymtab => {
                    var segment = command.Dysymtab.read(stream) catch {
                        @panic("Faild to read SegmentDysymtab");
                    };
                    stdout.print("Dysymtab \n", .{}) catch {};
                },
                .dyld_info_only => {
                    var segment = command.DylibInfoOnly.read(stream) catch {
                        @panic("Faild to read SegmentDylibInfoOnly");
                    };
                    stdout.print("SegmentDylibInfoOnly \n", .{}) catch {};
                },
                .load_dylinker => {
                    var segment = command.LoadDylinker.read(stream, allocator) catch |err| {
                        stdout.print("Error: {}\n", .{err}) catch {};
                        @panic("Faild to read SegmentLoadDylinker");
                    };
                    defer segment.free(allocator);
                    stdout.print("SegmentLoadDylinker - {} \n", .{segment.name}) catch {};
                },
                .version_min_macosx => {
                    var segment = command.VersionMinMacOSX.read(stream) catch |err| {
                        warn("Error: {}\n", .{err});
                        @panic("Faild to read VersionMinMacOSX");
                    };
                    stdout.print("VersionMinMacOSX - {} \n", .{segment.version}) catch {};
                },
                .source_version => {
                    var segment = command.SourceVersion.read(stream) catch |err| {
                        warn("Error: {}\n", .{err});
                        @panic("Faild to read SourceVersion");
                    };
                    stdout.print("SourceVersion - {} \n", .{segment.version}) catch {};
                },
                .main => {
                    var segment = command.Main.read(stream) catch |err| {
                        warn("Error: {}\n", .{@errorName(err)});
                        @panic("Faild to read Main");
                    };
                    stdout.print("Main - {}\n", .{segment.entry_offset}) catch {};
                },
                .load_dylib => {
                    var segment = command.LoadDlib.read(stream, allocator) catch |err| {
                        warn("Error: {}\n", .{err});
                        @panic("Faild to read LoadDlib");
                    };
                    defer segment.free(allocator);
                    log.warn(.Debug, "Test\n", .{});
                    stdout.print("LoadDlib - {} \n", .{segment.name}) catch {};

                },
                .function_starts => {
                    var segment = command.FunctionStarts.read(stream) catch |err| {
                        stdout.print("Error: {}\n", .{err}) catch {};
                        @panic("Faild to read FunctionStarts");
                    };
                    stdout.print("FunctionStarts\n", .{}) catch {};
                },
                .data_in_code => {
                    var segment = command.DataInCode.read(stream) catch |err| {
                        stdout.print("Error: {}\n", .{err}) catch {};
                        //std.log("Test");
                        @panic("Faild to read DataInCoden");
                    };
                    stdout.print("DataInCode\n", .{}) catch {};
                },
                .undef => {
                    stdout.print("Undefined command: {}\n", .{ cmdInt }) catch {};
                },
                else => {
                    var size = stream.readIntNative(u32) catch {
                        @panic("Faild to read size");
                    };
                    var sizeLeft = size - @sizeOf(command.Type) - @sizeOf(u32);
                    stdout.print(" - {}\n", .{cmd}) catch {};
                    stream.skipBytes(sizeLeft) catch {};
                }
            }
    }
}
