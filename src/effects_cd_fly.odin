package uzo_term

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// cd Camera Fly-Through — typing a `cd` command triggers a quick camera
// swoop into the 3D scene, then lands at a fresh random viewpoint with
// a punch on FOV. The target directory name is splashed across the
// floating cubes during the fly.

cam_anim_t:     f32 = -1
cam_origin_pos: rl.Vector3
cam_zoom_pos:   rl.Vector3
cam_origin_fov: f32
cam_zoom_fov:   f32
cam_fade:       f32 // lingers after animation ends, decays to 0

// Directory name shown on cubes during the fly
cd_dir_buf: [128]u8
cd_dir_len: int

trigger_cd_fly :: proc(dir: string = "~") {
	// Strip trailing slashes, then take last path component
	trimmed := dir
	for len(trimmed) > 1 && trimmed[len(trimmed) - 1] == '/' {
		trimmed = trimmed[:len(trimmed) - 1]
	}
	display := trimmed
	for i := len(trimmed) - 1; i >= 0; i -= 1 {
		if trimmed[i] == '/' {
			if i < len(trimmed) - 1 {
				display = trimmed[i + 1:]
			}
			break
		}
	}
	if len(display) == 0 do display = "/"

	n := min(len(display), len(cd_dir_buf) - 1)
	for i in 0 ..< n {
		cd_dir_buf[i] = display[i]
	}
	cd_dir_buf[n] = 0
	cd_dir_len = n
	cam_anim_t = 0
	cam_origin_pos = camera.position
	cam_origin_fov = camera.fovy
	// Fly to a new random viewpoint — each cd changes the perspective
	angle := rand.float32() * math.PI * 2
	radius := 4.0 + rand.float32() * 6.0
	height := 1.5 + rand.float32() * 5.0
	cam_zoom_pos = {
		math.cos(angle) * radius,
		height,
		math.sin(angle) * radius,
	}
	cam_zoom_fov = 25.0 + rand.float32() * 35.0
}

update_camera_fly :: proc() {
	if cam_anim_t < 0 do return
	dt := rl.GetFrameTime()
	cam_anim_t += dt / cfg.cam_duration // advances 0→1
	if cam_anim_t >= 1.0 {
		cam_anim_t = -1
		cam_fade = 1.0 // start fade-out tail
		camera.position = cam_zoom_pos
		camera.fovy = cam_zoom_fov
		cam_origin_pos = cam_zoom_pos
		cam_origin_fov = cam_zoom_fov
		return
	}
	// Ease-out cubic: fast start, smooth deceleration into destination
	t := cam_anim_t
	s := 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
	camera.position[0] = cam_origin_pos[0] + (cam_zoom_pos[0] - cam_origin_pos[0]) * s
	camera.position[1] = cam_origin_pos[1] + (cam_zoom_pos[1] - cam_origin_pos[1]) * s
	camera.position[2] = cam_origin_pos[2] + (cam_zoom_pos[2] - cam_origin_pos[2]) * s

	// FOV: punch narrow mid-flight then ease to destination
	fov_punch := math.sin(t * math.PI) * 0.4
	fov_lerp := cam_origin_fov + (cam_zoom_fov - cam_origin_fov) * s
	camera.fovy = fov_lerp * (1.0 - fov_punch)
}

// 0..1 during fly and fade-out tail.
cam_fly_intensity :: proc() -> f32 {
	if cam_fade > 0 {
		cam_fade = max(0, cam_fade - rl.GetFrameTime() * 1.2)
	}
	if cam_anim_t >= 0 do return min(cam_anim_t * 3.0, 1.0)
	return cam_fade
}

// Draw the cd target dir on cube positions — call after EndMode3D, before terminal overlay.
draw_cd_labels :: proc() {
	fly := cam_fly_intensity()
	if fly < 0.05 || cd_dir_len == 0 do return

	label := cstring(&cd_dir_buf[0])
	alpha := u8(fly * 240)
	t := elapsed_g

	for ix in -2 ..= 2 {
		for iz in -2 ..= 2 {
			x := f32(ix) * 2.5
			z := f32(iz) * 2.5 - 4
			y := math.sin(t * 0.6 + f32(ix + iz) * 0.8) * 0.4 + 0.5

			screen := rl.GetWorldToScreen({x, y, z}, camera)
			if screen.x < -100 || screen.x > f32(window_w + 100) do continue
			if screen.y < -100 || screen.y > f32(window_h + 100) do continue

			dx := x - camera.position[0]
			dy := y - camera.position[1]
			dz := z - camera.position[2]
			depth := math.sqrt(dx * dx + dy * dy + dz * dz)
			if depth < 0.5 do continue
			sz := i32(clamp(350.0 / depth, 10, 48))

			fsz := f32(sz)
			tw := rl.MeasureTextEx(font, label, fsz, 1).x
			pos := rl.Vector2{screen.x - tw * 0.5, screen.y - fsz * 0.5}

			rl.DrawTextEx(font, label, pos, fsz, 1,
				{cfg.fg_color.r, cfg.fg_color.g, cfg.fg_color.b, alpha})
		}
	}
}
