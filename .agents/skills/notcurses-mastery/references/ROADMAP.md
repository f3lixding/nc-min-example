# Notcurses Mastery Roadmap

## Phase 1: API user

Goal: build confidence with the public C API from Zig.

Read:

- `USAGE.md`: Planes, Input, Channels, Cells
- `include/notcurses/notcurses.h`
- `src/poc/cli1.c`
- `src/poc/gradients.c`

Build:

1. Hello world on the stdplane.
2. Wait-for-key example.
3. Arrow-key movement example.
4. Full-screen layout with a border and status line.
5. Resize-aware layout.

Key APIs:

```c
notcurses_init
notcurses_stop
notcurses_render
notcurses_stdplane
notcurses_stddim_yx
notcurses_get_blocking
ncplane_putstr_yx
ncplane_erase
ncplane_set_base
```

## Phase 2: Planes and composition

Goal: understand Notcurses as a compositor.

Read:

- `USAGE.md`: Planes
- `src/tests/plane.cpp`
- `src/tests/zaxis.cpp`
- `src/tests/piles.cpp`

Build:

1. Background plane.
2. Floating panel.
3. Modal popup.
4. Overlapping transparent planes.
5. Destroy/recreate panels dynamically.

Key APIs:

```c
ncplane_create
ncplane_destroy
ncplane_move_top
ncplane_move_bottom
ncplane_move_yx
ncplane_resize
ncplane_set_base
ncplane_set_scrolling
ncplane_set_autogrow
```

## Phase 3: Color, cells, Unicode

Goal: understand why Notcurses is Unicode-first and color-rich.

Read:

- `USAGE.md`: Cells, Channels
- `src/tests/cell.cpp`
- `src/tests/channels.cpp`
- `src/tests/wide.cpp`
- `src/lib/egcpool.c`

Build:

1. RGB palette demo.
2. Gradient demo.
3. Unicode width stress test.
4. Emoji/grapheme cluster test.
5. Alpha/blending demo.

Key APIs:

```c
NCCHANNELS_INITIALIZER
NCCHANNEL_INITIALIZER
ncplane_set_fg_rgb
ncplane_set_bg_rgb
ncchannels_set_fg_alpha
ncchannels_set_bg_alpha
nccell_load
nccell_release
```

## Phase 4: Input and interaction

Goal: build interactive applications.

Read:

- `USAGE.md`: Input, Mice
- `TERMINALS.md`: keyboard protocols and terminal notes
- `src/poc/direct-input.c`
- `src/lib/in.c`
- `src/input/input.cpp`

Build:

1. Key inspector.
2. Command palette.
3. Mouse-clickable button.
4. Scrollable list.
5. Keyboard shortcut system.

Key APIs:

```c
notcurses_get_blocking
notcurses_get_nblock
notcurses_inputready_fd
notcurses_mice_enable
notcurses_mice_disable
ncinput_ctrl_p
ncinput_alt_p
NCKEY_*
```

## Phase 5: Widgets

Goal: understand reusable UI components.

Read:

- `USAGE.md`: Widgets
- `src/poc/selector.c`
- `src/poc/multiselect.c`
- `src/poc/menu.c`
- `src/poc/readline.c`
- `src/poc/tabbed.c`
- `src/lib/selector.c`
- `src/lib/menu.c`
- `src/lib/reader.c`
- `src/lib/tabbed.c`

Build:

1. Selector-based menu.
2. Multiselect checklist.
3. Search input with reader.
4. Tabbed settings UI.
5. Dashboard with progbar/plot.

## Phase 6: Visuals and terminal graphics

Goal: learn images, videos, pixels, and degradation.

Read:

- `USAGE.md`: Visuals, Multimedia, Pixels
- `TERMINALS.md`
- `src/poc/pixel.c`
- `src/poc/blitters.c`
- `src/poc/qrcode.c`
- `src/lib/visual.c`
- `src/lib/sixel.c`
- `src/lib/kitty.c`
- `src/media/ffmpeg.c`

Build:

1. Image viewer.
2. Pixel-art renderer.
3. QR-code generator.
4. Terminal capability comparison tool.
5. Optional: video frame viewer.

## Phase 7: Contributor-level internals

Goal: be able to debug Notcurses itself.

Read:

- `doc/HACKING.md`
- `src/lib/render.c`
- `src/lib/blit.c`
- `src/lib/fill.c`
- `src/lib/termdesc.c`
- `src/lib/notcurses.c`
- `src/tests/*`

Learn:

- pile rendering
- rasterization/writeout
- damage and composition
- terminal capability detection
- Unicode cell storage
- Kitty and Sixel protocols
- input ambiguity and keyboard protocols

Contribute:

1. Add a small regression test.
2. Fix a documentation gap.
3. Improve a Zig wrapper example.
4. Debug a terminal-specific issue.
