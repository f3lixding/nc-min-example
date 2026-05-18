const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_bin = b.addExecutable(.{
        .name = "nc-min-ex",
        .root_module = b.addModule("main_module", .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Use the system linker instead of Zig's built-in ELF linker. This produces
    // ELF files that Nix/patchelf can reliably fix up.
    main_bin.use_lld = false;

    linkNc(main_bin);

    b.installArtifact(main_bin);
}

fn linkNc(bin: *std.Build.Step.Compile) void {
    // notcurses headers use wcwidth/wcswidth, whose declarations are exposed
    // by libc only when X/Open feature macros are enabled.
    bin.root_module.addCMacro("_XOPEN_SOURCE", "700");

    bin.root_module.linkSystemLibrary("notcurses", .{
        .use_pkg_config = .yes,
    });
}
