const std = @import("std");
const util = @import("root.zig");
const c = util.c;

const Opts = struct {
    program: Program = .SimplePrint,
};

const CtrlOpts = struct {
    pub const Command = enum {
        BringToTop,
        BringToBot,
        MoveLeft,
        MoveRight,
        MoveUp,
        MoveDown,
    };

    const Self = @This();

    focus: usize = 0,
    command: ?Command = null,

    pub fn reset(self: *Self) void {
        self.command = null;
    }
};

const Plane = struct {
    const Self = @This();

    red: u8,
    green: u8,
    blue: u8,
    plane: *c.ncplane,
    y: c_int = 0,
    x: c_int = 0,

    pub fn init(
        base_plane: *c.ncplane,
        y: c_int,
        x: c_int,
        red: u8,
        green: u8,
        blue: u8,
    ) !Self {
        var box_opts: c.ncplane_options = std.mem.zeroes(c.ncplane_options);
        box_opts.name = "Box on plane";
        box_opts.y = y;
        box_opts.x = x;
        box_opts.rows = 5;
        box_opts.cols = 31;

        const plane = c.ncplane_create(base_plane, &box_opts) orelse {
            return error.CreatePlaneFailed;
        };

        // fill in the plane
        _ = c.ncplane_cursor_move_yx(plane, 0, 0);

        const color = rgb(red, green, blue);
        _ = c.ncplane_set_fg_rgb(plane, color);
        var channels: u64 = 0;
        if (c.ncchannels_set_fg_rgb(&channels, color) < 0) {
            return error.ColorFailed;
        }

        if (c.ncplane_rounded_box_sized(
            plane,
            c.NCSTYLE_BOLD,
            channels,
            box_opts.rows,
            box_opts.cols,
            0,
        ) < 0) {
            return error.BoxFailed;
        }

        // Just display the color for now
        var buf: [256]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&buf, "red={d} green={d} blue={d}", .{ red, green, blue });
        const mid_y = box_opts.rows / 2;
        _ = c.ncplane_putstr_aligned(plane, @intCast(mid_y), c.NCALIGN_CENTER, text);

        return .{
            .red = red,
            .green = green,
            .blue = blue,
            .plane = plane,
            .y = y,
            .x = x,
        };
    }

    pub fn deinit(self: Self) void {
        _ = c.ncplane_destroy(self.plane);
    }

    pub fn processCommand(self: *Self, command: CtrlOpts.Command) void {
        switch (command) {
            .BringToTop => {
                _ = c.ncplane_move_top(self.plane);
            },
            .BringToBot => {
                _ = c.ncplane_move_bottom(self.plane);
            },
            .MoveLeft => {
                if (self.x > 0) {
                    self.x -= 1;
                }
                _ = c.ncplane_move_yx(self.plane, self.y, self.x);
            },
            .MoveRight => {
                self.x += 1;
                _ = c.ncplane_move_yx(self.plane, self.y, self.x);
            },
            .MoveUp => {
                if (self.y > 0) {
                    self.y -= 1;
                }
                _ = c.ncplane_move_yx(self.plane, self.y, self.x);
            },
            .MoveDown => {
                self.y += 1;
                _ = c.ncplane_move_yx(self.plane, self.y, self.x);
            },
        }
    }
};

const Program = enum {
    SimplePrint,
    KeyReading,
    Borders,
    Multilayer,
    Colors,
    Resize,
    RealBorders,
    DirectMode,
    KeyInspect,
    Planes,
    PlaneScrolling,

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
        } else if (std.mem.eql(u8, conv_buf, "realborders")) {
            return .RealBorders;
        } else if (std.mem.eql(u8, conv_buf, "directmode")) {
            return .DirectMode;
        } else if (std.mem.eql(u8, conv_buf, "keyinspect")) {
            return .KeyInspect;
        } else if (std.mem.eql(u8, conv_buf, "planes")) {
            return .Planes;
        } else if (std.mem.eql(u8, conv_buf, "planescrolling")) {
            return .PlaneScrolling;
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
        var needs_deinit = true;
        defer {
            if (needs_deinit) {
                _ = c.notcurses_stop(nc_ctx);
            }
        }

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
                _ = c.ncplane_putstr_yx(box, 1, 0, "| hello from a separate plane|");
                _ = c.ncplane_putstr_yx(box, 2, 0, "| this plane can move        |");
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
            .RealBorders => {
                var cur_height: c_uint = 0;
                var cur_width: c_uint = 0;

                _ = c.ncplane_dim_yx(stdplane, &cur_height, &cur_width);
                _ = c.ncplane_cursor_move_yx(stdplane, 0, 0);

                if (c.ncplane_rounded_box_sized(
                    stdplane,
                    0,
                    0,
                    cur_height,
                    cur_width,
                    0,
                ) < 0) {
                    return error.BoxFailed;
                }

                if (c.notcurses_render(nc_ctx) < 0) {
                    return error.RenderFailed;
                }

                var input = std.mem.zeroes(c.ncinput);
                while (true) {
                    const key = c.notcurses_get_blocking(nc_ctx, &input);
                    if (key == 'q') {
                        break;
                    }
                }
            },
            .DirectMode => {
                _ = c.notcurses_stop(nc_ctx);
                needs_deinit = false;

                const ncd = c.ncdirect_init(null, null, 0) orelse {
                    return error.DirectInitFailed;
                };
                defer _ = c.ncdirect_stop(ncd);

                _ = c.ncdirect_set_fg_rgb(ncd, 0xff0000);
                _ = c.ncdirect_putstr(ncd, 0, "red text from ncdirect\n");

                _ = c.ncdirect_set_fg_rgb(ncd, 0x00ff00);
                _ = c.ncdirect_putstr(ncd, 0, "green text from ncdirect\n");

                _ = c.ncdirect_set_fg_default(ncd);
                _ = c.ncdirect_putstr(ncd, 0, "back to default\n");
            },
            .KeyInspect => {
                while (true) {
                    c.ncplane_erase(stdplane);

                    _ = c.ncplane_putstr_yx(stdplane, 1, 2, "press keys; q quits");

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    if (key == 'q') break;

                    // erase to get rid tips
                    c.ncplane_erase(stdplane);

                    // reusable buff
                    var buf: [256]u8 = undefined;

                    const id_line = try std.fmt.bufPrintZ(
                        &buf,
                        "key id: {} / 0x{x}",
                        .{ input.id, input.id },
                    );
                    _ = c.ncplane_putstr_yx(stdplane, 2, 2, id_line.ptr);

                    const utf8_line = try std.fmt.bufPrintZ(
                        &buf,
                        "ut8: {s}",
                        .{std.mem.sliceTo(&input.utf8, 0)},
                    );
                    _ = c.ncplane_putstr_yx(stdplane, 3, 2, utf8_line.ptr);

                    const mod_line = try std.fmt.bufPrintZ(
                        &buf,
                        "modifiers: shift={}, ctrl={}, alt={}",
                        .{
                            c.ncinput_shift_p(&input),
                            c.ncinput_ctrl_p(&input),
                            c.ncinput_alt_p(&input),
                        },
                    );
                    _ = c.ncplane_putstr_yx(stdplane, 4, 2, mod_line.ptr);

                    _ = c.ncplane_putstr_yx(stdplane, 6, 2, "press another key; q quits");

                    if (c.notcurses_render(nc_ctx) < 0) return error.RenderFailed;

                    _ = c.notcurses_get_blocking(nc_ctx, null);
                }
            },
            .Planes => {
                var plane_one = try Plane.init(
                    stdplane,
                    5,
                    10,
                    0xff,
                    0x10,
                    0x10,
                );
                defer plane_one.deinit();
                var plane_two = try Plane.init(
                    stdplane,
                    8,
                    20,
                    0x10,
                    0xff,
                    0x10,
                );
                defer plane_two.deinit();
                var plane_three = try Plane.init(
                    stdplane,
                    11,
                    30,
                    0x10,
                    0x10,
                    0xff,
                );
                defer plane_three.deinit();
                const planes: [3]*Plane = .{
                    &plane_one,
                    &plane_two,
                    &plane_three,
                };

                var ctrlOpts: CtrlOpts = .{};

                while (true) {
                    var buf: [128]u8 = undefined;
                    const selected_text = try std.fmt.bufPrintZ(&buf, "selected plane: {d}", .{ctrlOpts.focus + 1});

                    _ = c.ncplane_putstr_yx(stdplane, 0, 0, "1, 2, 3 to choose planes");
                    _ = c.ncplane_putstr_yx(stdplane, 1, 0, "t to bring selected plane to the top");
                    _ = c.ncplane_putstr_yx(stdplane, 2, 0, "b to bring selected plane to the bottom");
                    _ = c.ncplane_putstr_yx(stdplane, 3, 0, "h/j/k/l to move selected plane");
                    _ = c.ncplane_putstr_yx(stdplane, 4, 0, selected_text.ptr);

                    if (c.notcurses_render(nc_ctx) < 0) {
                        return error.RenderFailed;
                    }

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    ctrlOpts.command = switch (key) {
                        '1' => blk: {
                            ctrlOpts.focus = 0;
                            break :blk null;
                        },
                        '2' => blk: {
                            ctrlOpts.focus = 1;
                            break :blk null;
                        },
                        '3' => blk: {
                            ctrlOpts.focus = 2;
                            break :blk null;
                        },
                        't' => .BringToTop,
                        'b' => .BringToBot,
                        'j' => .MoveDown,
                        'k' => .MoveUp,
                        'h' => .MoveLeft,
                        'l' => .MoveRight,
                        'q' => break,
                        else => null,
                    };

                    if (ctrlOpts.command) |command| {
                        planes[ctrlOpts.focus].processCommand(command);
                    }
                }
            },
            .PlaneScrolling => {
                var origin_y: c_int = 3;
                var origin_x: c_int = 3;

                var border_opts = std.mem.zeroes(c.ncplane_options);
                border_opts.y = origin_y;
                border_opts.x = origin_x;
                border_opts.rows = 12;
                border_opts.cols = 52;

                const border = c.ncplane_create(stdplane, &border_opts) orelse {
                    return error.CreatePlaneFailed;
                };
                defer _ = c.ncplane_destroy(border);

                if (c.ncplane_rounded_box_sized(
                    border,
                    0,
                    0,
                    border_opts.rows,
                    border_opts.cols,
                    0,
                ) < 0) {
                    return error.BoxFailed;
                }

                var log_opts = std.mem.zeroes(c.ncplane_options);
                log_opts.y = 1;
                log_opts.x = 1;
                log_opts.rows = 10;
                log_opts.cols = 50;

                const log = c.ncplane_create(border, &log_opts) orelse {
                    return error.CreatePlaneFailed;
                };
                defer _ = c.ncplane_destroy(log);

                _ = c.ncplane_set_scrolling(log, @intFromBool(true));

                var counter: usize = 0;

                while (true) {
                    c.ncplane_erase(stdplane);
                    _ = c.ncplane_putstr_yx(stdplane, 1, 2, "press any key to append; q quits");

                    if (c.notcurses_render(nc_ctx) < 0) return error.RenderFailed;

                    var input = std.mem.zeroes(c.ncinput);
                    const key = c.notcurses_get_blocking(nc_ctx, &input);

                    switch (key) {
                        'h' => {
                            if (origin_x > 0) {
                                origin_x -= 1;
                                _ = c.ncplane_move_yx(border, origin_y, origin_x);
                            }
                        },
                        'j' => {
                            origin_y += 1;
                            _ = c.ncplane_move_yx(border, origin_y, origin_x);
                        },
                        'k' => {
                            if (origin_y > 0) {
                                origin_y -= 1;
                                _ = c.ncplane_move_yx(border, origin_y, origin_x);
                            }
                        },
                        'l' => {
                            origin_x += 1;
                            _ = c.ncplane_move_yx(border, origin_y, origin_x);
                        },
                        'q' => break,
                        else => {},
                    }

                    var buf: [128]u8 = undefined;
                    const line = try std.fmt.bufPrintZ(
                        &buf,
                        "event {}:  key={} utf8={s}\n",
                        .{ counter, key, std.mem.sliceTo(&input.utf8, 0) },
                    );

                    _ = c.ncplane_putstr(log, line.ptr);
                    counter += 1;
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

fn rgb(r: u8, g: u8, b: u8) c_uint {
    return (@as(c_uint, r) << 16) | (@as(c_uint, g) << 8) | (@as(c_uint, b));
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
