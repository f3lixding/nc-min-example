const std = @import("std");
const c = @cImport({
    @cInclude("locale.h");
    @cInclude("stdio.h");
    @cInclude("notcurses/notcurses.h");
});

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    _ = io;

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
}

pub fn waitForKey() void {}
