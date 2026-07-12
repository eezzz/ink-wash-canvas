const fs = require("fs");
const html = fs.readFileSync("C:/Users/Eric/Claude/watercolor/ink-wash-canvas.html", "utf8");
const js = html.match(/<script>([\s\S]*)<\/script>/)[1];

function makeEl() {
  const target = function(){};
  return new Proxy(target, {
    get(t, k) {
      if (k === "classList") return { toggle(){}, add(){}, remove(){}, contains(){ return false; } };
      if (k === "style") return new Proxy({}, { set(){ return true; }, get(){ return ""; } });
      if (k === "dataset") return { s: "0" };
      if (k === "value") return "0.5";
      if (k === "innerHTML" || k === "textContent" || k === "className") return "";
      if (k === "clientWidth") return 1920;
      if (k === "clientHeight") return 1080;
      if (k === "width" || k === "height") return 1920;
      if (k === "getContext") return () => glStub;
      if (k === "querySelectorAll") return () => [];
      if (k === Symbol.iterator) return undefined;
      return (...a) => makeEl();
    },
    set(){ return true; },
    apply(){ return makeEl(); }
  });
}
const glStub = new Proxy({}, {
  get(t, k) {
    if (k === "drawingBufferWidth") return 1920;
    if (k === "drawingBufferHeight") return 1080;
    if (typeof k === "string" && k.toUpperCase() === k) return 1; // GL 常量
    return (...a) => {
      if (k === "getShaderParameter" || k === "getProgramParameter") return 1;
      if (k === "getActiveUniform") return { name: "u" + Math.random() };
      if (k === "getUniformLocation") return {};
      if (k === "getExtension") return {};
      if (k === "getShaderInfoLog" || k === "getProgramInfoLog") return "";
      return {};
    };
  },
  set(){ return true; }
});
global.window = new Proxy({ addEventListener(){}, devicePixelRatio: 1 }, { get(t,k){ return k in t ? t[k] : undefined; }, set(){ return true; } });
global.document = { getElementById: () => makeEl(), createElement: () => makeEl(), querySelectorAll: () => [] };
global.localStorage = { getItem: () => null, setItem(){}, removeItem(){} };
global.requestAnimationFrame = () => 0;
global.location = { search: '' };
global.Image = function(){ return makeEl(); };
global.URL = { createObjectURL: () => "", revokeObjectURL(){} };
global.canvasStub = null;

try {
  new Function(js)();
  console.log("INIT PATH OK — no runtime error");
} catch (err) {
  console.log("RUNTIME ERROR: " + err.message);
  console.log(err.stack.split("\n").slice(0, 4).join("\n")); process.exit(1);
}

