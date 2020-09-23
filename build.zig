const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    {
        const scanner = b.addExecutable("scanner", "scanner.zig");
        scanner.setTarget(target);
        scanner.setBuildMode(mode);

        scanner.linkLibC();
        scanner.linkSystemLibrary("expat");

        scanner.install();
    }

    {
        const scanner_test = b.addTest("scanner.zig");
        scanner_test.setTarget(target);
        scanner_test.setBuildMode(mode);

        scanner_test.linkLibC();
        scanner_test.linkSystemLibrary("expat");

        const test_step = b.step("test", "Run the tests");
        test_step.dependOn(&scanner_test.step);
    }
}
