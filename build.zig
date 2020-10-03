const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const examples = b.option(
        bool,
        "examples",
        "Set to true to build examples",
    ) orelse false;

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

    if (examples) {
        const globals = b.addExecutable("globals", "example/globals.zig");
        globals.setTarget(target);
        globals.setBuildMode(mode);

        globals.linkLibC();
        globals.linkSystemLibrary("wayland-client");

        // Requires the scanner to have been run for this to build
        // TODO: integrate scanner with build system
        globals.addPackagePath("wayland", "wayland.zig");

        globals.install();
    }
}
