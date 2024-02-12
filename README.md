# zig-wayland

Zig 0.11 bindings and protocol scanner for libwayland.

The main repository is on [codeberg](https://codeberg.org/ifreund/zig-wayland),
which is where the issue tracker may be found and where contributions are accepted.

Read-only mirrors exist on [sourcehut](https://git.sr.ht/~ifreund/zig-wayland)
and [github](https://github.com/ifreund/zig-wayland).

## Usage

A `Scanner` interface is provided which you may integrate with your `build.zig`:

```zig
const std = @import("std");

const Scanner = @import("deps/zig-wayland/build.zig").Scanner;

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});

    const wayland = b.createModule(.{ .source_file = scanner.result });

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("staging/ext-session-lock/ext-session-lock-v1.xml");
    scanner.addCustomProtocol("protocol/private_foobar.xml");

    // Pass the maximum version implemented by your wayland server or client.
    // Requests, events, enums, etc. from newer versions will not be generated,
    // ensuring forwards compatibility with newer protocol xml.
    // This will also generate code for interfaces created using the provided
    // global interface, in this example wl_keyboard, wl_pointer, xdg_surface,
    // xdg_toplevel, etc. would be generated as well.
    scanner.generate("wl_seat", 4);
    scanner.generate("xdg_wm_base", 3);
    scanner.generate("ext_session_lock_manager_v1", 1);
    scanner.generate("private_foobar_manager", 1);

    const exe = b.addExecutable(.{
        .name = "foobar",
        .root_source_file = .{ .path = "foobar.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("wayland", wayland);
    exe.linkLibC();
    exe.linkSystemLibrary("wayland-client");

    // TODO: remove when https://github.com/ziglang/zig/issues/131 is implemented
    scanner.addCSource(exe);

    b.installArtifact(exe);
}
```

Then, you may import the provided module in your project:

```zig
const wayland = @import("wayland");
const wl = wayland.client.wl;
```

There is an example project using zig-wayland here:
[hello-zig-wayland](https://codeberg.org/ifreund/hello-zig-wayland).

Note that zig-wayland does not currently do extensive verification of Wayland
protocol xml or provide good error messages if protocol xml is invalid. It is
recommend to use `wayland-scanner --strict` to debug protocol xml instead.

## License

zig-wayland is released under the MIT (expat) license.
