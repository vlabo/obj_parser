const TypeMask = enum (i32) {
    x64 = 0x01000000,
    x64_32 = 0x02000000,
};

fn intel_subtype(f: comptime i32, m: comptime i32) i32 {
    return f + (m << 4);
}

pub const CpuIntelSubType = enum (i32) {
    I386 = intel_subtype(3, 0),
    I486 = intel_subtype(4, 0),
    I486SX = intel_subtype(4, 8),
    I586 = intel_subtype(5, 0),
    PENT = intel_subtype(5, 0),
    PENTPRO = intel_subtype(6, 1),
    PENTII_M3 = intel_subtype(6, 3),
    PENTII_M5 = intel_subtype(6, 5),
    CELERON = intel_subtype(7, 6),
    CELERON_MOBILE = intel_subtype(7, 7),
    PENTIUM_3 = intel_subtype(8, 0),
    PENTIUM_3_M = intel_subtype(8, 1),
    PENTIUM_3_XEON = intel_subtype(8, 2),
    PENTIUM_M = intel_subtype(9, 0),
    PENTIUM_4 = intel_subtype(10, 0),
    PENTIUM_4_M = intel_subtype(10, 1),
    ITANIUM = intel_subtype(11, 0),
    ITANIUM_2 = intel_subtype(11, 1),
    XEON = intel_subtype(12, 0),
    XEON_MP = intel_subtype(12, 1),
};

pub const Type = enum (i32) {
    any = -1,
    vax = 1,
    mc680x0 = 6,
    x86 = 7,
    x86_64 = 7 | @enumToInt(TypeMask.x64),
    mips = 8,
    mc9800 = 10,
    hppa = 11,
    arm = 12,
    arm64 = 12 | @enumToInt(TypeMask.x64),
    arm64_32 = 12 | @enumToInt(TypeMask.x64_32),
    mc88000 = 13,
    sparc = 14,
    i860 = 15,
    power_pc = 18,
    power_pc64 = 18 | @enumToInt(TypeMask.x64),
};
