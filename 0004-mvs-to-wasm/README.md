```
nix-shell
cd deps/binaryen
nix-shell -p cmake gnumake
export CXX=./zigc++
export CC=./zigcc
cmake . && make
cd ../../
zig build-exe ./lib/binaryen.zig -Ideps/binaryen/src/ deps/binaryen/lib/libbinaryen.a -lc++
```