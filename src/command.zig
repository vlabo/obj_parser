const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

pub const Type = enum(u32) {
    undef =  0x0,
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

pub const Segment64 = struct {
    cmd: Type = .segment_64,
    size: u32 = 0,
    segname: [16]u8 = [_]u8{0} ** 16,
    vmaddr: u64 = 0,
    vmsize: u64 = 0,
    fileoff: u64 = 0,
    filesize: u64 = 0,
    maxprot: u32 = 0,
    initprot: u32 = 0,
    nsects: u32 = 0,
    flags: u32 = 0,

    const Self = Segment64;

    pub fn read(stream: File.Reader) !Self {
        var self = Self{};
        self.size = try stream.readIntNative(u32);
        _ = try stream.readAll(&self.segname);
        self.vmaddr = try stream.readIntNative(u64);
        self.vmsize = try stream.readIntNative(u64);
        self.fileoff = try stream.readIntNative(u64);
        self.filesize = try stream.readIntNative(u64);
        self.maxprot = try stream.readIntNative(u32);
        self.initprot = try stream.readIntNative(u32);
        self.nsects = try stream.readIntNative(u32);
        self.flags = try stream.readIntNative(u32);
        try stream.skipBytes(self.size - @sizeOf(Self));
        return self;
    }
};

pub const Symtab = struct {
    cmd: Type = .symtab,
    size: u32 = 0,
    symoff: u32 = 0,
    nsyms: u32 = 0,
    stroff: u32 = 0,
    strsize: u32 = 0,

    const Self = Symtab;

    pub fn read(stream: File.Reader) !Self {
        var self = Self{};
        self.size = try stream.readIntNative(u32);
        self.symoff = try stream.readIntNative(u32);
        self.nsyms = try stream.readIntNative(u32);
        self.stroff = try stream.readIntNative(u32);
        self.strsize = try stream.readIntNative(u32);
        return self;
    }
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

    pub fn read(stream: File.Reader) !Self {
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

    pub fn read(stream: File.Reader) !Self {
        var self = Self{};
        self.size = try stream.readIntNative(u32);
        self.rebase_info_offset = try stream.readIntNative(u32);
        self.rebase_info_size = try stream.readIntNative(u32);
        self.binding_info_offset = try stream.readIntNative(u32);
        self.binding_info_size = try stream.readIntNative(u32);
        self.weak_binding_info_offset = try stream.readIntNative(u32);
        self.weak_binding_info_size = try stream.readIntNative(u32);
        self.lazy_binding_info_offset = try stream.readIntNative(u32);
        self.lazy_binding_info_size = try stream.readIntNative(u32);
        self.export_info_offset = try stream.readIntNative(u32);
        self.export_info_size = try stream.readIntNative(u32);
        return self;
    }
};

pub const LoadDylinker = struct {
    cmd: Type = .load_dylinker,
    size: u32 = 0,
    name_offset: u32 = 0,
    name: []u8,

    const Self = LoadDylinker;

    pub fn read(stream: File.Reader, allocator: *Allocator) !Self {
        var size = try stream.readIntNative(u32);
        var name_offset = try stream.readIntNative(u32);
        var name = try allocator.alloc(u8, size - name_offset);
        _ = try stream.readAll(name);
        return Self {
            .size = size,
            .name_offset = name_offset,
            .name = name,
        };
    }

    pub fn free(self: Self, allocator: *Allocator) void {
        allocator.destroy(&self.name);
    }
};
