package main

import "ecs"
import rl "vendor:raylib"

render_creatures :: proc(world: ^ecs.World) {
	for archetype in ecs.query(world, {Position, Rotation, CreatureData}) {
		positions := ecs.get_table(world, archetype, Position)
		creatures := ecs.get_table(world, archetype, CreatureData)

		for position, i in positions {
			rl.DrawCircle(i32(position.x), i32(position.y), creatures[i].base_genes.size, rl.RED)
		}
	}
}
