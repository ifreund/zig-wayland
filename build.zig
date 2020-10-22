const mem = @import("std").mem;
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
        const example_names = [_][]const u8{ "globals", "listener", "seats" };
        for (example_names) |example| {
            const path = mem.concat(b.allocator, u8, &[_][]const u8{ "example/", example, ".zig" }) catch unreachable;
            const exe = b.addExecutable(example, path);
            exe.setTarget(target);
            exe.setBuildMode(mode);

            exe.linkLibC();
            exe.linkSystemLibrary("wayland-client");

            // Requires the scanner to have been run for this to build
            // TODO: integrate scanner with build system
            exe.addPackagePath("wayland", "wayland.zig");

            exe.install();
        }
    }
}
