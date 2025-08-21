const std = @import("std");
const Build = std.Build;
const fs = std.fs;
const mem = std.mem;

pub fn build(b: *Build) void {
    const enable_tests = b.option(bool, "enable-tests", "allow running tests") orelse false;

    if (!enable_tests) return;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{
        // Use an unchanging vendored wayland.xml for the tests
        // to make the snapshot test reliable.
        .wayland_xml = b.path("test/wayland.xml"),
    });

    const wayland = b.createModule(.{
        .root_source_file = scanner.result,
        .target = target,
        .optimize = optimize,
    });

    scanner.generate("wl_compositor", 5);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_seat", 5);
    scanner.generate("wl_output", 4);

    inline for ([_][]const u8{ "globals", "list", "listener", "seats" }) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_module = b.createModule(.{
                .root_source_file = b.path("example/" ++ example ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        exe.root_module.addImport("wayland", wayland);
        exe.linkLibC();
        exe.linkSystemLibrary("wayland-client");

        b.installArtifact(exe);
    }

    const test_step = b.step("test", "Run the tests");
    {
        const ref_all = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/ref_all.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        ref_all.root_module.addImport("wayland", wayland);
        ref_all.linkLibC();
        ref_all.linkSystemLibrary("wayland-client");
        ref_all.linkSystemLibrary("wayland-server");
        ref_all.linkSystemLibrary("wayland-egl");
        ref_all.linkSystemLibrary("wayland-cursor");

        const run_ref_all = b.addRunArtifact(ref_all);
        test_step.dependOn(&run_ref_all.step);
    }
    {
        const snapshot = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/snapshot.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        const options = b.addOptions();
        options.addOptionPath("snapshot_actual", scanner.result);

        snapshot.root_module.addOptions("build_options", options);

        const run_snapshot = b.addRunArtifact(snapshot);
        test_step.dependOn(&run_snapshot.step);
    }
}

const zig_wayland_build_zig = @This();

pub const Scanner = struct {
    run: *Build.Step.Run,
    result: Build.LazyPath,

    wayland_protocols: Build.LazyPath,

    pub const Options = struct {
        /// Path to the wayland.xml file.
        /// If null, the output of `pkg-config --variable=pkgdatadir wayland-scanner` will be used.
        wayland_xml: ?Build.LazyPath = null,
        /// Path to the wayland-protocols installation.
        /// If null, the output of `pkg-config --variable=pkgdatadir wayland-protocols` will be used.
        wayland_protocols: ?Build.LazyPath = null,
    };

    pub fn create(b: *Build, options: Options) *Scanner {
        const wayland_xml: Build.LazyPath = options.wayland_xml orelse blk: {
            const pc_output = b.run(&.{ "pkg-config", "--variable=pkgdatadir", "wayland-scanner" });
            break :blk .{
                .cwd_relative = b.pathJoin(&.{ mem.trim(u8, pc_output, &std.ascii.whitespace), "wayland.xml" }),
            };
        };
        const wayland_protocols: Build.LazyPath = options.wayland_protocols orelse blk: {
            const pc_output = b.run(&.{ "pkg-config", "--variable=pkgdatadir", "wayland-protocols" });
            break :blk .{
                .cwd_relative = mem.trim(u8, pc_output, &std.ascii.whitespace),
            };
        };

        const exe = b.addExecutable(.{
            .name = "zig-wayland-scanner",
            .root_module = b.createModule(.{
                .root_source_file = blk: {
                    if (b.available_deps.len > 0) {
                        break :blk b.dependencyFromBuildZig(zig_wayland_build_zig, .{}).path("src/scanner.zig");
                    } else {
                        break :blk b.path("src/scanner.zig");
                    }
                },
                .target = b.graph.host,
            }),
        });

        const run = b.addRunArtifact(exe);

        run.addArg("-o");
        const result = run.addOutputFileArg("wayland.zig");

        run.addArg("-i");
        run.addFileArg(wayland_xml);

        const scanner = b.allocator.create(Scanner) catch @panic("OOM");
        scanner.* = .{
            .run = run,
            .result = result,
            .wayland_protocols = wayland_protocols,
        };

        return scanner;
    }

    /// Scan protocol xml provided by the wayland-protocols package at the given path
    /// relative to the wayland-protocols installation. (e.g. "stable/xdg-shell/xdg-shell.xml")
    pub fn addSystemProtocol(scanner: *Scanner, sub_path: []const u8) void {
        const b = scanner.run.step.owner;

        scanner.run.addArg("-i");
        scanner.run.addFileArg(scanner.wayland_protocols.path(b, sub_path));
    }

    /// Scan the protocol xml at the given path.
    pub fn addCustomProtocol(scanner: *Scanner, path: Build.LazyPath) void {
        scanner.run.addArg("-i");
        scanner.run.addFileArg(path);
    }

    /// Generate code for the given global interface at the given version,
    /// as well as all interfaces that can be created using it at that version.
    /// If the version found in the protocol xml is less than the requested version,
    /// an error will be printed and code generation will fail.
    /// Code is always generated for wl_display, wl_registry, wl_callback, and wl_buffer.
    pub fn generate(scanner: *Scanner, global_interface: []const u8, version: u32) void {
        var buffer: [32]u8 = undefined;
        const version_str = std.fmt.bufPrint(&buffer, "{}", .{version}) catch unreachable;

        scanner.run.addArgs(&.{ "-g", global_interface, version_str });
    }
};
