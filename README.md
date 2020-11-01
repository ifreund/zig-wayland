# zig-wayland

Zig bindings and protocol scanner for libwayland.

## Usage

A `ScanProtocolsStep` is provided which you may intergrate with your
`build.zig`:

```zig
const std = @import("std");
const Builder = std.build.Builder;

const ScanProtocolsStep = @import("zig-wayland/build.zig").ScanProtocolsStep;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var scanner = ScanProtocolsStep.create(b, "zig-wayland/", .client);
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addProtocolPath("protocol/foobar.xml");

    const exe = b.addExecutable("foo", "foo.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.step.dependOn(&scanner.step);
    exe.addPackage(scanner.getPkg());
    scanner.link(exe);

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

zig-wayland is relased under the MIT (expat) license.
