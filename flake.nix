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

    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { self, nixpkgs, zig, zig2nix, ... }:
  let
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
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
    packages = forAllPlatforms(pkgs:
      pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
        let
          gtkSetup = mkGtkSetup pkgs;
          env = zig2nix.outputs.zig-env.${pkgs.stdenv.hostPlatform.system} {
            inherit nixpkgs;
            zig = zig2nix.packages.${pkgs.stdenv.hostPlatform.system}."zig-0_17_0";
          };

          gobjectSource = pkgs.fetchFromGitHub {
            owner = "ianprime0509";
            repo = "zig-gobject";
            rev = "90a738ce69a0f9533568077c8a7831628f20fa83";
            hash = "sha256-5svWKFn2ttsMRJaxMsmp/KLwdeATDSgqv1ToCJxPo3Y=";
          };

          gobjectDeps = env.deriveLockFile ./nix/gobject-generator.zon2json-lock
          {
            name = "gobject-generator-dependencies";
          };
        in
        {
          machtoo = env.package {
            pname = "machtoo-gtk";
            version = "0.1.0";
            src = pkgs.lib.cleanSource ./.;

            nativeBuildInputs = gtkSetup.nativeBuildInputs ++ [
              pkgs.autoPatchelfHook
              pkgs.wrapGAppsHook4
            ];

            inherit (gtkSetup) buildInputs;
            preBuild = gtkSetup.setup + ''
              (
                export MACHTOO_GOBJECT_SOURCE="${gobjectSource}"

                # Keep the generator's cache separate from Machtoo's cache.
                export ZIG_GLOBAL_CACHE_DIR="$(mktemp -d)"
                ln -s "${gobjectDeps}" "$ZIG_GLOBAL_CACHE_DIR/p"

                bash scripts/generate-gtk.sh
              )
            '';

            zigBuildFlags = [
              "-Dapprt=gtk"
              "-Doptimize=ReleaseFast"
            ];

            zigTarget = "${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux-gnu.${pkgs.glibc.version}";
            zigPreferMusl = false;
            meta.mainProgram = "machtoo";
          };
        }
      )
    );

    devShells = forAllPlatforms (pkgs: let
        gtkSetup = mkGtkSetup pkgs;
      in {
      default = pkgs.mkShell {
        inherit (gtkSetup) nativeBuildInputs buildInputs;
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

    homeManagerModules.default =
      import ./nix/machtoo-module.nix { inherit self; };
  };
}
