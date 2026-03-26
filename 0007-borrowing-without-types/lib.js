async function load(wasm_url, CodeJar) {
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
    let result;
    try {
      const result_ptr = instance.exports.run(source_ptr);
      result = readString(result_ptr);
      instance.exports.free(result_ptr);
    } catch (error) {
      result = error.toString();
    }
    instance.exports.free(source_ptr);
    return result;
  }

  function refreshNode(parent_node) {
    const source = parent_node.querySelector(".test-source").jar.toString();
    const result = run(source);
    parent_node.querySelector(".test-result").innerText = result;
  }

  instance = (await WebAssembly.instantiateStreaming(fetch(wasm_url))).instance;

  if (run("2 + 2") != "4") {
    throw new Error("Code eval is broken");
  }

  const status_node = document.querySelector("#code-status");
  status_node.style.color = "green";
  status_node.innerText = "✓";

  for (const pre of document.querySelectorAll("pre.language-test")) {
    const source = pre.innerText.split("\n\n")[0];
    const result = run(source);
    const parent_node = document.createElement("div");
    parent_node.className = "test";
    const source_node = document.createElement("div");
    source_node.jar = CodeJar(source_node, (editor) => {});
    source_node.className = "test-source";
    source_node.jar.updateCode(source);
    parent_node.appendChild(source_node);
    const button = document.createElement("button");
    button.addEventListener("click", () => {
      refreshNode(parent_node);
    });
    button.className = "test-eval";
    button.innerText = "↓eval↓";
    parent_node.appendChild(button);
    const result_node = document.createElement("div");
    result_node.className = "test-result";
    result_node.innerText = result;
    parent_node.appendChild(result_node);
    pre.replaceWith(parent_node);
  }
}
