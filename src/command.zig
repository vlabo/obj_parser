const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;
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

pub const Type = enum(u32) {
    undef = 0x0,
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

    segment64 = 0x19, //  64-bit segment of this file to be mapped
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
    source_version = 0x2A,
};

const Command = struct {
    @"type": Type,
    free: fn (cmd: *Command, allocator: *Allocator) void = Command.default_free,

    fn default_free() void {}
};

pub const Segment64 = struct {
    cmd: Command = Command{
        .type = Type.segment64,
        .free = Self.free,
    },
    size: u32,
    segment_name: [16]u8,
    vmaddr: u64,
    vmsize: u64,
    fileoff: u64,
    filesize: u64,
    maxprot: u32,
    initprot: u32,
    number_of_sections: u32,
    flags: u32,
    sections: []Segment64Header,
    const Self = Segment64;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var size = try stream.readIntNative(u32);
        var segment_name = [1]u8{0} ** 16;
        _ = try stream.readAll(&segment_name);
        var vmaddr = try stream.readIntNative(u64);
        var vmsize = try stream.readIntNative(u64);
        var fileoff = try stream.readIntNative(u64);
        var filesize = try stream.readIntNative(u64);
        var maxprot = try stream.readIntNative(u32);
        var initprot = try stream.readIntNative(u32);
        var number_of_sections = try stream.readIntNative(u32);
        var flags = try stream.readIntNative(u32);
        var sections = try allocator.alloc(Segment64Header, number_of_sections);
        var i: u32 = 0;
        while (i < number_of_sections) : (i += 1) {
            sections[i] = try Segment64Header.read(stream, allocator);
        }

        return Self{
            .size = size,
            .segment_name = segment_name,
            .vmaddr = vmaddr,
            .vmsize = vmsize,
            .fileoff = fileoff,
            .filesize = filesize,
            .maxprot = maxprot,
            .initprot = initprot,
            .number_of_sections = number_of_sections,
            .flags = flags,
            .sections = sections,
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {
        var segment = @ptrCast(*Self, self);
        allocator.free(segment.sections);
    }
};

pub const Segment64Header = struct {
    section_name: [16]u8,
    segment_name: [16]u8,
    address: u64,
    size: u64,
    offset: u32,
    alignment: u32,
    relocations_offset: u32,
    number_of_relocations: u32,
    flags: u32,
    reserved: [12]u8,

    const Self = Segment64Header;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var section_name = [_]u8{0} ** 16;
        var segment_name = [_]u8{0} ** 16;
        _ = try stream.readAll(&section_name);
        _ = try stream.readAll(&segment_name);

        var address = try stream.readIntNative(u64);
        var size = try stream.readIntNative(u64);
        var offset = try stream.readIntNative(u32);
        var alignment = try stream.readIntNative(u32);
        var relocations_offset = try stream.readIntNative(u32);
        var number_of_relocations = try stream.readIntNative(u32);
        var flags = try stream.readIntNative(u32);
        var reserved = [_]u8{0} ** 12;
        _ = try stream.readAll(&reserved);

        return Self{
            .section_name = section_name,
            .segment_name = segment_name,
            .address = address,
            .size = size,
            .offset = offset,
            .alignment = alignment,
            .relocations_offset = relocations_offset,
            .number_of_relocations = number_of_relocations,
            .flags = flags,
            .reserved = reserved,
        };
    }

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const Symtab = struct {
    cmd: Command = Command{
        .type = .symtab,
        .free = Self.free,
    },
    size: u32,
    symoff: u32,
    nsyms: u32,
    stroff: u32,
    strsize: u32,

    const Self = Symtab;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var self = Self{
            .size = try stream.readIntNative(u32),
            .symoff = try stream.readIntNative(u32),
            .nsyms = try stream.readIntNative(u32),
            .stroff = try stream.readIntNative(u32),
            .strsize = try stream.readIntNative(u32),
        };
        return self;
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const Dysymtab = struct {
    cmd: Command = Command{
        .type = .dysymtab,
        .free = Self.free,
    },
    cmdsize: u32,
    ilocalsym: u32,
    nlocalsym: u32,
    iextdefsym: u32,
    nextdefsym: u32,
    iundefsym: u32,
    nundefsym: u32,
    tocoff: u32,
    ntoc: u32,
    modtaboff: u32,
    nmodtab: u32,
    extrefsymoff: u32,
    nextrefsyms: u32,
    indirectsymoff: u32,
    nindirectsyms: u32,
    extreloff: u32,
    nextrel: u32,
    locreloff: u32,
    nlocrel: u32,

    const Self = Dysymtab;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var self = Self{
            .cmdsize = try stream.readIntNative(u32),
            .ilocalsym = try stream.readIntNative(u32),
            .nlocalsym = try stream.readIntNative(u32),
            .iextdefsym = try stream.readIntNative(u32),
            .nextdefsym = try stream.readIntNative(u32),
            .iundefsym = try stream.readIntNative(u32),
            .nundefsym = try stream.readIntNative(u32),
            .tocoff = try stream.readIntNative(u32),
            .ntoc = try stream.readIntNative(u32),
            .modtaboff = try stream.readIntNative(u32),
            .nmodtab = try stream.readIntNative(u32),
            .extrefsymoff = try stream.readIntNative(u32),
            .nextrefsyms = try stream.readIntNative(u32),
            .indirectsymoff = try stream.readIntNative(u32),
            .nindirectsyms = try stream.readIntNative(u32),
            .extreloff = try stream.readIntNative(u32),
            .nextrel = try stream.readIntNative(u32),
            .locreloff = try stream.readIntNative(u32),
            .nlocrel = try stream.readIntNative(u32),
        };
        return self;
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const DylibInfoOnly = struct {
    cmd: Command = Command{
        .type = .dyld_info_only,
        .free = Self.free,
    },
    size: u32,
    rebase_info_offset: u32,
    rebase_info_size: u32,
    binding_info_offset: u32,
    binding_info_size: u32,
    weak_binding_info_offset: u32,
    weak_binding_info_size: u32,
    lazy_binding_info_offset: u32,
    lazy_binding_info_size: u32,
    export_info_offset: u32,
    export_info_size: u32,

    const Self = DylibInfoOnly;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .rebase_info_offset = try stream.readIntNative(u32),
            .rebase_info_size = try stream.readIntNative(u32),
            .binding_info_offset = try stream.readIntNative(u32),
            .binding_info_size = try stream.readIntNative(u32),
            .weak_binding_info_offset = try stream.readIntNative(u32),
            .weak_binding_info_size = try stream.readIntNative(u32),
            .lazy_binding_info_offset = try stream.readIntNative(u32),
            .lazy_binding_info_size = try stream.readIntNative(u32),
            .export_info_offset = try stream.readIntNative(u32),
            .export_info_size = try stream.readIntNative(u32),
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const LoadDylinker = struct {
    cmd: Command = Command{
        .type = .load_dylinker,
        .free = Self.free,
    },
    size: u32,
    name_offset: u32,
    name: []u8,

    const Self = LoadDylinker;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var size = try stream.readIntNative(u32);
        var name_offset = try stream.readIntNative(u32);
        var name = try allocator.alloc(u8, size - name_offset);
        _ = try stream.readAll(name);
        return Self{
            .size = size,
            .name_offset = name_offset,
            .name = name,
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {
        allocator.free(@ptrCast(*LoadDylinker, self).name);
    }
};

pub const VersionMinMacOSX = struct {
    cmd: Command = Command{
        .type = .version_min_macosx,
        .free = Self.free,
    },
    size: u32,
    version: u32,
    revision: u32,

    const Self = VersionMinMacOSX;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .version = try stream.readIntNative(u32),
            .revision = try stream.readIntNative(u32),
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const SourceVersion = struct {
    cmd: Command = Command{
        .type = .source_version,
        .free = Self.free,
    },
    size: u32,
    version: u64,

    const Self = SourceVersion;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .version = try stream.readIntNative(u64),
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const Main = struct {
    cmd: Command = Command{
        .type = .main,
        .free = Self.free,
    },
    size: u32,
    entry_offset: u64,
    stack_size: u64,

    const Self = Main;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .entry_offset = try stream.readIntNative(u64),
            .stack_size = try stream.readIntNative(u64),
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const LoadDlib = struct {
    cmd: Command = Command{
        .type = .load_dylib,
        .free = Self.free,
    },
    size: u32,
    name_offset: u32,
    timestamp: u32,
    current_version: u32,
    compatability_version: u32,
    name: []u8,

    const Self = LoadDlib;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        const size = try stream.readIntNative(u32);
        const name_offset = try stream.readIntNative(u32);
        const timestamp = try stream.readIntNative(u32);
        const current_version = try stream.readIntNative(u32);
        const compatability_version = try stream.readIntNative(u32);
        var name = try allocator.alloc(u8, size - name_offset);
        _ = try stream.readAll(name);
        return Self{
            .size = size,
            .name_offset = name_offset,
            .timestamp = timestamp,
            .current_version = current_version,
            .compatability_version = compatability_version,
            .name = name,
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {
        allocator.free(@ptrCast(*Self, self).name);
    }
};

pub const FunctionStarts = struct {
    cmd: Command = Command{
        .type = .function_starts,
        .free = Self.free,
    },
    size: u32,
    data_offset: u32,
    data_size: u32,

    const Self = FunctionStarts;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .data_offset = try stream.readIntNative(u32),
            .data_size = try stream.readIntNative(u32),
        };
    }
    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const DataInCode = struct {
    cmd: Command = Command{
        .type = .data_in_code,
        .free = Self.free,
    },
    size: u32,
    data_offset: u32,
    data_size: u32,

    const Self = DataInCode;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .data_offset = try stream.readIntNative(u32),
            .data_size = try stream.readIntNative(u32),
        };
    }
    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const UUID = struct {
    cmd: Command = Command{
        .type = .uuid,
        .free = Self.free,
    },
    size: u32,
    uuid: [16]u8,

    const Self = UUID;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var size = try stream.readIntNative(u32);
        var uuid = [_]u8{0} ** 16;
        _ = try stream.readAll(&uuid);
        return Self{
            .size = size,
            .uuid = uuid,
        };
    }

    pub fn free(self: *Command, allocator: *Allocator) void {}
};

pub const Header = packed struct {
    magic: u32 = 0,
    cpu_type: cpu.Type = .any,
    cpu_sub_type: u32 = 0,
    file_type: FileType = .object,
    number_of_load_commands: u32 = 0,
    size_of_load_commands: u32 = 0,
    flags: u32 = 0,
    reserved: u32 = 0,

    pub fn print(h: Header, stdout: File.OutStream) !void {
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
};

pub const Section = struct {
    data: []u8,

    const Self = Section;

    fn read(file: File, allocator: *Allocator, section_header: *const Segment64Header) !Self {
        try file.seekTo(section_header.offset);
        var data = try allocator.alloc(u8, section_header.size);
        _ = try file.read(data);
        return Self{ .data = data };
    }

    fn free(self: Self, allocator: *Allocator) void {
        allocator.free(self.data);
    }
};

pub const DynamicLoaderInfo = struct {
    rebase_info: []u8,
    bindings_info: []u8,
    weak_bindings_info: []u8,
    lazy_bindigs_info: []u8,
    export_info: []u8,

    const Self = DynamicLoaderInfo;
    fn read(file: File, allocator: *Allocator, header: *DylibInfoOnly) !Self {
        var self: Self = undefined;

        self.rebase_info = try allocator.alloc(u8, header.rebase_info_size);
        try file.seekTo(header.rebase_info_offset);
        _ = try file.read(self.rebase_info);

        self.bindings_info = try allocator.alloc(u8, header.binding_info_size);
        try file.seekTo(header.binding_info_offset);
        _ = try file.read(self.bindings_info);

        self.weak_bindings_info = try allocator.alloc(u8, header.weak_binding_info_size);
        try file.seekTo(header.weak_binding_info_offset);
        _ = try file.read(self.weak_bindings_info);

        self.lazy_bindigs_info = try allocator.alloc(u8, header.lazy_binding_info_size);
        try file.seekTo(header.lazy_binding_info_offset);
        _ = try file.read(self.lazy_bindigs_info);

        self.export_info = try allocator.alloc(u8, header.export_info_size);
        try file.seekTo(header.export_info_offset);
        _ = try file.read(self.export_info);

        return self;
    }

    fn free(self: Self, allocator: *Allocator) void {
        allocator.free(self.rebase_info);
        allocator.free(self.bindings_info);
        allocator.free(self.weak_bindings_info);
        allocator.free(self.lazy_bindigs_info);
        allocator.free(self.export_info);
    }
};

pub const ObjFile = struct {
    header: Header,
    load_commands: []usize,
    sections: []Section,
    dyld_info: DynamicLoaderInfo,

    const Self = ObjFile;
    pub fn read(file: File, allocator: *Allocator) !Self {
        var stream = file.reader();
        var header = try stream.readStruct(Header);
        var i: u32 = 0;
        var load_commands = try allocator.alloc(usize, header.number_of_load_commands);

        while (i < header.number_of_load_commands) : (i += 1) {
            var cmdInt = try stream.readIntNative(u32);
            var cmd = @intToEnum(Type, cmdInt);
            switch (cmd) {
                .segment64 => {
                    load_commands[i] = try Self.create_command(Segment64, stream, allocator);
                },
                .symtab => {
                    load_commands[i] = try Self.create_command(Symtab, stream, allocator);
                },
                .dysymtab => {
                    load_commands[i] = try Self.create_command(Dysymtab, stream, allocator);
                },
                .dyld_info_only => {
                    load_commands[i] = try Self.create_command(DylibInfoOnly, stream, allocator);
                },
                .load_dylinker => {
                    load_commands[i] = try Self.create_command(LoadDylinker, stream, allocator);
                },
                .version_min_macosx => {
                    load_commands[i] = try Self.create_command(VersionMinMacOSX, stream, allocator);
                },
                .source_version => {
                    load_commands[i] = try Self.create_command(SourceVersion, stream, allocator);
                },
                .main => {
                    load_commands[i] = try Self.create_command(Main, stream, allocator);
                },
                .load_dylib => {
                    load_commands[i] = try Self.create_command(LoadDlib, stream, allocator);
                },
                .function_starts => {
                    load_commands[i] = try Self.create_command(FunctionStarts, stream, allocator);
                },
                .data_in_code => {
                    load_commands[i] = try Self.create_command(DataInCode, stream, allocator);
                },
                .uuid => {
                    load_commands[i] = try Self.create_command(UUID, stream, allocator);
                },
                else => {
                    load_commands[i] = 0;
                    var size = try stream.readIntNative(u32);
                    try stream.skipBytes(size - 8);
                },
            }
        }

        var sections: []Section = undefined;
        var dyld_info: DynamicLoaderInfo = undefined;
        sections.len = 0;
        for (load_commands) |command_pointer| {
            var cmd = @intToPtr(*Command, command_pointer);

            switch (cmd.type) {
                .segment64 => {
                    var segment = @ptrCast(*Segment64, cmd);
                    var current_sections: []Section = try allocator.alloc(Section, segment.sections.len);

                    var j: u32 = 0;
                    for (segment.sections) |section_header| {
                        current_sections[j] = try Section.read(file, allocator, &section_header);
                        j += 1;
                    }
                    if (sections.len == 0) {
                        sections = current_sections;
                    } else {
                        var current_size = sections.len - 1;
                        sections = try allocator.realloc(sections, sections.len + current_sections.len);
                        std.mem.copy(Section, sections[current_size..], current_sections);
                        allocator.free(current_sections);
                    }
                },
                .dyld_info_only => {
                    var segment = @ptrCast(*DylibInfoOnly, cmd);
                    dyld_info = try DynamicLoaderInfo.read(file, allocator, segment);

                },
                else => {},
            }
        }

        return Self{
            .header = header,
            .load_commands = load_commands,
            .sections = sections,
            .dyld_info = dyld_info,
        };
    }

    fn create_command(comptime command_type: type, stream: File.Reader, allocator: *Allocator) !usize {
        var command = try allocator.create(command_type);
        command.* = try command_type.read(stream, allocator);
        return @ptrToInt(command);
    }

    pub fn print(self: Self, stdout: File.OutStream) !void {
        try stdout.print("Sections:\n", .{});
        for (self.sections) |section| {
            try stdout.print(" Section size: {}\n", .{section.data.len});
        }

        try stdout.print("Dynamic Loader info:\n", .{});
        try stdout.print(" Rebase: {}\n", .{self.dyld_info.rebase_info.len});
        try stdout.print(" Bindings: {}\n", .{self.dyld_info.bindings_info.len});
        try stdout.print(" Weak: {}\n", .{self.dyld_info.weak_bindings_info.len});
        try stdout.print(" Lazy: {}\n", .{self.dyld_info.lazy_bindigs_info.len});
        try stdout.print(" Export: {}\n", .{self.dyld_info.export_info.len});
    }

    pub fn free(self: Self, allocator: *Allocator) void {
        for (self.load_commands) |load_command| {
            var cmd = @intToPtr(*Command, load_command);
            cmd.free(cmd, allocator);
        }
        allocator.free(self.load_commands);

        for (self.sections) |section| {
            section.free(allocator);
        }
        allocator.free(self.sections);
    }
};
