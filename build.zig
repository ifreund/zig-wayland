const std = @import("std");
const Build = std.Build;
const fs = std.fs;
const mem = std.mem;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b);
    defer scanner.finish();

    const wayland = b.createModule(.{ .source_file = scanner.result });

    scanner.generate("wl_compositor", 1);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_seat", 2);
    scanner.generate("wl_output", 1);

    inline for ([_][]const u8{ "globals", "list", "listener", "seats" }) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = .{ .path = "example/" ++ example ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.addModule("wayland", wayland);
        scanner.addCSource(exe);
        exe.linkLibC();
        exe.linkSystemLibrary("wayland-client");

        b.installArtifact(exe);
    }

    const test_step = b.step("test", "Run the tests");
    {
        const scanner_tests = b.addTest(.{
            .root_source_file = .{ .path = "src/scanner.zig" },
            .target = target,
            .optimize = optimize,
        });

        scanner_tests.addModule("wayland", wayland);

        test_step.dependOn(&scanner_tests.step);
    }
    {
        const ref_all = b.addTest(.{
            .root_source_file = .{ .path = "src/ref_all.zig" },
            .target = target,
            .optimize = optimize,
        });

        ref_all.addModule("wayland", wayland);
        scanner.addCSource(ref_all);
        ref_all.linkLibC();
        ref_all.linkSystemLibrary("wayland-client");
        ref_all.linkSystemLibrary("wayland-server");
        ref_all.linkSystemLibrary("wayland-egl");
        ref_all.linkSystemLibrary("wayland-cursor");
        test_step.dependOn(&ref_all.step);
    }
}

pub const Scanner = struct {
    run: *Build.Step.Run,
    result: Build.FileSource,

    /// Path to the system protocol directory, stored to avoid invoking pkg-config N times.
    system_protocol_path: []const u8,

    // TODO remove these when the workaround for zig issue #131 is no longer needed.
    compiles: std.ArrayListUnmanaged(*Build.Step.Compile) = .{},
    protocols: std.ArrayListUnmanaged([]const u8) = .{},

    pub fn create(b: *Build) *Scanner {
        const zig_wayland_dir = fs.path.dirname(@src().file) orelse ".";
        const exe = b.addExecutable(.{
            .name = "zig-wayland-scanner",
            .root_source_file = .{ .path = b.pathJoin(&.{ zig_wayland_dir, "src/scanner.zig" }) },
        });

        const run = b.addRunArtifact(exe);

        run.addArg("-o");
        const result = run.addOutputFileArg("wayland.zig");

        const scanner = b.allocator.create(Scanner) catch @panic("OOM");
        scanner.* = .{
            .run = run,
            .result = result,
            .system_protocol_path = blk: {
                const pc_output = b.exec(&.{ "pkg-config", "--variable=pkgdatadir", "wayland-protocols" });
                break :blk mem.trim(u8, pc_output, &std.ascii.whitespace);
            },
        };

        {
            const pc_output = b.exec(&.{ "pkg-config", "--variable=pkgdatadir", "wayland-scanner" });
            const wayland_dir = mem.trim(u8, pc_output, &std.ascii.whitespace);
            const wayland_xml = b.pathJoin(&.{ wayland_dir, "wayland.xml" });

            run.addArg("-i");
            run.addFileSourceArg(.{ .path = wayland_xml });
        }

        return scanner;
    }

    /// Scan protocol xml provided by the wayland-protocols package
    /// at the given relative path (e.g. "stable/xdg-shell/xdg-shell.xml")
    pub fn addSystemProtocol(scanner: *Scanner, path: []const u8) void {
        const b = scanner.run.step.owner;
        const absolute_path = b.pathJoin(&.{ scanner.system_protocol_path, path });

        scanner.run.addArg("-i");
        scanner.run.addFileSourceArg(.{ .path = absolute_path });

        scanner.protocols.append(b.allocator, absolute_path) catch @panic("OOM");
    }

    /// Scan the protocol xml at the given path
    pub fn addCustomProtocol(scanner: *Scanner, path: []const u8) void {
        const b = scanner.run.step.owner;

        scanner.run.addArg("-i");
        scanner.run.addFileSourceArg(.{ .path = path });

        scanner.protocols.append(b.allocator, b.dupe(path)) catch @panic("OOM");
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

    /// Generate and add the necessary C source to the compilation unit.
    /// Once https://github.com/ziglang/zig/issues/131 is resolved we can remove this.
    pub fn addCSource(scanner: *Scanner, compile: *Build.Step.Compile) void {
        scanner.compiles.append(scanner.run.step.owner.allocator, compile) catch @panic("OOM");
    }

    /// This only exists as we need to generate and link C code due to the fact that we can't
    /// create self-referential static data in zig yet.
    /// TODO remove this after https://github.com/ziglang/zig/issues/131 is implemented.
    pub fn finish(scanner: *Scanner) void {
        const b = scanner.run.step.owner;

        for (scanner.protocols.items) |protocol| {
            const cmd = b.addSystemCommand(&.{ "wayland-scanner", "private-code", protocol });

            // Extension is .xml, so slice off the last 4 characters
            const basename = fs.path.basename(protocol);
            const basename_no_ext = basename[0..(basename.len - 4)];
            const out_name = mem.concat(b.allocator, u8, &.{ basename_no_ext, "-protocol.c" }) catch @panic("OOM");

            const c_source = cmd.addOutputFileArg(out_name);

            for (scanner.compiles.items) |compile| {
                compile.addCSourceFileSource(.{
                    .source = c_source,
                    .args = &.{ "-std=c99", "-O2" },
                });
            }
        }
    }
};
