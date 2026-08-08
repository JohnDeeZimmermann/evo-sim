package main

FoodType :: enum {
	MEAT,
	PLANT,
}

Food :: struct {
	nutrition: f32,
	hardness:  f32,
	type:      FoodType,
}
