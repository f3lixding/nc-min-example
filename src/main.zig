const std = @import("std");
const nc = @cImport({
    @cInclude("notcurses/notcurses.h");
});

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout = std.Io.File.stdout();

    var buf: [1028]u8 = undefined;
    var stdout_writer = stdout.writer(io, &buf);
    const writer = &stdout_writer.interface;

    const nc_version = nc.notcurses_version();
    const nc_ver_slice: []const u8 = std.mem.span(nc_version);

    try writer.writeAll(nc_ver_slice);
    try writer.writeAll("\n");
    try writer.flush();
}
