const std = @import("std");
const zbs = std.build;
const fs = std.fs;
const mem = std.mem;

pub fn build(b: *zbs.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const scanner = ScanProtocolsStep.create(b);
    const wayland = zbs.Pkg{
        .name = "wayland",
        .path = .{ .generated = &scanner.result },
    };

    inline for ([_][]const u8{ "globals", "list", "listener", "seats" }) |example| {
        const exe = b.addExecutable(example, "example/" ++ example ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);

        exe.step.dependOn(&scanner.step);
        exe.addPackage(wayland);
        scanner.addCSource(exe);
        exe.linkLibC();
        exe.linkSystemLibrary("wayland-client");

        exe.install();
    }

    const test_step = b.step("test", "Run the tests");
    {
        const scanner_tests = b.addTest("src/scanner.zig");
        scanner_tests.setTarget(target);
        scanner_tests.setBuildMode(mode);

        scanner_tests.step.dependOn(&scanner.step);
        scanner_tests.addPackage(wayland);

        test_step.dependOn(&scanner_tests.step);
    }
    {
        const ref_all = b.addTest("src/ref_all.zig");
        ref_all.setTarget(target);
        ref_all.setBuildMode(mode);

        ref_all.step.dependOn(&scanner.step);
        ref_all.addPackage(wayland);
        scanner.addCSource(ref_all);
        ref_all.linkLibC();
        ref_all.linkSystemLibrary("wayland-client");
        ref_all.linkSystemLibrary("wayland-server");
        ref_all.linkSystemLibrary("wayland-egl");
        ref_all.linkSystemLibrary("wayland-cursor");
        test_step.dependOn(&ref_all.step);
    }
}

pub const ScanProtocolsStep = struct {
    const scanner = @import("src/scanner.zig");

    builder: *zbs.Builder,
    step: zbs.Step,
    result: zbs.GeneratedFile,

    /// Slice of absolute paths of protocol xml files to be scanned
    protocol_paths: std.ArrayList([]const u8),

    pub fn create(builder: *zbs.Builder) *ScanProtocolsStep {
        const ally = builder.allocator;
        const self = ally.create(ScanProtocolsStep) catch unreachable;
        self.* = .{
            .builder = builder,
            .step = zbs.Step.init(.custom, "Scan Protocols", ally, make),
            .result = .{ .step = &self.step, .path = null },
            .protocol_paths = std.ArrayList([]const u8).init(ally),
        };
        return self;
    }

    /// Generate bindings from the protocol xml at the given absolute or relative path
    pub fn addProtocolPath(self: *ScanProtocolsStep, path: []const u8) void {
        self.protocol_paths.append(path) catch unreachable;
    }

    /// Generate bindings from protocol xml provided by the wayland-protocols
    /// package given the relative path (e.g. "stable/xdg-shell/xdg-shell.xml")
    pub fn addSystemProtocol(self: *ScanProtocolsStep, relative_path: []const u8) void {
        const protocol_dir = mem.trim(u8, self.builder.exec(
            &[_][]const u8{ "pkg-config", "--variable=pkgdatadir", "wayland-protocols" },
        ) catch unreachable, &std.ascii.spaces);
        self.addProtocolPath(fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ protocol_dir, relative_path },
        ) catch unreachable);
    }

    fn make(step: *zbs.Step) !void {
        const self = @fieldParentPtr(ScanProtocolsStep, "step", step);
        const ally = self.builder.allocator;

        const wayland_dir = mem.trim(u8, try self.builder.exec(
            &[_][]const u8{ "pkg-config", "--variable=pkgdatadir", "wayland-scanner" },
        ), &std.ascii.spaces);
        const wayland_xml = try fs.path.join(ally, &[_][]const u8{ wayland_dir, "wayland.xml" });

        const out_path = try fs.path.join(ally, &[_][]const u8{ self.builder.cache_root, "zig-wayland" });

        var root_dir = try fs.cwd().openDir(self.builder.build_root, .{});
        defer root_dir.close();
        var out_dir = try root_dir.makeOpenPath(out_path, .{});
        defer out_dir.close();
        try scanner.scan(root_dir, out_dir, wayland_xml, self.protocol_paths.items);

        // Once https://github.com/ziglang/zig/issues/131 is implemented
        // we can stop generating/linking C code.
        for (self.protocol_paths.items) |path| {
            _ = try self.builder.exec(
                &[_][]const u8{ "wayland-scanner", "private-code", path, self.getCodePath(path) },
            );
        }

        self.result.path = try fs.path.join(ally, &[_][]const u8{ out_path, "wayland.zig" });
    }
    /// Add the necessary C source to the compilation unit.
    /// Once https://github.com/ziglang/zig/issues/131 we can remove this.
    pub fn addCSource(self: *ScanProtocolsStep, obj: *zbs.LibExeObjStep) void {
        for (self.protocol_paths.items) |path| {
            obj.addCSourceFile(self.getCodePath(path), &[_][]const u8{"-std=c99"});
        }
    }

    fn getCodePath(self: *ScanProtocolsStep, xml_in_path: []const u8) []const u8 {
        const ally = self.builder.allocator;
        // Extension is .xml, so slice off the last 4 characters
        const basename = fs.path.basename(xml_in_path);
        const basename_no_ext = basename[0..(basename.len - 4)];
        const code_filename = std.fmt.allocPrint(ally, "{s}-protocol.c", .{basename_no_ext}) catch unreachable;
        return fs.path.join(ally, &[_][]const u8{
            self.builder.build_root,
            self.builder.cache_root,
            "zig-wayland",
            code_filename,
        }) catch unreachable;
    }
};
