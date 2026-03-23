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

To build wasm:

```sh
nix-shell
zig build-exe -target wasm32-freestanding -fno-entry -rdynamic -fllvm ./wasm.zig --name lib
```