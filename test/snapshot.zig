const std = @import("std");
const build_options = @import("build_options");

test "snapshot" {
    const expected = @embedFile("snapshot_expected.zig");

    const actual_file = try std.fs.cwd().openFile(build_options.snapshot_actual, .{});
    defer actual_file.close();

    const actual = try actual_file.readToEndAlloc(std.testing.allocator, 4 * 1024 * 1024 * 1024);
    defer std.testing.allocator.free(actual);

    if (!std.mem.eql(u8, expected, actual)) {
        std.debug.print("scanner output does not match snapshot\n", .{});
        std.debug.print("diff -C 3 test/snapshot_expected.zig {s}\n", .{build_options.snapshot_actual});
        return error.TestUnexpectedResult;
    }
}
