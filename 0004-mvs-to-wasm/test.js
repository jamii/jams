const wasmCode = Deno.readFileSync("./test.wasm");
const wasmModule = new WebAssembly.Module(wasmCode);

let memory = undefined;

function print_string(ptr, len) {
  let str = (new TextDecoder()).decode(new Uint8Array(memory.buffer, ptr, len));
  console.log(str);
}
const wasmInstance = new WebAssembly.Instance(wasmModule, {
  env: { print_string },
});

memory = wasmInstance.exports.memory;

wasmInstance.exports.main();
