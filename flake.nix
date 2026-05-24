{
  description = "Minimal example for learning notcurses";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      zig-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ zig-overlay.overlays.default ];
        };

        zig = pkgs.zigpkgs."0.16.0";
        zls = pkgs.zls;
        notcursesPatched = pkgs.notcurses.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (pkgs.fetchpatch {
              url = "https://github.com/dankamongmen/notcurses/pull/2926.patch";
              hash = "sha256-1EBbQZghAyvXks5KClStgZ1VXd4MGKm4NwkSXQOluXw=";
            })
          ];
        });
        zigTarget =
          if pkgs.stdenv.isLinux then "${pkgs.stdenv.hostPlatform.system}-gnu"
          else pkgs.stdenv.hostPlatform.system;
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "notcurses-min-example";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [
              zig.hook # this is what tells nix build what to run
              pkgs.pkg-config
            ];

            buildInputs = [
              notcursesPatched
            ];

            zigBuildFlags = [
              "-Dtarget=${zigTarget}"
              "-Drpath=${pkgs.lib.makeLibraryPath [
                notcursesPatched
                pkgs.ncurses
                pkgs.libunistring
                pkgs.libdeflate
                pkgs.glibc
                pkgs.stdenv.cc.cc.lib
              ]}"
            ];

            postInstall = ''
              ${pkgs.patchelfUnstable}/bin/patchelf \
                --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
                $out/bin/nc-min-ex
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            gcc
            zig
            zls
            notcursesPatched
            pkg-config
          ];

          shellHook = ''
            export NC_DEV_LOADER=${pkgs.stdenv.cc.bintools.dynamicLinker}
            export NC_DEV_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.glibc notcursesPatched pkgs.ncurses ]}
            export NC_DEV_RPATH=${pkgs.lib.makeLibraryPath [
              notcursesPatched
              pkgs.ncurses
              pkgs.libunistring
              pkgs.libdeflate
              pkgs.glibc
              pkgs.stdenv.cc.cc.lib
            ]}

            nc-run() {
              "$NC_DEV_LOADER" \
                --library-path "$NC_DEV_LIBRARY_PATH" \
                ./zig-out/bin/nc-min-ex "$@"
            }
            export -f nc-run
          '';
        };
      }
    );
}
