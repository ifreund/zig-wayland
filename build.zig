const std = @import("std");
const zbs = std.build;

pub fn build(b: *zbs.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const scanner = ScanProtocolsStep.create(b, ".");
    inline for ([_][]const u8{ "globals", "list", "listener", "seats" }) |example| {
        const exe = b.addExecutable(example, "example/" ++ example ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);

        exe.step.dependOn(&scanner.step);
        exe.addPackage(scanner.getPkg());
        scanner.addCSource(exe);
        exe.linkLibC();
        exe.linkSystemLibrary("wayland-client");

        exe.install();
    }

    const test_step = b.step("test", "Run the tests");
    for ([_][]const u8{ "src/scanner.zig", "src/common_core.zig" }) |file| {
        const t = b.addTest(file);
        t.setTarget(target);
        t.setBuildMode(mode);

        test_step.dependOn(&t.step);
    }

    {
        const ref_all = b.addTest("src/ref_all.zig");
        ref_all.setTarget(target);
        ref_all.setBuildMode(mode);

        ref_all.step.dependOn(&scanner.step);
        ref_all.addPackage(scanner.getPkg());
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

    /// Relative path to the root of the zig wayland repo from the user's build.zig
    zig_wayland_path: []const u8,

    /// Slice of absolute paths of protocol xml files to be scanned
    protocol_paths: std.ArrayList([]const u8),

    pub fn create(builder: *zbs.Builder, zig_wayland_path: []const u8) *ScanProtocolsStep {
        const self = builder.allocator.create(ScanProtocolsStep) catch unreachable;
        self.* = .{
            .builder = builder,
            .step = zbs.Step.init(.Custom, "Scan Protocols", builder.allocator, make),
            .zig_wayland_path = zig_wayland_path,
            .protocol_paths = std.ArrayList([]const u8).init(builder.allocator),
        };
        return self;
    }

    /// Generate bindings from the protocol xml at the given absolute or relative path
    pub fn addProtocolPath(self: *ScanProtocolsStep, path: []const u8) void {
        if (std.fs.path.isAbsolute(path)) {
            self.protocol_paths.append(path) catch unreachable;
        } else {
            const pwd = std.process.getCwdAlloc(self.builder.allocator) catch unreachable;
            const abs_path = std.fs.path.join(self.builder.allocator, &[_][]const u8{ pwd, path }) catch unreachable;
            self.protocol_paths.append(abs_path) catch unreachable;
        }
    }

    /// Generate bindings from protocol xml provided by the wayland-protocols
    /// package given the relative path (e.g. "stable/xdg-shell/xdg-shell.xml")
    pub fn addSystemProtocol(self: *ScanProtocolsStep, relative_path: []const u8) void {
        const protocol_dir = std.mem.trim(u8, self.builder.exec(
            &[_][]const u8{ "pkg-config", "--variable=pkgdatadir", "wayland-protocols" },
        ) catch unreachable, &std.ascii.spaces);
        self.addProtocolPath(std.fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ protocol_dir, relative_path },
        ) catch unreachable);
    }

    fn make(step: *zbs.Step) !void {
        const self = @fieldParentPtr(ScanProtocolsStep, "step", step);

        const out_path = try std.fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.zig_wayland_path, "generated" },
        );
        var out_dir = try std.fs.cwd().openDir(out_path, .{});
        defer out_dir.close();

        const wayland_dir = std.mem.trim(u8, try self.builder.exec(
            &[_][]const u8{ "pkg-config", "--variable=pkgdatadir", "wayland-scanner" },
        ), &std.ascii.spaces);
        const wayland_xml = try std.fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ wayland_dir, "wayland.xml" },
        );

        try scanner.scan(out_dir, wayland_xml, self.protocol_paths.items);

        // Once https://github.com/ziglang/zig/issues/131 is implemented
        // we can stop generating/linking C code.
        for (self.protocol_paths.items) |path| {
            _ = try self.builder.exec(
                &[_][]const u8{ "wayland-scanner", "private-code", path, self.getCodePath(path) },
            );
        }
    }
    /// Add the necessary C source to the compilation unit.
    /// Once https://github.com/ziglang/zig/issues/131 we can remove this.
    pub fn addCSource(self: *ScanProtocolsStep, obj: *zbs.LibExeObjStep) void {
        for (self.protocol_paths.items) |path|
            obj.addCSourceFile(self.getCodePath(path), &[_][]const u8{"-std=c99"});
    }

    pub fn getPkg(self: *ScanProtocolsStep) zbs.Pkg {
        return .{
            .name = "wayland",
            .path = std.fs.path.join(
                self.builder.allocator,
                &[_][]const u8{ self.zig_wayland_path, "generated/wayland.zig" },
            ) catch unreachable,
        };
    }

    fn getCodePath(self: *ScanProtocolsStep, xml_in_path: []const u8) []const u8 {
        const allocator = self.builder.allocator;
        // Extension is .xml, so slice off the last 4 characters
        const basename = std.fs.path.basename(xml_in_path);
        const basename_no_ext = basename[0..(basename.len - 4)];
        const code_filename = std.fmt.allocPrint(allocator, "{}-protocol.c", .{basename_no_ext}) catch unreachable;
        return std.fs.path.join(
            allocator,
            &[_][]const u8{ self.zig_wayland_path, "generated", code_filename },
        ) catch unreachable;
    }
};
