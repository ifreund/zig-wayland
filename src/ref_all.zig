// Note: this requires the fix made in https://github.com/ziglang/zig/pull/7178
// to work properly with zig-wayland's use of usingnamespace
fn refAllDeclsRecursive(comptime T: type) void {
    const decls = switch (@typeInfo(T)) {
        .Struct => |info| info.decls,
        .Union => |info| info.decls,
        .Enum => |info| info.decls,
        .Opaque => |info| info.decls,
        else => return,
    };
    inline for (decls) |decl| {
        switch (decl.data) {
            .Type => |T2| refAllDeclsRecursive(T2),
            else => _ = decl,
        }
    }
}

test "" {
    refAllDeclsRecursive(@import("wayland"));
}
