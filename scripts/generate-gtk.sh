#!/usr/bin/env bash
# Run inside the Nix dev shell with git, Zig, libxslt and
# gobject-introspection available. Generates GTK bindings from a pinned revision.
set -euo pipefail

project="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
commit=90a738ce69a0f9533568077c8a7831628f20fa83

for tool in git zig pkg-config xsltproc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing tool: %s. Run inside the configured Nix dev shell.\n' "$tool" >&2
    exit 1
  fi
done

gir_dir="$(pkg-config --variable=girdir gobject-introspection-1.0)"
if [[ -z "$gir_dir" || ! -d "$gir_dir" ]]; then
  printf 'Cannot locate GIR files. Add gobject-introspection to nativeBuildInputs.\n' >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone https://github.com/ianprime0509/zig-gobject.git "$work/generator"
git -C "$work/generator" checkout --detach "$commit"

# Nix distributes GIR files across multiple package directories.
args=("-Dgir-files-path=$gir_dir")
IFS=: read -ra dirs <<< "${XDG_DATA_DIRS:-}"
for dir in "${dirs[@]}"; do
  if [[ -d "$dir/gir-1.0" ]]; then
    args+=("-Dgir-files-path=$dir/gir-1.0")
  fi
done

(
  cd "$work/generator"
  zig build codegen -Dmodules=Gtk-4.0 "${args[@]}"
)

# Copy only after successful generation. Do not overwrite existing bindings.
destination="$project/vendor/zig-gobject"
if [[ -e "$destination" ]]; then
  printf 'Destination already exists: %s\nMove it aside before regenerating.\n' "$destination" >&2
  exit 1
fi
mkdir -p "$project/vendor"
cp -R "$work/generator/zig-out/bindings" "$destination"
printf 'Generated GTK bindings in %s\n' "$destination"
