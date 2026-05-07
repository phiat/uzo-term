package uzo_term

// Shardwall — the existing 7×7 cube grid, instead of being a wireframe
// backdrop, becomes a textured mosaic of the live TUI. Each cube takes one
// 1/49th tile of term_target and faces the camera; small per-cube wobble
// means the seams shimmer slightly and the image fragments more as the
// camera flies. Drawn in place of the wireframes inside draw_3d_scene.

import "core:math"
import rlgl "vendor:raylib/rlgl"

shardwall_active: bool = true

// Compose a local-space cube vertex with a Y-axis rotation, then translate
// it into world space. Inlined into the per-vertex emits below; pulled out
// here so the body of draw_shardwall stays readable.
@(private = "file")
xform :: proc(lx, ly, lz, cos_a, sin_a, ox, oy, oz: f32) -> (f32, f32, f32) {
	wx := lx * cos_a + lz * sin_a
	wz := -lx * sin_a + lz * cos_a
	return ox + wx, oy + ly, oz + wz
}

draw_shardwall :: proc(t: f32) {
	if !shardwall_active do return

	rlgl.SetTexture(term_target.texture.id)
	rlgl.Begin(rlgl.QUADS)

	half := f32(0.6 * 0.5) // matches old DrawCubeWires sz=0.6 → half-extent 0.3

	for ix in -3 ..= 3 {
		for iz in -3 ..= 3 {
			x := f32(ix) * 2.5
			z := f32(iz) * 2.5 - 4
			y := math.sin(t * 0.6 + f32(ix + iz) * 0.8) * 0.4

			// UV sub-rect — far cubes (iz=-3) at top of screen show TUI top
			// (high V because raylib RenderTexture is V-flipped at sample).
			u0 := f32(ix + 3) / 7.0
			u1 := f32(ix + 4) / 7.0
			v_top := f32(4 - iz) / 7.0
			v_bot := f32(3 - iz) / 7.0

			// Per-cube wobble — small Y-axis rotation, hashed phase per cube.
			hash := u32((ix + 100) * 173 + (iz + 100) * 31)
			phase := f32(hash % 1000) / 1000.0 * math.PI * 2
			angle := math.sin(t * 0.3 + phase) * 0.18
			cos_a := math.cos(angle)
			sin_a := math.sin(angle)

			// Camera-facing face only (front +Z after the local rotation).
			x0, y0, z0 := xform(-half, -half, half, cos_a, sin_a, x, y, z)
			x1, y1, z1 := xform( half, -half, half, cos_a, sin_a, x, y, z)
			x2, y2, z2 := xform( half,  half, half, cos_a, sin_a, x, y, z)
			x3, y3, z3 := xform(-half,  half, half, cos_a, sin_a, x, y, z)

			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x0, y0, z0)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x1, y1, z1)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x2, y2, z2)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x3, y3, z3)
		}
	}

	rlgl.End()
	rlgl.SetTexture(0)
}
