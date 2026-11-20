{
  description = "machtoo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, zig, ... }:
  let
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];

    forAllPlatforms = f: nixpkgs.lib.genAttrs platforms (
      system: f (import nixpkgs {
        inherit system;
        overlays = [ zig.overlays.default ];
      })
    );

    mkGtkSetup = pkgs:
      let
        isLinux = pkgs.stdenv.hostPlatform.isLinux;
        patchedPkgConfig = pkgs.runCommandLocal "patched-pkg-config" {} ''
          mkdir -p "$out"

          substitute ${pkgs.graphene.dev}/lib/pkgconfig/graphene-1.0.pc \
            "$out/graphene-1.0.pc" \
            --replace-quiet '-mfpmath=sse -msse -msse2' ""

          substitute ${pkgs.glib.dev}/lib/pkgconfig/gmodule-2.0.pc \
            "$out/gmodule-2.0.pc" \
            --replace-quiet '-Wl,--export-dynamic' "" \
            --replace-quiet '-Wl,-export-dynamic' ""
        '';
      in {
        nativeBuildInputs = pkgs.lib.optionals isLinux ( with pkgs; [
            pkg-config
            libxslt
            gobject-introspection
          ]
        );

        buildInputs = pkgs.lib.optionals isLinux [ pkgs.gtk4 ];

        setup = pkgs.lib.optionalString isLinux ''
          # Search modified PC files before the originals.
          export PKG_CONFIG_PATH="${patchedPkgConfig}:''${PKG_CONFIG_PATH:-}"
        '';
        runSetup = pkgs.lib.optionalString isLinux ''
          # Run with the loader matching this shell's GTK dependencies.
          export MACHTOO_DYNAMIC_LINKER="${pkgs.stdenv.cc.bintools.dynamicLinker}"
        '';
      };
  in
  {
    devShells = forAllPlatforms (pkgs: let
        gtkSetup = mkGtkSetup pkgs;
      in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          git

          nixd
          nixfmt

          lldb
          clang-tools
          zls
          zigpkgs."0.17.0"
        ];

        shellHook = gtkSetup.setup + gtkSetup.runSetup;
      };
    });
  };
}
