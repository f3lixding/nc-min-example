---
name: notcurses-mastery
description: Guides learning, using, and wrapping Notcurses from Zig. Use when working with Notcurses APIs, terminal/TUI concepts, ncplane rendering, input, colors/channels, visuals, widgets, or creating Zig examples/bindings for Notcurses.
compatibility: Zig projects using Notcurses through C interop; assumes Notcurses headers/libraries and pkg-config are available.
---

# Notcurses Mastery

Use this skill when helping with Notcurses API learning, Zig bindings, examples, terminal capability issues, or TUI architecture.

## Operating principles

- Treat Notcurses as a **terminal compositor**, not as an ncurses-compatible printer.
- Prefer small runnable examples that demonstrate one concept at a time.
- For Zig, keep `@cImport` isolated behind a thin wrapper and gradually wrap only the APIs the project uses.
- When troubleshooting runtime behavior, check terminal environment first: `$TERM`, `$COLORTERM`, locale, terminal size, tmux/screen, and `notcurses-info`.

## Core mental model

1. `struct notcurses` — global TUI context.
2. `struct ncplane` — drawable 2D surface/layer.
3. Cells — extended grapheme cluster + style + packed channels.
4. Channels — foreground/background RGB plus alpha mode.
5. Render loop — mutate planes, then call `notcurses_render()`.
6. Input — read `ncinput`; offer input to widgets or handle keys manually.
7. Visuals — images/videos rendered via terminal graphics or degraded text blitters.
8. Widgets — higher-level components built on planes.

## Recommended source reading order

In the Notcurses checkout, read:

```text
README.md
USAGE.md
TERMINALS.md
doc/CURSES.md
doc/HACKING.md
include/notcurses/notcurses.h
include/notcurses/direct.h
include/notcurses/nckeys.h
```

Then study examples:

```text
src/poc/cli1.c
src/poc/direct.c
src/poc/gradients.c
src/poc/rgb.c
src/poc/scroll.c
src/poc/selector.c
src/poc/menu.c
src/poc/readline.c
src/poc/pixel.c
src/poc/blitters.c
src/poc/qrcode.c
```

For internals, study:

```text
src/lib/notcurses.c
src/lib/render.c
src/lib/blit.c
src/lib/fill.c
src/lib/egcpool.c
src/lib/termdesc.c
src/lib/in.c
src/lib/mice.c
src/input/input.cpp
```

See [references/ROADMAP.md](references/ROADMAP.md) for a staged learning plan.

## Zig integration pattern

Use `pkg-config` from `build.zig`:

```zig
exe.root_module.link_libc = true;
exe.root_module.linkSystemLibrary("notcurses", .{
    .use_pkg_config = .force,
});
```

Create a small raw C import module:

```zig
// src/notcurses.zig
pub const c = @cImport({
    @cInclude("notcurses/notcurses.h");
});
```

Then wrap gradually:

```zig
const nc = @import("notcurses").c;

pub const NotCurses = struct {
    ptr: *nc.notcurses,

    pub fn init() !NotCurses {
        var opts: nc.notcurses_options = .{};
        const ptr = nc.notcurses_init(&opts, null) orelse return error.NotcursesInitFailed;
        return .{ .ptr = ptr };
    }

    pub fn deinit(self: *NotCurses) void {
        _ = nc.notcurses_stop(self.ptr);
    }

    pub fn render(self: *NotCurses) !void {
        if (nc.notcurses_render(self.ptr) != 0) return error.RenderFailed;
    }

    pub fn stdplane(self: *NotCurses) *nc.ncplane {
        return nc.notcurses_stdplane(self.ptr);
    }
};
```

## First examples to build

1. Hello screen: init, write to stdplane, render, wait for key, stop.
2. Keyboard movement: move a character with arrow keys.
3. Multiple planes: background, panel, popup; experiment with z-order.
4. Colors/channels: foreground, background, alpha, gradients.
5. Resize handling: respond to `NCKEY_RESIZE` and recompute layout.
6. Widgets: selector, menu, reader, tabbed UI.
7. Visuals: load image, blit using terminal-supported graphics or degraded blitters.

## Troubleshooting checklist

Run inside the same terminal/session as the app:

```sh
echo "$TERM"
echo "$COLORTERM"
locale
stty size
notcurses-info
```

If using tmux:

```tmux
set -g default-terminal "tmux-256color"
set -as terminal-features ",*:RGB"
set -g allow-passthrough on
```

Restart tmux completely after changing config:

```sh
tmux kill-server
```

## Important API families

- Lifecycle: `notcurses_init`, `notcurses_core_init`, `notcurses_stop`, `notcurses_render`.
- Planes: `notcurses_stdplane`, `ncplane_create`, `ncplane_destroy`, `ncplane_putstr_yx`, `ncplane_erase`, `ncplane_move_yx`, `ncplane_resize`.
- Input: `notcurses_get_blocking`, `notcurses_get_nblock`, `ncinput`, `NCKEY_*`.
- Colors/channels: `NCCHANNELS_INITIALIZER`, `ncplane_set_fg_rgb`, `ncplane_set_bg_rgb`, `ncchannels_set_*_alpha`.
- Cells: `nccell_load`, `nccell_release`, `nccell_prime`, `nccell_duplicate`.
- Visuals: `ncvisual_from_file`, `ncvisual_from_rgba`, `ncvisual_blit`, `ncvisual_destroy`.
- Widgets: selector, multiselector, menu, reader, reel, tabbed, progbar, plot.
