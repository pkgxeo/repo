# xeo.repo

main [xeon](https://github.com/arozoid/xeon) repo

## current packages

- `printc`: basic ANSI escape code print library

## how to make your own repo

(xeon is a prerequisite)

copy .xeon/* to your desired directory and remove endpoints.toml:

```bash
cd [directory]
cp -a ~/.xeon/* .
rm -rf endpoints.toml
```

then simply make your directory a git repository and publicize it. add and remove packages from your repo selection by just adding or deleting certain files in `./bin/`, `./lib/`, and `./pkg/`. for a more in-depth explanation, visit the [xeon](https://github.com/arozoid/xeon) github page.
