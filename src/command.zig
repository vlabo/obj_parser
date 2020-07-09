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

    fn to_type(self: Type) comptime type {
        switch (self) {
            .segment64 => {
                return Segment64;
            },
            .symtab => {
                return Symtab;
            },
            .dysymtab => {
                return Dysymtab;
            },
            .dyld_info_only => {
                return DylibInfoOnly;
            },
            .load_dylinker => {
                return LoadDylinker;
            },
            .version_min_macosx => {
                return VersionMinMacOSX;
            },
            .source_version => {
                return SourceVersion;
            },
            .main => {
                return Main;
            },
            .load_dylib => {
                return LoadDlib;
            },
            .function_starts => {
                return FunctionStarts;
            },
            .data_in_code => {
                return DataInCode;
            },
            .uuid => {
                return UUID;
            },
            else => {
                return void;
            },
        }
    }
};

pub const Segment64 = struct {
    cmd: Type = .segment64,
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

    pub fn free(self: Self, allocator: *Allocator) void {
        allocator.free(self.sections);
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
    cmd: Type = .symtab,
    size: u32 = 0,
    symoff: u32 = 0,
    nsyms: u32 = 0,
    stroff: u32 = 0,
    strsize: u32 = 0,

    const Self = Symtab;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var self = Self{};
        self.size = try stream.readIntNative(u32);
        self.symoff = try stream.readIntNative(u32);
        self.nsyms = try stream.readIntNative(u32);
        self.stroff = try stream.readIntNative(u32);
        self.strsize = try stream.readIntNative(u32);
        return self;
    }

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const Dysymtab = struct {
    cmd: Type = .dysymtab,
    cmdsize: u32 = 0,
    ilocalsym: u32 = 0,
    nlocalsym: u32 = 0,
    iextdefsym: u32 = 0,
    nextdefsym: u32 = 0,
    iundefsym: u32 = 0,
    nundefsym: u32 = 0,
    tocoff: u32 = 0,
    ntoc: u32 = 0,
    modtaboff: u32 = 0,
    nmodtab: u32 = 0,
    extrefsymoff: u32 = 0,
    nextrefsyms: u32 = 0,
    indirectsymoff: u32 = 0,
    nindirectsyms: u32 = 0,
    extreloff: u32 = 0,
    nextrel: u32 = 0,
    locreloff: u32 = 0,
    nlocrel: u32 = 0,

    const Self = Dysymtab;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var self = Self{};
        self.cmdsize = try stream.readIntNative(u32);
        self.ilocalsym = try stream.readIntNative(u32);
        self.nlocalsym = try stream.readIntNative(u32);
        self.iextdefsym = try stream.readIntNative(u32);
        self.nextdefsym = try stream.readIntNative(u32);
        self.iundefsym = try stream.readIntNative(u32);
        self.nundefsym = try stream.readIntNative(u32);
        self.tocoff = try stream.readIntNative(u32);
        self.ntoc = try stream.readIntNative(u32);
        self.modtaboff = try stream.readIntNative(u32);
        self.nmodtab = try stream.readIntNative(u32);
        self.extrefsymoff = try stream.readIntNative(u32);
        self.nextrefsyms = try stream.readIntNative(u32);
        self.indirectsymoff = try stream.readIntNative(u32);
        self.nindirectsyms = try stream.readIntNative(u32);
        self.extreloff = try stream.readIntNative(u32);
        self.nextrel = try stream.readIntNative(u32);
        self.locreloff = try stream.readIntNative(u32);
        self.nlocrel = try stream.readIntNative(u32);
        return self;
    }

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const DylibInfoOnly = struct {
    cmd: Type = .dyld_info_only,
    size: u32 = 0,
    rebase_info_offset: u32 = 0,
    rebase_info_size: u32 = 0,
    binding_info_offset: u32 = 0,
    binding_info_size: u32 = 0,
    weak_binding_info_offset: u32 = 0,
    weak_binding_info_size: u32 = 0,
    lazy_binding_info_offset: u32 = 0,
    lazy_binding_info_size: u32 = 0,
    export_info_offset: u32 = 0,
    export_info_size: u32 = 0,

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

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const LoadDylinker = struct {
    cmd: Type = .load_dylinker,
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

    pub fn free(self: Self, allocator: *Allocator) void {
        allocator.free(self.name);
    }
};

pub const VersionMinMacOSX = struct {
    cmd: Type = .version_min_macosx,
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

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const SourceVersion = struct {
    cmd: Type = .source_version,
    size: u32,
    version: u64,

    const Self = SourceVersion;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        return Self{
            .size = try stream.readIntNative(u32),
            .version = try stream.readIntNative(u64),
        };
    }

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const Main = struct {
    cmd: Type = .main,
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

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const LoadDlib = struct {
    cmd: Type = .load_dylib,
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

    pub fn free(self: Self, allocator: *Allocator) void {
        allocator.free(self.name);
    }
};

pub const FunctionStarts = struct {
    cmd: Type = .function_starts,
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

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const DataInCode = struct {
    cmd: Type = .data_in_code,
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

    pub fn free(self: Self, allocator: *Allocator) void {}
};

pub const UUID = struct {
    cmd: Type = .uuid,
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

    pub fn free(self: Self, allocator: *Allocator) void {}
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

pub const ObjFile = struct {
    header: Header,
    load_commands: []usize,

    const Self = ObjFile;
    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var header = try stream.readStruct(Header);
        var i: u32 = 0;
        var load_commands = try allocator.alloc(usize, header.number_of_load_commands);

        while (i < header.number_of_load_commands) : (i += 1) {
            var cmdInt = try stream.readIntNative(u32);
            var cmd = @intToEnum(Type, cmdInt);
            switch (cmd) {
                .segment64 => {
                    load_commands[i] = try Self.create_command(Type.segment64.to_type(), stream, allocator);
                },
                .symtab => {
                    load_commands[i] = try Self.create_command(Type.symtab.to_type(), stream, allocator);
                },
                .dysymtab => {
                    load_commands[i] = try Self.create_command(Type.dysymtab.to_type(), stream, allocator);
                },
                .dyld_info_only => {
                    load_commands[i] = try Self.create_command(Type.dyld_info_only.to_type(), stream, allocator);
                },
                .load_dylinker => {
                    load_commands[i] = try Self.create_command(Type.load_dylinker.to_type(), stream, allocator);
                },
                .version_min_macosx => {
                    load_commands[i] = try Self.create_command(Type.version_min_macosx.to_type(), stream, allocator);
                },
                .source_version => {
                    load_commands[i] = try Self.create_command(Type.source_version.to_type(), stream, allocator);
                },
                .main => {
                    load_commands[i] = try Self.create_command(Type.main.to_type(), stream, allocator);
                },
                .load_dylib => {
                    load_commands[i] = try Self.create_command(Type.load_dylib.to_type(), stream, allocator);
                },
                .function_starts => {
                    load_commands[i] = try Self.create_command(Type.function_starts.to_type(), stream, allocator);
                },
                .data_in_code => {
                    load_commands[i] = try Self.create_command(Type.data_in_code.to_type(), stream, allocator);
                },
                .uuid => {
                    load_commands[i] = try Self.create_command(Type.uuid.to_type(), stream, allocator);
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

    pub fn print(self: Self, stdout: File.OutStream) !void {
        for (self.load_commands) |load_command| {
            if (load_command != 0) {
                var command_type = @intToPtr(*Type, load_command);

                switch (command_type.*) {
                    .segment64 => {
                        var command = @intToPtr(*Segment64, load_command);
                        try stdout.print(" Segment 64 - {}\n", .{command.segment_name});

                        var sections_count = command.number_of_sections;
                        for (command.sections) |section| {
                            try stdout.print("\t SegmentHeader - {}\n", .{section.section_name});
                        }
                    },
                    .symtab => {
                        var command = @intToPtr(*Symtab, load_command);
                        try stdout.print(" Symtab \n", .{});
                    },
                    .dysymtab => {
                        var command = @intToPtr(*Dysymtab, load_command);
                        try stdout.print(" Dysymtab \n", .{});
                    },
                    .dyld_info_only => {
                        var command = @intToPtr(*DylibInfoOnly, load_command);
                        try stdout.print(" SegmentDylibInfoOnly \n", .{});
                    },
                    .load_dylinker => {
                        var command = @intToPtr(*LoadDylinker, load_command);
                        try stdout.print(" SegmentLoadDylinker - {} \n", .{command.name});
                    },
                    .version_min_macosx => {
                        var command = @intToPtr(*VersionMinMacOSX, load_command);
                        try stdout.print(" VersionMinMacOSX - {} \n", .{command.version});
                    },
                    .source_version => {
                        var command = @intToPtr(*SourceVersion, load_command);
                        try stdout.print(" SourceVersion - {} \n", .{command.version});
                    },
                    .main => {
                        var command = @intToPtr(*Main, load_command);
                        try stdout.print(" Main - {}\n", .{command.entry_offset});
                    },
                    .load_dylib => {
                        var command = @intToPtr(*LoadDlib, load_command);
                        try stdout.print(" LoadDlib - {} \n", .{command.name});
                    },
                    .function_starts => {
                        var command = @intToPtr(*FunctionStarts, load_command);
                        try stdout.print(" FunctionStarts\n", .{});
                    },
                    .data_in_code => {
                        var command = @intToPtr(*DataInCode, load_command);
                        try stdout.print(" DataInCode\n", .{});
                    },
                    .uuid => {
                        var command = @intToPtr(*UUID, load_command);
                        try stdout.print(" UUID\n", .{});
                    },
                    .undef => {
                        std.debug.panic("Undefined command\n", .{});
                    },

                    else => {},
                }
            }
        }
    }

    fn free_list(self: Self, allocator: *Allocator) void {
        for(self.load_commands) |load_command| {
            var command_type = @intToPtr(*Type, load_command).*;
            switch (command_type) {
                .segment64 => {
                    @intToPtr(*Type.segment64.to_type(), load_command).free(allocator);
                },
                .symtab => {
                    @intToPtr(*Type.symtab.to_type(), load_command).free(allocator);
                },
                .dysymtab => {
                    @intToPtr(*Type.dysymtab.to_type(), load_command).free(allocator);
                },
                .dyld_info_only => {
                    @intToPtr(*Type.dyld_info_only.to_type(), load_command).free(allocator);
                },
                .load_dylinker => {
                    @intToPtr(*Type.load_dylinker.to_type(), load_command).free(allocator);
                },
                .version_min_macosx => {
                    @intToPtr(*Type.version_min_macosx.to_type(), load_command).free(allocator);
                },
                .source_version => {
                    @intToPtr(*Type.source_version.to_type(), load_command).free(allocator);
                },
                .main => {
                    @intToPtr(*Type.main.to_type(), load_command).free(allocator);
                },
                .load_dylib => {
                    @intToPtr(*Type.load_dylib.to_type(), load_command).free(allocator);
                },
                .function_starts => {
                    @intToPtr(*Type.function_starts.to_type(), load_command).free(allocator);
                },
                .data_in_code => {
                    @intToPtr(*Type.data_in_code.to_type(), load_command).free(allocator);
                },
                .uuid => {
                    @intToPtr(*Type.uuid.to_type(), load_command).free(allocator);
                },
                else => {},
            }
        }
    }
    pub fn free(self: Self, allocator: *Allocator) void {
        self.free_list(allocator);
        allocator.free(self.load_commands);
    }
};
