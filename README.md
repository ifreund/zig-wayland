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
    scanner.addProtocolPath("protocol/foobar.xml");

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

## License

zig-wayland is released under the MIT (expat) license.
