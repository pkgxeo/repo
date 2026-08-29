# xeo.repo

main [xeon](https://github.com/arozoid/xeon) package repository.

## packages

every package lives under the [`pkgxeo/list`](https://github.com/pkgxeo/list)
submodule, which tracks each package as its own nested submodule. each package
has a standard `lib/`, `bin/`, and `pkg/` layout:

- `env`: starter environment helpers
- `fs`: starter filesystem helpers
- `printc`: basic ANSI escape code print library
- `template`: package/extension template

## building

pust extensions are built automatically by github actions on every commit,
on manual `workflow_dispatch`, and daily at 12:00 utc. each package is compiled
for **x86_64** and **arm64** on **macOS**, **windows**, and **linux**.

prebuilt binaries are available as:

- [github pages site](https://pkgxeo.github.io/repo/) — an index of every binary
- build artifacts attached to each workflow run

to build everything locally:

```bash
git submodule update --init --recursive
for d in env fs printc template; do
  (cd "list/$d" && cargo build --release)
done
```

## updating packages

the `list` submodule and its nested package submodules are pinned to specific
commits. to refresh them to the latest published package versions:

```bash
git submodule update --init --recursive
cd list
git submodule update --remote --merge
cd ..
git add list
git commit -m "chore: update packages"
```
