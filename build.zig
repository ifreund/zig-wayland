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
        const test_files = [_][]const u8{ "scanner.zig", "src/common_core.zig" };

        const test_step = b.step("test", "Run the tests");
        for (test_files) |file| {
            const t = b.addTest(file);
            t.setTarget(target);
            t.setBuildMode(mode);

            t.linkLibC();
            t.linkSystemLibrary("expat");

            test_step.dependOn(&t.step);
        }
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

    if (examples) {
        const listener = b.addExecutable("listener", "example/listener.zig");
        listener.setTarget(target);
        listener.setBuildMode(mode);

        // Requires the scanner to have been run for this to build
        // TODO: integrate scanner with build system
        listener.addPackagePath("wayland", "wayland.zig");

        listener.install();
    }
}
