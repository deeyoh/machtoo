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
  in
  {
    devShells = forAllPlatforms (pkgs: let
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
      default = pkgs.mkShell {
        nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
          with pkgs; [
            pkg-config
            libxslt
            gobject-introspection
          ]
        );

        packages = with pkgs; [
          git

          nixd
          nixfmt

          clang-tools
          zls
          zigpkgs."0.17.0"
        ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          gtk4
        ];

        shellHook = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          # Search modified PC files before the originals.
          export PKG_CONFIG_PATH="${patchedPkgConfig}:''${PKG_CONFIG_PATH:-}"
          # Run with the loader matching this shell's GTK dependencies.
          export MACHTOO_DYNAMIC_LINKER="${pkgs.stdenv.cc.bintools.dynamicLinker}"
        '';
      };
    });
  };
}
