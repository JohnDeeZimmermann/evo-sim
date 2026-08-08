package main

import "ecs"
import rl "vendor:raylib"

render_creatures :: proc(world: ^ecs.World) {
	for archetype in ecs.query(world, {Position, Rotation, Size}) {
		positions := ecs.get_table(world, archetype, Position)
		sizes := ecs.get_table(world, archetype, Size)

		for position, i in positions {
			rl.DrawCircle(i32(position.x), i32(position.y), f32(sizes[i]), rl.RED)
		}
	}
}
