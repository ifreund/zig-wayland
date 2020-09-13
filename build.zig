const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("globals", "example/globals.zig");
    exe.addPackagePath("wayland", "wayland.zig");
}
