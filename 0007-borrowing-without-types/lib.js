async function load() {
  let instance = undefined;

  const writeString = function (string) {
    const encoded = new TextEncoder().encode(string);
    const string_ptr = instance.exports.alloc(encoded.length);
    const bytes = new Uint8Array(instance.exports.memory.buffer, string_ptr);
    bytes.set(encoded);
    return string_ptr;
  };

  const readString = function (string_ptr) {
    const bytes = new Uint8Array(instance.exports.memory.buffer, string_ptr);
    const string_len = bytes.indexOf(0);
    return new TextDecoder().decode(
      bytes.slice(0, string_len),
    );
  };

  function run(source) {
    const source_ptr = writeString(source);
    const result_ptr = instance.exports.run(source_ptr);
    const result = readString(result_ptr);
    instance.exports.free(result_ptr);
    instance.exports.free(source_ptr);
    return result;
  }

  instance =
    (await WebAssembly.instantiateStreaming(fetch("./lib.wasm"))).instance;

  console.log(run("2 + 2"));
}
