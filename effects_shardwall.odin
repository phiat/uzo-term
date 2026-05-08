package uzo_term

// Shardwall — the existing 7×7 cube grid, instead of being a wireframe
// backdrop, becomes a textured mosaic of the live TUI. Each cube takes one
// 1/49th tile of term_target, with all six faces sampling the same sub-rect
// so the cubes stay solid as the cd-fly camera arcs around the grid.
// Per-cube wobble means the seams shimmer slightly and the image fragments
// more as the camera flies. Drawn in place of the wireframes inside
// draw_3d_scene.

import "core:math"
import rlgl "vendor:raylib/rlgl"

shardwall_active: bool = true

// Compose a local-space cube vertex with a Y-axis rotation, then translate
// it into world space.
@(private = "file")
xform :: proc(lx, ly, lz, cos_a, sin_a, ox, oy, oz: f32) -> (f32, f32, f32) {
	wx := lx * cos_a + lz * sin_a
	wz := -lx * sin_a + lz * cos_a
	return ox + wx, oy + ly, oz + wz
}

draw_shardwall :: proc(t: f32) {
	if !shardwall_active do return

	// Disable backface culling for the duration — keeps cubes visible from
	// every angle the cd-fly arcs through, regardless of winding direction.
	rlgl.DisableBackfaceCulling()
	defer rlgl.EnableBackfaceCulling()

	rlgl.SetTexture(term_target.texture.id)
	rlgl.Begin(rlgl.QUADS)

	fly := cam_fly_intensity()
	half := f32(0.6 * 0.5) + fly * 0.15 // base 0.30, swells to ~0.45 during fly

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

			// Eight corners — local space, then xformed into world.
			x0, y0, z0 := xform(-half, -half,  half, cos_a, sin_a, x, y, z) // F-BL
			x1, y1, z1 := xform( half, -half,  half, cos_a, sin_a, x, y, z) // F-BR
			x2, y2, z2 := xform( half,  half,  half, cos_a, sin_a, x, y, z) // F-TR
			x3, y3, z3 := xform(-half,  half,  half, cos_a, sin_a, x, y, z) // F-TL
			x4, y4, z4 := xform(-half, -half, -half, cos_a, sin_a, x, y, z) // B-BL
			x5, y5, z5 := xform( half, -half, -half, cos_a, sin_a, x, y, z) // B-BR
			x6, y6, z6 := xform( half,  half, -half, cos_a, sin_a, x, y, z) // B-TR
			x7, y7, z7 := xform(-half,  half, -half, cos_a, sin_a, x, y, z) // B-TL

			// Front (+Z)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x0, y0, z0)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x1, y1, z1)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x2, y2, z2)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x3, y3, z3)

			// Back (-Z)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x5, y5, z5)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x4, y4, z4)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x7, y7, z7)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x6, y6, z6)

			// Right (+X)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x1, y1, z1)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x5, y5, z5)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x6, y6, z6)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x2, y2, z2)

			// Left (-X)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x4, y4, z4)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x0, y0, z0)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x3, y3, z3)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x7, y7, z7)

			// Top (+Y)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x3, y3, z3)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x2, y2, z2)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x6, y6, z6)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x7, y7, z7)

			// Bottom (-Y)
			rlgl.TexCoord2f(u0, v_bot); rlgl.Vertex3f(x4, y4, z4)
			rlgl.TexCoord2f(u1, v_bot); rlgl.Vertex3f(x5, y5, z5)
			rlgl.TexCoord2f(u1, v_top); rlgl.Vertex3f(x1, y1, z1)
			rlgl.TexCoord2f(u0, v_top); rlgl.Vertex3f(x0, y0, z0)
		}
	}

	rlgl.End()
	rlgl.SetTexture(0)
}
