#!/usr/bin/env bash
# Creates the lock necessary for zig2nix to fetch dependencies
# for gobject bindings. Due to choice to not git track the `vendor/zig-gobject`,
# `nix build .#machtoo` will not be able to find the bindings.
#
# At the time of writing this, zig-gobject @ commit=90a738ce69a0f9533568077c8a7831628f20fa83
# has its generator depending on `zig-xml`. 
#
# =========
# NOTE: This is only necessary to run when chanigng the generator rev.
# =========

project="$PWD"
work="$(mktemp -d)"

git clone https://github.com/ianprime0509/zig-gobject.git "$work/generator"
git -C "$work/generator" checkout --detach \
  90a738ce69a0f9533568077c8a7831628f20fa83

(
  cd "$work/generator"
  nix run github:Cloudef/zig2nix -- zon2lock build.zig.zon
)

mkdir -p "$poject/nix"
cp "$work/generator/build.zig.zon2json-lock" \
  "$project/nix/gobject-generator.zon2json-lock"

rm -rf "$work"
git add nix/gobject-generator.zon2json-lock
