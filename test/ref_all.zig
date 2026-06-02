const std = @import("std");

pub fn refAllDeclsRecursive(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        if (@TypeOf(@field(T, decl)) == type) {
            switch (@typeInfo(@field(T, decl))) {
                .@"struct", .@"enum", .@"union", .@"opaque" => refAllDeclsRecursive(@field(T, decl)),
                else => {},
            }
        }
        _ = &@field(T, decl);
    }
}

test {
    refAllDeclsRecursive(@import("wayland"));
}
