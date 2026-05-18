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
              zig.hook
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.notcurses
            ];

            zigBuildFlagsArray = [
              "-Dtarget=${zigTarget}"
            ];

            postInstall = ''
              mkdir -p $out/libexec
              mv $out/bin/nc-min-ex $out/libexec/nc-min-ex

              cat > $out/bin/nc-min-ex <<EOF
              #!${pkgs.runtimeShell}
              exec ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \\
                --library-path ${pkgs.lib.makeLibraryPath [ pkgs.glibc pkgs.notcurses pkgs.ncurses ]} \\
                $out/libexec/nc-min-ex "\$@"
              EOF

              chmod +x $out/bin/nc-min-ex
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            gcc
            zig
            zls
            notcurses
            pkg-config
          ];
        };
      }
    );
}
