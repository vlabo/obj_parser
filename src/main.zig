const std = @import("std");
const process = std.process;
const cpu = @import("cpu.zig");

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

const CommandType = enum(u32) {
    segment = 0x1, //  segment of this file to be mapped
    symtab = 0x2, //  link-edit stab symbol table info
    symseg = 0x3, //  link-edit gdb symbol table info (obsolete)
    thread = 0x4, //  thread
    unixthread = 0x5, //  unix thread (includes a stack)
    loadfvmlib = 0x6, //  load a specified fixed VM shared library
    idfvmlib = 0x7, //  fixed VM shared library identification
    ident = 0x8, //  object identification info (obsolete)
    fvmfile = 0x9, //  fixed VM file inclusion (internal use)
    prepage = 0xa, //  prepage command (internal use)
    dysymtab = 0xb, //  dynamic link-edit symbol table info
    load_dylib = 0xc, //  load a dynamically linked shared library
    id_dylib = 0xd, //  dynamically linked shared lib ident
    load_dylinker = 0xe, //  load a dynamic linker
    id_dylinker = 0xf, //  dynamic linker identification
    prebound_dylib = 0x10, //  modules prebound for a dynamically

    //   linked shared library
    routines = 0x11, //  image routines
    sub_framework = 0x12, //  sub framework
    sub_umbrella = 0x13, //  sub umbrella
    sub_client = 0x14, //  sub client
    sub_library = 0x15, //  sub library
    twolevel_hints = 0x16, //  two-level namespace lookup hints
    prebind_cksum = 0x17, //  prebind checksum

    load_weak_dylib = (0x18 | 0x80000000),

    //load a dynamically linked shared library that is allowed to be missing (all symbols are weak imported).

    segment_64 = 0x19, //  64-bit segment of this file to be mapped
    routines_64 = 0x1a, //  64-bit image routines
    uuid = 0x1b, //  the uuid
    rpath = (0x1c | 0x80000000), //  runpath additions
    code_signature = 0x1d, //  local of code signature
    segment_split_info = 0x1e, //  local of info to split segments
    reexport_dylib = (0x1f | 0x80000000), //  load and re-export dylib
    lazy_load_dylib = 0x20, //  delay load of dylib until first use
    encryption_info = 0x21, //  encrypted segment information
    dyld_info = 0x22, //  compressed dyld information
    dyld_info_only = (0x22 | 0x80000000), //  compressed dyld information only
    version_min_macosx = 0x24, 
    function_starts = 0x26,
    main = (0x28 | 0x80000000),
    data_in_code = 0x29,
    soruce_version = 0x2A,
};

const Header = packed struct {
    magic: u32 = 0,
    cpu_type: cpu.Type = cpu.Type.any,
    cpu_sub_type: u32 = 0,
    file_type: FileType = FileType.object,
    number_of_load_commands: u32 = 0,
    size_of_load_commands: u32 = 0,
    flags: u32 = 0,
    reserved: u32 = 0,
};

const LoadCommand = packed struct {
    cmd_type: CommandType = CommandType.segment,
    cmd_size: u32 = 0,
};

fn print_header(stdout: std.fs.File.OutStream, h: Header) !void {
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
        var load_command = stream.readStruct(LoadCommand) catch LoadCommand{};
        stdout.print(" - {}\n", .{load_command.cmd_type}) catch {};
        stream.skipBytes(load_command.cmd_size - @sizeOf(LoadCommand)) catch {};
    }
}
