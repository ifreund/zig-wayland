const std = @import("std");
test {
    std.testing.refAllDeclsRecursive(@import("wayland"));
}
