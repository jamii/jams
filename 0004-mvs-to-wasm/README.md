```
nix-shell
cd deps/binaryen
nix-shell -p cmake gnumake
export CXX=./zigc++
export CC=./zigcc
cmake . && make
cd ../../
zig build-lib lib/runtime_wasm.zig -target wasm32-freestanding -dynamic -rdynamic -O ReleaseSafe -fstrip
zig run -lc -lc++ -Ideps/binaryen/src/ deps/binaryen/lib/libbinaryen.a lib/test.zig -- test/basic
```