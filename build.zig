const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const scanner = b.addExecutable("scanner", "scanner.zig");
    scanner.setTarget(target);
    scanner.setBuildMode(mode);

    scanner.linkLibC();
    scanner.linkSystemLibrary("expat");

    scanner.install();
}
