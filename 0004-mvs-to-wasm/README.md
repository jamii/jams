```
nix-shell
cd deps/binaryen
nix-shell -p cmake gnumake
export CXX=./zigc++
export CC=./zigcc
cmake . && make
cd ../../
zig build-lib lib/runtime.zig -target wasm32-freestanding -dynamic -rdynamic
zig run ./lib/binaryen.zig -Ideps/binaryen/src/ deps/binaryen/lib/libbinaryen.a -lc++
./deps/binaryen/bin/wasm-merge runtime.wasm runtime hello.wasm hello -o merged.wasm
```