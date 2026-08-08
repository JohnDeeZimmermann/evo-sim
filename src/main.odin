package main

import "ecs"
import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, "Evolution Simulator")
	defer rl.CloseWindow()
	rl.SetTargetFPS(FPS)

	world := ecs.create_world()
	defer ecs.delete_world(world)

	create_creatures(world)
	for _ in 0..<5 {
		plant_spawner_create_random(world, {0, 0}, {DEFAULT_WIDTH, DEFAULT_HEIGHT})
	}
	game_loop(world)
}
