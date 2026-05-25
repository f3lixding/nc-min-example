const std = @import("std");

pub const c = @cImport({
    @cInclude("locale.h");
    @cInclude("stdio.h");
    @cInclude("notcurses/notcurses.h");
});

/// Draw a rectangular ASCII border.
///
/// `y`/`x` are the top-left corner of the border, and `rows`/`cols` are the
/// border's total height/width.
pub fn drawBorders(
    n: *c.ncplane,
    y: c_uint,
    x: c_uint,
    rows: c_uint,
    cols: c_uint,
) void {
    if (rows < 2 or cols < 2) return;

    const top: c_int = @intCast(y);
    const left: c_int = @intCast(x);
    const bottom: c_int = @intCast(y + rows - 1);
    const right: c_int = @intCast(x + cols - 1);

    var cur_x: c_uint = x + 1;
    while (cur_x < x + cols - 1) : (cur_x += 1) {
        const draw_x: c_int = @intCast(cur_x);
        _ = c.ncplane_putstr_yx(n, top, draw_x, "-");
        _ = c.ncplane_putstr_yx(n, bottom, draw_x, "-");
    }

    var cur_y: c_uint = y + 1;
    while (cur_y < y + rows - 1) : (cur_y += 1) {
        const draw_y: c_int = @intCast(cur_y);
        _ = c.ncplane_putstr_yx(n, draw_y, left, "|");
        _ = c.ncplane_putstr_yx(n, draw_y, right, "|");
    }

    _ = c.ncplane_putstr_yx(n, top, left, "+");
    _ = c.ncplane_putstr_yx(n, top, right, "+");
    _ = c.ncplane_putstr_yx(n, bottom, left, "+");
    _ = c.ncplane_putstr_yx(n, bottom, right, "+");
}
