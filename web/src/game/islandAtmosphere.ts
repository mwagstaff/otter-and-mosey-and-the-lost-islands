import { GlProgram, Mesh, MeshGeometry, Shader, Texture, UniformGroup } from "pixi.js";
import source from "../../../OtterAndMosey/Game/Scenes/IslandAtmosphere.fsh?raw";

export const islandPaintings = ["bg_woods", "bg_bay", "bg_dragon", "bg_cloud", "bg_candy", "bg_star", "bg_hollow", "bg_meadow", "bg_map"];
const atmosphereSource = "const vec4 v_color_mix = vec4(1.0);\n" + source;
export { atmosphereSource };

/** Far tiles share the same program and clock, including the mirrored tiles of scrolling levels. */
export function levelPainting(texture: Texture, art: string) {
  const uniforms = new UniformGroup({
    u_theme: { value: islandPaintings.indexOf(art), type: "f32" },
    u_time: { value: 0, type: "f32" },
    u_strength: { value: 1, type: "f32" },
  });
  const glProgram = GlProgram.from({
    vertex: `attribute vec2 aPosition, aUV;
      varying vec2 v_tex_coord;
      uniform mat3 uProjectionMatrix, uWorldTransformMatrix, uTransformMatrix;
      void main() {
        gl_Position = vec4((uProjectionMatrix * uWorldTransformMatrix * uTransformMatrix * vec3(aPosition,1.0)).xy,0.0,1.0);
        v_tex_coord = vec2(aUV.x, 1.0-aUV.y);
      }`,
    fragment: `varying vec2 v_tex_coord;
      uniform sampler2D u_texture;
      uniform float u_theme, u_time, u_strength;
      vec4 samplePainting(sampler2D tex, vec2 uv) { return texture2D(tex,vec2(uv.x,1.0-uv.y)); }
      ${atmosphereSource.replace("texture2D(u_texture", "samplePainting(u_texture")}`,
  });
  const shader = new Shader({glProgram, resources: { u_texture: texture.source, atmosphere: uniforms }});
  const x = texture.width / 2, y = texture.height / 2;
  const geometry = new MeshGeometry({
    positions: new Float32Array([-x,-y, x,-y, x,y, -x,y]),
    uvs: new Float32Array([0,0, 1,0, 1,1, 0,1]),
    indices: new Uint32Array([0,1,2, 0,2,3]),
  });
  return {
    uniforms: uniforms.uniforms,
    tile: () => new Mesh({geometry, shader, texture}),
    destroy() { geometry.destroy(); shader.destroy(); },
  };
}
