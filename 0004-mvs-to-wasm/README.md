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

Questions:
* Compile/run time vs bytecode interpreter with same layout?
  * How much is this affected by types?
  * Cost of re-merging runtime vs indirection through js?
* How much is layout constrained?
* Best approach to linking? Abi?