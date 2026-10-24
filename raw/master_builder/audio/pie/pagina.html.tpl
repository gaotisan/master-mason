<title>Pisadas del peregrino</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IM+Fell+English:ital@0;1&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Mesa de escucha: cabecera fija con recuento y filtros; debajo, un bloque por
   video con sus golpes en rejilla (forma de onda + marcas). */
:root {
  --bg: #edefe9;
  --panel: #f8f9f5;
  --ink: #1e2420;
  --muted: #5d665f;
  --line: #d3d8cf;
  --wave: #3f5a49;
  --accent: #2f5d45;
  --vale: #2e7d4f;
  --fuera: #b2472f;
  --duda: #a87a14;
  --sel: #2f5d45;
  --display: "IM Fell English", "Iowan Old Style", Georgia, serif;
  --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #141815; --panel: #1c211d; --ink: #e3e7e0; --muted: #9aa49b; --line: #2e352f;
    --wave: #8fb59c; --accent: #8fc4a3; --vale: #5cc287; --fuera: #e07a5f; --duda: #d9a93c; --sel: #8fc4a3;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #141815; --panel: #1c211d; --ink: #e3e7e0; --muted: #9aa49b; --line: #2e352f;
  --wave: #8fb59c; --accent: #8fc4a3; --vale: #5cc287; --fuera: #e07a5f; --duda: #d9a93c; --sel: #8fc4a3;
  color-scheme: dark;
}
* { box-sizing: border-box; }
body {
  background: var(--bg); color: var(--ink); font-family: var(--body); font-size: 14px; line-height: 1.45;
  padding-left: max(16px, env(safe-area-inset-left, 0px));
  padding-right: max(16px, env(safe-area-inset-right, 0px));
  padding-block: 0 48px;
}
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--bg); }
header {
  position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--bg);
  border-bottom: 1px solid var(--line); padding-block: 14px 12px; display: grid; gap: 10px;
}
.titulo { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px 16px; }
h1 { font-family: var(--display); font-weight: 400; font-size: 30px; margin: 0; letter-spacing: 0.01em; text-wrap: balance; }
.sub { color: var(--muted); max-width: 70ch; margin: 0; }
.cuentas { display: flex; flex-wrap: wrap; gap: 6px 14px; font-family: var(--mono); font-size: 13px; font-variant-numeric: tabular-nums; }
.cuentas b { font-weight: 500; }
.c-vale { color: var(--vale); } .c-fuera { color: var(--fuera); } .c-duda { color: var(--duda); }
.estado { color: var(--muted); }
.filtros { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.filtros .grupo { display: flex; flex-wrap: wrap; gap: 4px; margin-right: 8px; }
.chip {
  font: 500 12px var(--body); border: 1px solid var(--line); background: var(--panel); color: var(--ink);
  padding: 4px 10px; border-radius: 999px; cursor: pointer;
}
.chip[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); color: var(--bg); }
.chip:focus-visible, .tile:focus-visible, button:focus-visible { outline: 2px solid var(--sel); outline-offset: 2px; }
.teclas { color: var(--muted); font-size: 12px; }
.teclas kbd { font-family: var(--mono); font-size: 11px; border: 1px solid var(--line); border-bottom-width: 2px; border-radius: 4px; padding: 0 4px; background: var(--panel); }
main { display: grid; gap: 28px; padding-top: 18px; }
section.video { display: grid; gap: 10px; }
.vcab { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; }
.vcab h2 { font-family: var(--display); font-weight: 400; font-size: 21px; margin: 0; }
.vcab .meta { font-family: var(--mono); font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
.aviso { font-size: 12px; padding: 1px 8px; border-radius: 999px; border: 1px solid var(--duda); color: var(--duda); }
.vcab button { margin-left: auto; }
.btn {
  font: 500 12px var(--body); border: 1px solid var(--line); background: var(--panel); color: var(--ink);
  padding: 4px 10px; border-radius: 6px; cursor: pointer;
}
.rejilla { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px; }
.tile {
  background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 8px 8px 6px;
  display: grid; gap: 4px; cursor: pointer; position: relative; min-width: 0;
}
.tile.sel { border-color: var(--sel); box-shadow: 0 0 0 1px var(--sel); }
.tile.sonando canvas { opacity: 0.55; }
.tile[data-voto="vale"] { border-left: 4px solid var(--vale); }
.tile[data-voto="fuera"] { border-left: 4px solid var(--fuera); opacity: 0.6; }
.tile[data-voto="duda"] { border-left: 4px solid var(--duda); }
.tile canvas { width: 100%; height: 40px; display: block; }
.fila1 { display: flex; justify-content: space-between; gap: 6px; font-family: var(--mono); font-size: 12px; font-variant-numeric: tabular-nums; }
.fila1 .n { font-weight: 500; }
.fila1 .f { color: var(--muted); }
.fila2 { display: flex; gap: 6px; font-family: var(--mono); font-size: 11px; color: var(--muted); font-variant-numeric: tabular-nums; flex-wrap: wrap; }
.flojo { color: var(--duda); }
.votos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; margin-top: 2px; }
.votos button {
  font: 600 12px var(--body); border: 1px solid var(--line); background: transparent; color: var(--muted);
  padding: 3px 0; border-radius: 5px; cursor: pointer;
}
.votos button[data-v="vale"][aria-pressed="true"] { background: var(--vale); border-color: var(--vale); color: var(--bg); }
.votos button[data-v="fuera"][aria-pressed="true"] { background: var(--fuera); border-color: var(--fuera); color: var(--bg); }
.votos button[data-v="duda"][aria-pressed="true"] { background: var(--duda); border-color: var(--duda); color: var(--bg); }
.vacio { color: var(--muted); }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>

<header>
  <div class="titulo">
    <h1>Pisadas del peregrino</h1>
    <div class="cuentas" id="cuentas" aria-live="polite"></div>
  </div>
  <p class="sub">Cada golpe del audio de los videos de Veo, recortado y a igual volumen. Marca los que valen para la capa del pie; los de baculo, para sacar y guardar. Fondo = cuanto sobresale el golpe del ruido del video; cola = lo que tarda en apagarse (eco).</p>
  <div class="filtros" id="filtros"></div>
  <div class="teclas"><kbd>&larr;</kbd><kbd>&rarr;</kbd> moverse y escuchar · <kbd>espacio</kbd> repetir · <kbd>1</kbd> vale · <kbd>2</kbd> fuera · <kbd>3</kbd> duda (marca y pasa al siguiente) · <span class="estado" id="estado">conectando...</span></div>
</header>
<main id="lista"></main>

<script>
const DATOS = /*DATOS*/;
const VIDEOS = /*VIDEOS*/;

const marcas = {};            // id -> "vale" | "fuera" | "duda"
let db = null;
const filtro = { vista: "todas", tipo: "todos", flojos: true, pendientes: false };
let visibles = [];            // ids en orden de pantalla
let sel = null;

// --- audio: se descodifica al pedirlo y se guarda
let ctx = null;
const buffers = {};
let fuente = null;
async function buffer(id) {
  if (!buffers[id]) {
    buffers[id] = fetch("escucha/" + id + ".mp3").then(r => r.arrayBuffer()).then(b => ctx.decodeAudioData(b));
  }
  return buffers[id];
}
async function tocar(id, cuando = 0) {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  if (ctx.state === "suspended") await ctx.resume();
  const b = await buffer(id);
  const s = ctx.createBufferSource();
  s.buffer = b; s.connect(ctx.destination);
  s.start(ctx.currentTime + cuando);
  const el = document.querySelector(`.tile[data-id="${id}"]`);
  if (el) {
    setTimeout(() => el.classList.add("sonando"), cuando * 1000);
    setTimeout(() => el.classList.remove("sonando"), (cuando + b.duration) * 1000);
  }
  return s;
}
function parar() { try { fuente && fuente.stop(); } catch (e) {} }

// toda la secuencia de un video, cada golpe a su tiempo original
async function tocarVideo(clave) {
  const fs = DATOS.filter(d => d.video === clave);
  const t0 = fs[0].t;
  for (const d of fs) tocar(d.id, d.t - t0 + 0.05);
}

// --- forma de onda
function dibujar(canvas, forma, voto) {
  const r = window.devicePixelRatio || 1;
  const w = canvas.clientWidth || 140, h = canvas.clientHeight || 40;
  canvas.width = w * r; canvas.height = h * r;
  const g = canvas.getContext("2d");
  g.scale(r, r);
  const css = getComputedStyle(document.documentElement);
  g.fillStyle = css.getPropertyValue(voto ? "--" + voto : "--wave").trim();
  const n = forma.length, bw = w / n;
  for (let i = 0; i < n; i++) {
    const a = Math.max(forma[i] * (h / 2 - 1), 0.5);
    g.fillRect(i * bw + 0.5, h / 2 - a, Math.max(bw - 1, 1), a * 2);
  }
}

// --- marcas
async function marcar(id, voto) {
  const antes = marcas[id];
  const nuevo = antes === voto ? null : voto;
  if (nuevo) marcas[id] = nuevo; else delete marcas[id];
  pintarTile(id); cuentas();
  if (db) {
    try {
      const ref = db.doc("marcas/" + id);
      if (nuevo) await ref.set({ voto: nuevo, video: DATOS_POR_ID[id].video, fecha: new Date().toISOString() });
      else await ref.delete();
    } catch (e) {
      estado("no se pudo guardar: " + (e.code || e.message));
    }
  } else {
    try { localStorage.setItem("marcas", JSON.stringify(marcas)); } catch (e) {}
  }
}
const DATOS_POR_ID = Object.fromEntries(DATOS.map(d => [d.id, d]));

function estado(t) { document.getElementById("estado").textContent = t; }

function cuentas() {
  const n = { vale: 0, fuera: 0, duda: 0 };
  for (const v of Object.values(marcas)) n[v]++;
  const total = DATOS.length, pend = total - n.vale - n.fuera - n.duda;
  document.getElementById("cuentas").innerHTML =
    `<span class="c-vale"><b>${n.vale}</b> valen</span><span class="c-fuera"><b>${n.fuera}</b> fuera</span>` +
    `<span class="c-duda"><b>${n.duda}</b> duda</span><span><b>${pend}</b> sin marcar de ${total}</span>`;
}

// --- filtros
const OPC = {
  vista: [["todas", "Todas"], ["perfil", "Perfil"], ["frente", "Frente"], ["diagonal", "Diagonal"]],
  tipo: [["todos", "Todo"], ["andar", "Andar"], ["correr", "Correr"], ["giro", "Giro"], ["baculo", "Baculo"]],
};
function filtros() {
  const f = document.getElementById("filtros");
  f.innerHTML = "";
  for (const [clave, opciones] of Object.entries(OPC)) {
    const g = document.createElement("div"); g.className = "grupo";
    for (const [v, txt] of opciones) {
      const b = document.createElement("button");
      b.className = "chip"; b.textContent = txt; b.id = `f-${clave}-${v}`;
      b.setAttribute("aria-pressed", String(filtro[clave] === v));
      b.onclick = () => { filtro[clave] = v; filtros(); lista(); };
      g.appendChild(b);
    }
    f.appendChild(g);
  }
  const g = document.createElement("div"); g.className = "grupo";
  for (const [clave, txt] of [["flojos", "Con flojos"], ["pendientes", "Solo sin marcar"]]) {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = txt; b.id = "f-" + clave;
    b.setAttribute("aria-pressed", String(filtro[clave]));
    b.onclick = () => { filtro[clave] = !filtro[clave]; filtros(); lista(); };
    g.appendChild(b);
  }
  f.appendChild(g);
}

function pasa(d) {
  if (filtro.vista !== "todas" && d.vista !== filtro.vista) return false;
  if (filtro.tipo !== "todos" && d.tipo !== filtro.tipo) return false;
  if (!filtro.flojos && d.flojo) return false;
  if (filtro.pendientes && marcas[d.id]) return false;
  return true;
}

function mediana(a) { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : 0; }

// --- lista
function lista() {
  const main = document.getElementById("lista");
  main.innerHTML = "";
  visibles = [];
  for (const [clave, v] of Object.entries(VIDEOS)) {
    const fs = DATOS.filter(d => d.video === clave && pasa(d));
    if (!fs.length) continue;
    const todos = DATOS.filter(d => d.video === clave);
    const snr = mediana(todos.map(d => d.snr_db)), cola = mediana(todos.map(d => d.cola_s ?? 0.6));
    const sec = document.createElement("section"); sec.className = "video";
    const avisos = [];
    if (snr < 20) avisos.push("fondo con ruido");
    if (cola > 0.18) avisos.push("con eco");
    sec.innerHTML = `<div class="vcab"><h2>${v.que}</h2>
      <span class="meta">${v.vista} · ${v.tipo} · ${todos.length} golpes · fondo ${snr.toFixed(0)} dB · cola ${cola.toFixed(2)} s</span>
      ${avisos.map(a => `<span class="aviso">${a}</span>`).join("")}
      <button class="btn" type="button">Oir seguidos</button></div>
      <div class="rejilla"></div>`;
    sec.querySelector(".vcab button").onclick = () => tocarVideo(clave);
    const rej = sec.querySelector(".rejilla");
    for (const d of fs) {
      visibles.push(d.id);
      const t = document.createElement("div");
      t.className = "tile"; t.tabIndex = 0; t.dataset.id = d.id;
      const n = d.id.slice(clave.length + 1);
      t.innerHTML = `<div class="fila1"><span class="n">#${n}</span><span class="f">fotograma ${d.fotograma}</span></div>
        <canvas aria-hidden="true"></canvas>
        <div class="fila2"><span>fondo ${d.snr_db.toFixed(0)}</span><span>cola ${d.cola_s == null ? "larga" : d.cola_s.toFixed(2)}</span>${d.flojo ? '<span class="flojo">flojo</span>' : ""}</div>
        <div class="votos"><button type="button" data-v="vale" title="Vale (1)">Vale</button><button type="button" data-v="fuera" title="Fuera (2)">Fuera</button><button type="button" data-v="duda" title="Duda (3)">Duda</button></div>`;
      t.onclick = (e) => {
        const b = e.target.closest("button[data-v]");
        if (b) { marcar(d.id, b.dataset.v); return; }
        seleccionar(d.id, true);
      };
      rej.appendChild(t);
    }
    main.appendChild(sec);
  }
  if (!visibles.length) main.innerHTML = '<p class="vacio">Nada con estos filtros.</p>';
  for (const id of visibles) pintarTile(id);
  if (sel && visibles.includes(sel)) document.querySelector(`.tile[data-id="${sel}"]`).classList.add("sel");
}

function pintarTile(id) {
  const t = document.querySelector(`.tile[data-id="${id}"]`);
  if (!t) return;
  const v = marcas[id] || "";
  if (v) t.dataset.voto = v; else delete t.dataset.voto;
  for (const b of t.querySelectorAll("button[data-v]")) b.setAttribute("aria-pressed", String(b.dataset.v === v));
  dibujar(t.querySelector("canvas"), DATOS_POR_ID[id].forma, v);
}

function seleccionar(id, sonar) {
  document.querySelectorAll(".tile.sel").forEach(e => e.classList.remove("sel"));
  sel = id;
  const t = document.querySelector(`.tile[data-id="${id}"]`);
  if (!t) return;
  t.classList.add("sel");
  t.focus({ preventScroll: true });
  t.scrollIntoView({ block: "nearest", behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  if (sonar) tocar(id);
}

document.addEventListener("keydown", (e) => {
  if (e.target.closest && e.target.closest("input, textarea")) return;
  const i = sel ? visibles.indexOf(sel) : -1;
  if (e.key === "ArrowRight" || e.key === "ArrowDown") { e.preventDefault(); if (i + 1 < visibles.length) seleccionar(visibles[i + 1], true); }
  else if (e.key === "ArrowLeft" || e.key === "ArrowUp") { e.preventDefault(); if (i > 0) seleccionar(visibles[i - 1], true); }
  else if (e.key === " ") { e.preventDefault(); if (sel) tocar(sel); else if (visibles.length) seleccionar(visibles[0], true); }
  else if (["1", "2", "3"].includes(e.key) && sel) {
    e.preventDefault();
    const voto = { "1": "vale", "2": "fuera", "3": "duda" }[e.key];
    const actual = sel;
    marcar(actual, voto);
    if (filtro.pendientes) {
      // la tile se queda hasta la proxima vez que se filtra: pasa al siguiente igual
    }
    const j = visibles.indexOf(actual);
    if (j + 1 < visibles.length) seleccionar(visibles[j + 1], true);
  }
});

let redibujo = null;
window.addEventListener("resize", () => { clearTimeout(redibujo); redibujo = setTimeout(() => visibles.forEach(pintarTile), 150); });
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => visibles.forEach(pintarTile));

filtros(); cuentas(); lista();

(async () => {
  db = window.claude && window.claude.use ? await window.claude.use("db") : null;
  if (!db) {
    try { Object.assign(marcas, JSON.parse(localStorage.getItem("marcas") || "{}")); } catch (e) {}
    estado("sin conexion: las marcas se quedan en este navegador");
    cuentas(); visibles.forEach(pintarTile);
    return;
  }
  estado("las marcas se guardan");
  db.collection("marcas").onSnapshot((snap) => {
    for (const k of Object.keys(marcas)) delete marcas[k];
    for (const d of snap.docs) { const v = d.data().voto; if (v) marcas[d.id] = v; }
    cuentas(); visibles.forEach(pintarTile);
  }, (err) => estado("sin conexion con las marcas (" + err.code + ")"));
})();
</script>
