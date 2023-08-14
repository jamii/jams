let memory = undefined;
let bytes = undefined;

function print_string(ptr, len) {
  let str = (new TextDecoder()).decode(new Uint8Array(memory.buffer, ptr, len));
  console.log(str);
}
WebAssembly.instantiateStreaming(fetch("./test.wasm"), {
  env: { print_string },
}).then(
  (results) => {
    const wasmInstance = results.instance;
    memory = wasmInstance.exports.memory;
    bytes = new Uint8Array(memory.buffer);
    wasmInstance.exports.main();
  },
);
