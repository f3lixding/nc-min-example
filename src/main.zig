const std = @import("std");
const c = @cImport({
    @cInclude("locale.h");
    @cInclude("stdio.h");
    @cInclude("notcurses/notcurses.h");
});

const Opts = struct {
    program: Program = .SimplePrint,
};

const Program = enum {
    SimplePrint,

    pub fn parseFromStr(input: []const u8) ?Program {
        // We'll deal with this later. For now we'll assume this is true
        std.debug.assert(input.len <= 1024);

        var buf: [1024]u8 = undefined;
        for (input, buf[0..input.len]) |in, *out| {
            out.* = std.ascii.toLower(in);
        }
        const conv_buf = buf[0..input.len];

        if (std.mem.eql(u8, conv_buf, "simpleprint")) {
            return .SimplePrint;
        }

        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    const args = init.minimal.args;
    var args_iter = try std.process.Args.iterateAllocator(args, init.gpa);
    _ = args_iter.next(); // program name

    var input_opts: Opts = undefined;
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--program") or std.mem.eql(u8, arg, "-p")) {
            if (args_iter.next()) |val| {
                input_opts.program = Program.parseFromStr(val) orelse return error.ArgParseError;
            } else {
                return error.ArgParseError;
            }
        }
    }

    switch (input_opts.program) {
        .SimplePrint => {
            if (c.setlocale(c.LC_ALL, "") == null) {
                return error.SetLocaleFailed;
            }

            var opts: c.notcurses_options = std.mem.zeroes(c.notcurses_options);

            const nc_ctx = c.notcurses_core_init(&opts, null) orelse {
                return error.NotcursesInitFailed;
            };
            defer _ = c.notcurses_stop(nc_ctx);

            const stdplane = c.notcurses_stdplane(nc_ctx) orelse {
                return error.NotcursesInitFailed;
            };

            _ = c.ncplane_set_fg_rgb8(stdplane, 255, 255, 255);
            _ = c.ncplane_set_bg_rgb8(stdplane, 0, 0, 128);

            if (c.ncplane_putstr_yx(stdplane, 2, 4, "hello notcurses") < 0) {
                return error.PutStrFailed;
            }

            if (c.ncplane_putstr_yx(stdplane, 4, 4, "press any key to exit") < 0) {
                return error.PutStrFailed;
            }

            if (c.notcurses_render(nc_ctx) < 0) {
                return error.RenderFailed;
            }

            while (true) {
                var input: c.ncinput = std.mem.zeroes(c.ncinput);
                const id = c.notcurses_get_blocking(nc_ctx, &input);

                if (id == std.math.maxInt(u32)) {
                    return error.InputFailed;
                }

                if (id == 'q' or id == c.NCKEY_ESC) break;
            }
        },
    }

    var buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout();
    var stdout_writer_ = stdout.writer(init.io, &buf);
    var stdout_writer = &stdout_writer_.interface;

    try stdout_writer.writeAll("No matching program found\n");
    try stdout_writer.flush();
}

pub fn waitForKey() void {}
