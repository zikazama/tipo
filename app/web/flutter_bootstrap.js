{{flutter_js}}
{{flutter_build_config}}

(function () {
  var rev = _flutter.buildConfig && _flutter.buildConfig.engineRevision;
  if (!rev) return;

  function preload(href, as) {
    var link = document.createElement("link");
    link.rel = "preload";
    link.as = as;
    link.href = href;
    link.crossOrigin = "anonymous";
    document.head.appendChild(link);
  }

  var supportsWasmGC = false;
  try {
    supportsWasmGC = WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0]));
  } catch (e) {}

  var base = "https://www.gstatic.com/flutter-canvaskit/" + rev + "/";
  if (supportsWasmGC) {
    // Chrome Lighthouse path: skwasm (not CanvasKit).
    var hasCodecs = typeof ImageDecoder !== "undefined";
    var hasBreak = typeof Intl !== "undefined" && typeof Intl.Segmenter !== "undefined";
    var sk = hasCodecs && hasBreak ? "skwasm.wasm" : "skwasm_heavy.wasm";
    preload(base + sk, "fetch");
  } else {
    var hasCodecs2 = typeof ImageDecoder !== "undefined";
    var hasBreak2 = typeof Intl !== "undefined" && typeof Intl.Segmenter !== "undefined";
    var hasCluster = typeof TextCluster !== "undefined";
    var path = "canvaskit.wasm";
    if (hasCodecs2 && hasBreak2) {
      path = hasCluster ? "webparagraph/canvaskit.wasm" : "chromium/canvaskit.wasm";
    }
    preload(base + path, "fetch");
  }
})();

_flutter.loader.load({
  config: {
    canvasKitVariant: "chromium",
    preferWebParagraph: true,
    useLocalCanvasKit: false,
  },
});
