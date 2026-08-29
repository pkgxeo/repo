#!/usr/bin/env bash
# Generate a multi-page static site for the pkgxeo package repository.
#
# Produces (into the output dir):
#   index.html            home page: every package + description (clickable)
#   <name>.html           per package: files provided (pkg, lib, bin)
#   pkg/<name>.toml       package metadata (copied as-is)
#   lib/<name>/...        library source files (copied as-is)
#   bin/<name>-<arch>-<platform>  prebuilt binaries (expected to exist already)
#
# Usage: site.sh <list-dir> <out-dir>
set -euo pipefail

LIST_DIR="${1:?usage: site.sh <list-dir> <out-dir>}"
OUT_DIR="${2:?usage: site.sh <list-dir> <out-dir>}"

mkdir -p "$OUT_DIR/pkg" "$OUT_DIR/lib" "$OUT_DIR/bin"

# sanitize a package name into a safe url/filename slug (lowercase word)
slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

# read a field from a package toml, tolerating missing keys and slight syntax
toml_field() {
  local toml="$1" key="$2"
  sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$toml" | head -n1 | \
    sed 's/^"//; s/"$//'
}

html_head() {
  local title="$1"
  cat << HEAD
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 2rem auto; max-width: 56rem; padding: 0 1rem; line-height: 1.5; color: #222; }
  h1 { border-bottom: 2px solid #eee; padding-bottom: .5rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; padding: .5rem .75rem; border-bottom: 1px solid #eee; }
  th { background: #f6f6f6; }
  a { color: #0366d6; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .muted { color: #666; }
  .note { color: #666; font-size: .9rem; margin-top: 2rem; }
  ul { margin: .25rem 0 1rem 1.25rem; }
</style>
</head>
<body>
HEAD
}

html_foot() {
  local da
  da=$(date -u)
  cat << FOOT
  <p class="note">Built at ${da} UTC by GitHub Actions from <a href="https://github.com/pkgxeo/repo">pkgxeo/repo</a>.</p>
</body>
</html>
FOOT
}

# copy a package's library source files so package pages can link to them
copy_lib() {
  local pkg_dir="$1" name="$2"
  [ -d "$pkg_dir/lib" ] || return 0
  mkdir -p "$OUT_DIR/lib/$name"
  shopt -s nullglob
  for f in "$pkg_dir"/lib/*; do
    [ -f "$f" ] && cp "$f" "$OUT_DIR/lib/$name/"
  done
}

declare -a PACKAGES
mapfile -t PACKAGES < <(ls -d "$LIST_DIR"/*/ 2>/dev/null | sed "s|$LIST_DIR/||; s|/||" | grep -v -E '^(\.github|\.git)$' | sort)
if [ "${#PACKAGES[@]}" -eq 0 ]; then
  echo "::error:: no package directories found in $LIST_DIR" >&2
  exit 1
fi

# per-package info
declare -A DESC
declare -A VER

for name in "${PACKAGES[@]}"; do
  pkg_dir="$LIST_DIR/$name"
  toml="$pkg_dir/pkg/$name.toml"
  desc=$(toml_field "$toml" description || true)
  ver=$(toml_field "$toml" version || true)
  [ -n "$desc" ] || desc="$name — a pkgxeo package"
  [ -n "$ver" ] || ver=""
  DESC["$name"]="$desc"
  VER["$name"]="$ver"
  copy_lib "$pkg_dir" "$name"
done

# home page
html_head "pkgxeo packages" > "$OUT_DIR/index.html"
{
  echo '<h1>pkgxeo packages</h1>'
  echo '<p>Prebuilt binaries for every <code>pkgxeo</code> package, compiled for x86_64 and arm64 on Linux, Windows, and macOS. Click a package for its files.</p>'
  echo '<table><thead><tr><th>Package</th><th>Description</th></tr></thead><tbody>'
  for name in "${PACKAGES[@]}"; do
    printf '  <tr><td><a href="%s.html">%s</a></td><td>%s</td></tr>\n' \
      "$(slug "$name")" "$name" "${DESC[$name]}"
  done
  echo '</tbody></table>'
} >> "$OUT_DIR/index.html"
html_foot >> "$OUT_DIR/index.html"

# per-package pages
for name in "${PACKAGES[@]}"; do
  slugname=$(slug "$name")
  page="$OUT_DIR/$slugname.html"
  pkg_dir="$LIST_DIR/$name"

  html_head "$name — pkgxeo" > "$page"
  {
    echo "<p><a href=\"index.html\">&larr; all packages</a></p>"
    echo "<h1>$name</h1>"
    [ -n "${VER[$name]}" ] && echo "<p class=\"muted\">version ${VER[$name]}</p>"
    echo "<p>${DESC[$name]}</p>"

    # pkg metadata
    echo '<h2>pkg</h2>'
    if [ -f "$pkg_dir/pkg/$name.toml" ]; then
      printf '<p><a href="pkg/%s.toml">%s.toml</a> <span class="muted">(metadata)</span></p>\n' "$name" "$name"
    else
      echo '<p class="muted">no metadata</p>'
    fi

    # prebuilt binaries
    echo '<h2>bin</h2>'
    shopt -s nullglob
    bins=( "$OUT_DIR"/bin/"$name"-* )
    if [ "${#bins[@]}" -gt 0 ]; then
      echo '<ul>'
      for b in "${bins[@]}"; do
        fb=$(basename "$b")
        printf '  <li><a href="bin/%s">%s</a></li>\n' "$fb" "$fb"
      done
      echo '</ul>'
    else
      echo '<p class="muted">no prebuilt binaries</p>'
    fi

    # library source files
    echo '<h2>lib</h2>'
    shopt -s nullglob
    libfiles=( "$OUT_DIR"/lib/"$name"/* )
    if [ "${#libfiles[@]}" -gt 0 ]; then
      echo '<ul>'
      for lf in "${libfiles[@]}"; do
        fl=$(basename "$lf")
        printf '  <li><a href="lib/%s/%s">%s</a></li>\n' "$name" "$fl" "$fl"
      done
      echo '</ul>'
    else
      echo '<p class="muted">no library files</p>'
    fi
  } >> "$page"
  html_foot >> "$page"
done

echo "::notice:: generated ${#PACKAGES[@]} package page(s) in $OUT_DIR"
