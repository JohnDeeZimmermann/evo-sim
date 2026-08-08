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
	game_loop(world)
}
