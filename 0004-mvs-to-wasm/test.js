const wasmCode = Deno.readFileSync("./merged.wasm");
const wasmModule = new WebAssembly.Module(wasmCode);
const wasmInstance = new WebAssembly.Instance(wasmModule);
console.log(wasmInstance.exports.add(4));
