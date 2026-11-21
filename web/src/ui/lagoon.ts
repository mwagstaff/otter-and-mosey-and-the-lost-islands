import waterSource from "../../../OtterAndMosey/UI/Menus/RainbowIslandWater.fsh?raw";
import { artURL } from "../assets";
import { options } from "../game/options";
import { islandWildlife } from "./islandWildlife";

import { atmosphereSource, islandPaintings } from "../game/islandAtmosphere";

function painting(canvas: HTMLCanvasElement, art: string) {
  const gl = canvas.getContext("webgl", { alpha: false, antialias: false, depth: false });
  if (!gl) return;
  const program = gl.createProgram()!;
  function compile(type: number, source: string) {
    const shader = gl!.createShader(type)!;
    gl!.shaderSource(shader, source); gl!.compileShader(shader);
    gl!.attachShader(program, shader); gl!.deleteShader(shader);
  }
  compile(gl.VERTEX_SHADER, `
    attribute vec2 position;
    uniform vec2 crop;
    varying highp vec2 v_tex_coord;
    void main() {
      v_tex_coord = 0.5 + 0.5 * position * crop;
      gl_Position = vec4(position, 0.0, 1.0);
    }`);
  compile(gl.FRAGMENT_SHADER, `precision highp float;
    varying vec2 v_tex_coord;
    uniform sampler2D u_texture;
    uniform float u_time, u_saturation, u_theme, u_strength;
    ${art === "bg_title" ? waterSource : atmosphereSource}`);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.warn("Lagoon shader unavailable", gl.getProgramInfoLog(program));
    gl.getExtension("WEBGL_lose_context")?.loseContext();
    return;
  }
  gl.useProgram(program);
  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 3,-1, -1,3]), gl.STATIC_DRAW);
  const pos = gl.getAttribLocation(program, "position");
  gl.enableVertexAttribArray(pos); gl.vertexAttribPointer(pos, 2, gl.FLOAT, false, 0, 0);
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  for (const wrap of [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T]) gl.texParameteri(gl.TEXTURE_2D, wrap, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  gl.uniform1f(gl.getUniformLocation(program, "u_saturation"), 1);
  gl.uniform1f(gl.getUniformLocation(program, "u_theme"), islandPaintings.indexOf(art));
  gl.uniform1f(gl.getUniformLocation(program, "u_strength"), 1);
  const crop = gl.getUniformLocation(program, "crop"), clock = gl.getUniformLocation(program, "u_time");
  let ready = false;
  const img = new Image();
  img.onload = () => {
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, img);
    ready = true;
  };
  img.src = artURL(art);
  return {
    draw(time: number, scale: number) {
      if (!ready || gl.isContextLost()) { canvas.hidden = true; return; }
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform2f(crop, canvas.width / (900 * scale), canvas.height / (600 * scale));
      gl.uniform1f(clock, time); gl.drawArrays(gl.TRIANGLES, 0, 3);
      canvas.hidden = false;
    },
    destroy() {
      img.onload = null;
      gl.deleteTexture(texture); gl.deleteBuffer(buffer); gl.deleteProgram(program);
      gl.getExtension("WEBGL_lose_context")?.loseContext();
    },
  };
}

/** The host keeps its original CSS painting as the loading and reduced-motion view. */
export function animateLagoon(host: HTMLElement, art = "bg_title", input = host): () => void {
  const sky = document.createElement("canvas"), animals = document.createElement("canvas");
  for (const canvas of [sky, animals]) {
    canvas.className = "lagoon-animation";
    canvas.setAttribute("aria-hidden", "true");
  }
  host.prepend(sky);
  if (art === "bg_title") sky.after(animals);
  sky.hidden = true;
  const ctx = art === "bg_title" ? animals.getContext("2d") : null;
  const wildlife = islandWildlife();
  const preference = matchMedia("(prefers-reduced-motion: reduce)");
  let renderer: ReturnType<typeof painting>, attempted = false, frame = 0, previous = 0, time = 0;
  function draw(now: number) {
    if (document.hidden || options.reducedMotion) { sync(); return; }
    frame = requestAnimationFrame(draw);
    if (now - previous < 32) return;
    time += previous ? Math.min(0.1, (now - previous) / 1000) : 0;
    previous = now;
    const ratio = Math.min(devicePixelRatio, 1.5);
    const width = Math.round(host.clientWidth * ratio), height = Math.round(host.clientHeight * ratio);
    if (!width || !height) return;
    for (const canvas of [sky, animals]) {
      if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; }
    }
    const scale = Math.max(width / 900, height / 600);
    renderer?.draw(time, scale);
    if (ctx) {
      ctx.resetTransform(); ctx.clearRect(0, 0, width, height);
      ctx.setTransform(scale, 0, 0, scale, (width - 900 * scale) / 2, (height - 600 * scale) / 2);
      wildlife.draw(ctx, time);
    }
  }
  function sync() {
    cancelAnimationFrame(frame); previous = 0;
    if (document.hidden || options.reducedMotion) { sky.hidden = animals.hidden = true; return; }
    if (!attempted) { attempted = true; renderer = painting(sky, art); }
    animals.hidden = false;
    frame = requestAnimationFrame(draw);
  }
  function greet(event: MouseEvent) {
    if (!ctx || animals.hidden || !(event.target instanceof Element) ||
        event.target.closest("button, a, .decoration, .home-tray, header, .logo, .hero")) return;
    const rect = animals.getBoundingClientRect();
    const scale = Math.max(rect.width / 900, rect.height / 600);
    if (!scale) return;
    wildlife.tap((event.clientX - rect.left - rect.width / 2) / scale + 450,
                 (event.clientY - rect.top - rect.height / 2) / scale + 300, time);
  }
  if (ctx) input.addEventListener("click", greet);
  preference.addEventListener("change", sync);
  document.addEventListener("visibilitychange", sync);
  sync();
  return () => {
    cancelAnimationFrame(frame); renderer?.destroy();
    preference.removeEventListener("change", sync);
    document.removeEventListener("visibilitychange", sync);
    input.removeEventListener("click", greet);
    sky.remove(); animals.remove();
  };
}
