To run tests:

```sh
nix-shell
zig run -lc ./main.zig -- ./test.md
```

To rewrite tests:

```sh
nix-shell
zig run -lc ./main.zig -- --rewrite ./test.md
```