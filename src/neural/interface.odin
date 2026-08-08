package neural

Evaluate_Proc :: #type proc(
	schema: Schema,
	genes: ^Genes,
	state: ^Runtime_State,
	inputs: []f32,
	outputs: []f32,
) -> Evaluation_Status

Reset_Proc :: #type proc(state: ^Runtime_State)

Evaluator :: struct {
	evaluate: Evaluate_Proc,
	reset:    Reset_Proc,
}

Default_Evaluator :: proc() -> Evaluator {
	return {evaluate = evaluate_default, reset = reset_default}
}
