package main

import rl "vendor:raylib"

import "ecs"

Systems :: []SystemDefinition{SystemMovement}

game_loop :: proc(world: ^ecs.World) {
	result := make(SystemResult)
	defer delete(result)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		render_creatures(world)
		rl.EndDrawing()

		if !run_systems(Systems, world, &result, dt) {
			return
		}

		free_all(context.temp_allocator)
	}
}
