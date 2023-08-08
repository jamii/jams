const wasmCode = Deno.readFileSync("./test.wasm");
const wasmModule = new WebAssembly.Module(wasmCode);
const wasmInstance = new WebAssembly.Instance(wasmModule);
// TODO Need to allocate stack space first.
console.log(wasmInstance.exports.main());
