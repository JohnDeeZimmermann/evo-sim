package main

import "ecs"
import rl "vendor:raylib"

render :: proc(world: ^ecs.World) {

	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)
	// render_creatures(world)
	render_circles(world)
	rl.EndDrawing()
}

render_creatures :: proc(world: ^ecs.World) {
	for archetype in ecs.query(world, {Position, Rotation, Size}) {
		positions := ecs.get_table(world, archetype, Position)
		sizes := ecs.get_table(world, archetype, Size)

		for position, i in positions {
			rl.DrawCircle(i32(position.x), i32(position.y), f32(sizes[i]), rl.RED)
		}
	}
}

render_circles :: proc(world: ^ecs.World) {
	for arch in ecs.query(world, {RenderCircle, Size, Position}) {
		circles := ecs.get_table(world, arch, RenderCircle)
		sizes := ecs.get_table(world, arch, Size)
		positions := ecs.get_table(world, arch, Position)

		for position, idx in positions {
			size := f32(sizes[idx])
			circle := circles[idx]
			bw := f32(circle.border_width)

			rl.DrawCircle(i32(position.x), i32(position.y), size, circle.border_color)
			rl.DrawCircle(i32(position.x), i32(position.y), size * (1 - bw), circle.inner_color)
		}
	}
}
