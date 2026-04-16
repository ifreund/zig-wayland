const std = @import("std");
const build_options = @import("build_options");

test "snapshot" {
    const io = std.testing.io;
    const expected = @embedFile("snapshot_expected.zig");

    const actual_file = try std.Io.Dir.cwd().openFile(io, build_options.snapshot_actual, .{});
    defer actual_file.close(io);

    var actual_reader = actual_file.reader(io, &.{});
    const actual = try actual_reader.interface.allocRemaining(std.testing.allocator, .unlimited);
    defer std.testing.allocator.free(actual);

    if (!std.mem.eql(u8, expected, actual)) {
        std.debug.print("scanner output does not match snapshot\n", .{});
        std.debug.print("diff -C 3 test/snapshot_expected.zig {s}\n", .{build_options.snapshot_actual});
        return error.TestUnexpectedResult;
    }
}
