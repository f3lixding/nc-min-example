const std = @import("std");
const util = @import("root.zig");
const c = util.c;

const Opts = struct {
    program: Program = .SimplePrint,
};

const Program = enum {
    SimplePrint,
    KeyReading,
    Borders,
    Multilayer,
    Colors,
    Resize,

    const Self = @This();

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
        } else if (std.mem.eql(u8, conv_buf, "keyreading")) {
            return .KeyReading;
        } else if (std.mem.eql(u8, conv_buf, "borders")) {
            return .Borders;
        } else if (std.mem.eql(u8, conv_buf, "multilayer")) {
            return .Multilayer;
        } else if (std.mem.eql(u8, conv_buf, "colors")) {
            return .Colors;
        } else if (std.mem.eql(u8, conv_buf, "resize")) {
            return .Resize;
        }

        return null;
    }

    pub fn execute(self: Self, input_opts: Opts) !void {
        _ = input_opts;

        if (c.setlocale(c.LC_ALL, "") == null) {
            return error.SetLocaleFailed;
        }

        var opts = std.mem.zeroes(c.notcurses_options);
        const nc_ctx = c.notcurses_core_init(&opts, null) orelse {
            return error.NotcursesInitFailed;
        };
        defer _ = c.notcurses_stop(nc_ctx);

        // regardless of what program we are running we are going to need a plane
        const stdplane = c.notcurses_stdplane(nc_ctx) orelse {
            return error.NotcursesInitFailed;
        };

        switch (self) {
            .SimplePrint => {
                if (c.ncplane_putstr_yx(stdplane, 2, 4, "hello notcurses") < 0) {
                    return error.PutStrFailed;
                }

                if (c.ncplane_putstr_yx(stdplane, 4, 4, "press 'q' to exit") < 0) {
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
            .KeyReading => {
                const Coord = struct {
                    y: c_int,
                    x: c_int,
                };
                const BUF_MAX_LEN: usize = 10;

                var head: usize = 0;
                var tail: usize = 0;
                var len: usize = 0;

                var pb: [BUF_MAX_LEN]Coord = undefined;
                pb[0] = .{ .y = 5, .x = 10 };

                while (true) {
                    c.ncplane_erase(stdplane);

                    if (c.ncplane_putstr_yx(stdplane, 0, 5, "move with arrows and vim motion; q quits") < 0) {
                        return error.PutstrError;
                    }

                    const y = pb[head].y;
                    const x = pb[head].x;
                    const next_head = (head + 1) % BUF_MAX_LEN;
                    const next_coord = &pb[next_head];

                    const to_render = if (len < BUF_MAX_LEN) blk_one: {
                        break :blk_one pb[tail .. head + 1];
                    } else blk_two: {
                        break :blk_two &pb;
                    };
                    for (to_render) |*coord| {
                        if (c.ncplane_putstr_yx(stdplane, coord.y, coord.x, "@") < 0) {
                            return error.PutstrError;
                        }
                    }

                    if (c.notcurses_render(nc_ctx) < 0) {
                        return error.RenderFailed;
                    }

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    switch (key) {
                        c.NCKEY_UP, 'k' => {
                            if (y <= 0) continue;
                            next_coord.x = x;
                            next_coord.y = y - 1;
                        },
                        c.NCKEY_DOWN, 'j' => {
                            next_coord.x = x;
                            next_coord.y = y + 1;
                        },
                        c.NCKEY_LEFT, 'h' => {
                            if (x <= 0) continue;
                            next_coord.x = x - 1;
                            next_coord.y = y;
                        },
                        c.NCKEY_RIGHT, 'l' => {
                            next_coord.x = x + 1;
                            next_coord.y = y;
                        },
                        'q' => break,
                        else => continue,
                    }

                    head = next_head;
                    if (head == tail)
                        tail = (tail + 1) % BUF_MAX_LEN;
                    if (len < BUF_MAX_LEN)
                        len += 1;
                }
            },
            // move the border with j, k, h, l
            // resize it with shft + j, k, j, l
            .Borders => {
                var top_left_y: c_uint = 5;
                var top_left_x: c_uint = 10;
                var height: c_uint = 20;
                var width: c_uint = 40;

                while (true) {
                    var term_height: c_uint = 0;
                    var term_width: c_uint = 0;
                    c.ncplane_dim_yx(stdplane, &term_height, &term_width);

                    c.ncplane_erase(stdplane);

                    if (c.ncplane_putstr_yx(
                        stdplane,
                        0,
                        0,
                        "Use j, k, h, l to move; Use shift to resize in those directions",
                    ) < 0) {
                        return error.PutstrError;
                    }
                    if (c.ncplane_putstr_yx(
                        stdplane,
                        1,
                        0,
                        "Use q to quit",
                    ) < 0) {
                        return error.PutstrError;
                    }

                    util.drawBorders(stdplane, top_left_y, top_left_x, height, width);
                    if (c.notcurses_render(nc_ctx) < 0) return error.RenderFailed;

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    switch (key) {
                        'h', c.NCKEY_LEFT => {
                            if (top_left_x > 0) {
                                top_left_x -= 1;
                            }
                        },
                        'l', c.NCKEY_RIGHT => {
                            top_left_x += 1;
                        },
                        'k', c.NCKEY_UP => {
                            if (top_left_y > 0) {
                                top_left_y -= 1;
                            }
                        },
                        'j', c.NCKEY_DOWN => {
                            top_left_y += 1;
                        },

                        // Most terminals send Shift+h/j/k/l as uppercase letters,
                        // not as lowercase letters with NCKEY_MOD_SHIFT set.
                        'H' => if (width > 2) {
                            width -= 1;
                        },
                        'L' => width += 1,
                        'K' => if (height > 2) {
                            height -= 1;
                        },
                        'J' => height += 1,

                        'q' => break,
                        else => continue,
                    }
                }
            },
            .Multilayer => {
                // This is more or less identical to moving what you draw around
                // except this case it's moving the entire plane
                var box_opts: c.ncplane_options = std.mem.zeroes(c.ncplane_options);
                box_opts.name = "Box on plane";
                box_opts.y = 5;
                box_opts.x = 10;
                box_opts.rows = 5;
                box_opts.cols = 31;

                const box = c.ncplane_create(stdplane, &box_opts) orelse {
                    return error.CreatePlaneFailed;
                };
                defer if (c.ncplane_destroy(box) < 0) {
                    // noop
                };

                // draw the box
                // notice how we are using coords relative to the box plane
                _ = c.ncplane_putstr_yx(box, 0, 0, "+----------------------------+");
                _ = c.ncplane_putstr_yx(box, 1, 0, "| hello from a separate plane |");
                _ = c.ncplane_putstr_yx(box, 2, 0, "| this plane can move         |");
                _ = c.ncplane_putstr_yx(box, 3, 0, "+----------------------------+");
                try movingBoxOnPlane(nc_ctx, stdplane, box);
            },
            .Colors => {
                // This is more or less identical to moving what you draw around
                // except this case it's moving the entire plane
                var box_opts: c.ncplane_options = std.mem.zeroes(c.ncplane_options);
                box_opts.name = "Box on plane";
                box_opts.y = 5;
                box_opts.x = 10;
                box_opts.rows = 5;
                box_opts.cols = 31;

                const box = c.ncplane_create(stdplane, &box_opts) orelse {
                    return error.CreatePlaneFailed;
                };
                defer if (c.ncplane_destroy(box) < 0) {
                    // noop
                };

                // setting up colors
                _ = c.ncplane_set_fg_rgb(box, 0x00ff80);
                _ = c.ncplane_set_bg_rgb(box, 0x202020);

                // draw the box
                // notice how we are using coords relative to the box plane
                _ = c.ncplane_putstr_yx(box, 0, 0, "+-----------------------------+");
                _ = c.ncplane_putstr_yx(box, 1, 0, "| hello from a separate plane |");
                _ = c.ncplane_putstr_yx(box, 2, 0, "| this plane can move         |");
                _ = c.ncplane_putstr_yx(box, 3, 0, "+-----------------------------+");

                try movingBoxOnPlane(nc_ctx, stdplane, box);
            },
            .Resize => {
                // resize and adjust
                // don't want to compilcate it too much for now though
                // so i am just going to make it read the dimension and print it
                var cur_width: c_uint = 0;
                var cur_height: c_uint = 0;
                var buf: [1024]u8 = undefined;
                const template = "Height: {d}, Width: {d}";

                while (true) {
                    c.ncplane_erase(stdplane);
                    c.ncplane_dim_yx(stdplane, &cur_height, &cur_width);

                    const text = try std.fmt.bufPrintZ(&buf, template, .{ cur_height, cur_width });
                    const mid_y = cur_height / 2;
                    _ = c.ncplane_putstr_aligned(stdplane, @intCast(mid_y), c.NCALIGN_CENTER, text);

                    if (c.notcurses_render(nc_ctx) < 0) {
                        return error.RenderFailed;
                    }

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    switch (key) {
                        'q' => break,
                        else => {},
                    }
                }
            },
        }
    }
};

fn movingBoxOnPlane(
    nc_ctx: *c.struct_notcurses,
    stdplane: *c.struct_ncplane,
    box: *c.struct_ncplane,
) !void {
    var box_top_left_y: c_uint = 5;
    var box_top_left_x: c_uint = 10;
    while (true) {
        c.ncplane_erase(stdplane);

        _ = c.ncplane_putstr_yx(stdplane, 1, 2, "background stdplane");
        _ = c.ncplane_putstr_yx(stdplane, 2, 2, "move box with arrows/h; q quits");

        _ = c.ncplane_move_yx(box, @intCast(box_top_left_y), @intCast(box_top_left_x));

        if (c.notcurses_render(nc_ctx) < 0) return error.RenderFailed;

        var input = std.mem.zeroes(c.ncinput);
        const key = c.notcurses_get_blocking(nc_ctx, &input);

        switch (key) {
            c.NCKEY_UP, 'k' => if (box_top_left_y > 0) {
                box_top_left_y -= 1;
            },
            c.NCKEY_DOWN, 'j' => box_top_left_y += 1,
            c.NCKEY_LEFT, 'h' => if (box_top_left_x > 0) {
                box_top_left_x -= 1;
            },
            c.NCKEY_RIGHT, 'l' => box_top_left_x += 1,
            'q' => break,
            else => {},
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const args = init.minimal.args;
    var args_iter = try std.process.Args.iterateAllocator(args, init.gpa);
    _ = args_iter.next(); // program name

    var input_opts: Opts = .{};
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--program") or std.mem.eql(u8, arg, "-p")) {
            const val = args_iter.next() orelse return error.ArgParseError;
            input_opts.program = Program.parseFromStr(val) orelse return error.ArgParseError;
        } else if (arg.len > "--program=".len and std.mem.startsWith(u8, arg, "--program=")) {
            const val = arg["--program=".len..];
            input_opts.program = Program.parseFromStr(val) orelse return error.ArgParseError;
        }
    }

    try input_opts.program.execute(input_opts);
}
