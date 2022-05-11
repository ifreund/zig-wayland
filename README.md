# zig-wayland

Zig 0.9 bindings and protocol scanner for libwayland.

## Usage

A `ScanProtocolsStep` is provided which you may integrate with your
`build.zig`:

```zig
const std = @import("std");
const Builder = std.build.Builder;

const ScanProtocolsStep = @import("zig-wayland/build.zig").ScanProtocolsStep;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const scanner = ScanProtocolsStep.create(b);
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("staging/ext-session-lock/ext-session-lock-v1.xml");
    scanner.addProtocolPath("protocol/private_foobar.xml");

    // Pass the maximum version implemented by your wayland server or client.
    // Requests, events, enums, etc. from newer versions will not be generated,
    // ensuring forwards compatibility with newer protocol xml.
    // This will also generate code for interfaces created using the provided
    // global interface, in this example wl_keyboard, wl_pointer, xdg_surface,
    // xdg_toplevel, etc. would be generated.
    scanner.generate("wl_seat", 4);
    scanner.generate("xdg_wm_base", 3);
    scanner.generate("ext_session_lock_manager_v1", 1);
    scanner.generate("private_foobar_manager", 1);

    const exe = b.addExecutable("foo", "foo.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.addPackage(.{
        .name = "wayland",
        .path = .{ .generated = &scanner.result },
    });
    exe.step.dependOn(&scanner.step);
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");

    // TODO: remove when https://github.com/ziglang/zig/issues/131 is implemented
    scanner.addCSource(exe);

    exe.install();
}

```

Then, you may import the provided package in your project:

```zig
const wayland = @import("wayland");
const wl = wayland.client.wl;
```

There is an example project using zig-wayland here:
[hello-zig-wayland](https://github.com/ifreund/hello-zig-wayland).

Note that zig-wayland does not currently do extensive verification of Wayland
protocol xml or provide good error messages if protocol xml is invalid. It is
recommend to use `wayland-scanner --strict` to debug protocol xml instead.

## License

zig-wayland is released under the MIT (expat) license.
