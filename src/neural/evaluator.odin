package neural

accumulate :: proc(destination: ^f32, value: f32) {
	destination^ = Sanitize(destination^ + Sanitize(value))
}

reset_default :: proc(state: ^Runtime_State) {
	state^ = {}
}

evaluate_latch :: proc(state: ^Runtime_State, hidden_index: int, sum: f32) -> f32 {
	is_positive := Sanitize(sum) > 0
	if is_positive && !state.latch_was_positive[hidden_index] {
		state.latch_on[hidden_index] = !state.latch_on[hidden_index]
	}
	state.latch_was_positive[hidden_index] = is_positive
	return state.latch_on[hidden_index] ? 1 : 0
}

evaluate_default :: proc(
	schema: Schema,
	genes: ^Genes,
	state: ^Runtime_State,
	inputs: []f32,
	outputs: []f32,
) -> Evaluation_Status {
	if !Schema_Is_Valid(schema) ||
	   len(inputs) != int(schema.input_count) ||
	   len(outputs) != int(schema.output_count) {
		return .Invalid_Dimensions
	}
	if !Counts_Are_Valid(genes) {
		return .Invalid_Genome
	}
	for &output in outputs {
		output = 0
	}

	for i in 0 ..< int(genes.hidden_count) {
		if !Is_Activation_Valid(genes.hidden_nodes[i].activation) {
			return .Invalid_Genome
		}
	}
	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if !Endpoint_Is_Valid(schema, genes, edge.source) ||
		   !Endpoint_Is_Valid(schema, genes, edge.destination) ||
		   !Direction_Is_Legal(edge.source, edge.destination) {
			return .Invalid_Genome
		}
	}

	// Compute a complete order first so a cyclic genome cannot partially update latches.
	indegrees: [MAX_HIDDEN_NODES]u8
	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if edge.source.role == .Hidden && edge.destination.role == .Hidden {
			indegrees[edge.destination.index] += 1
		}
	}

	queue: [MAX_HIDDEN_NODES]u8
	order: [MAX_HIDDEN_NODES]u8
	head, tail, order_count := 0, 0, 0
	for i in 0 ..< int(genes.hidden_count) {
		if indegrees[i] == 0 {
			queue[tail] = u8(i)
			tail += 1
		}
	}
	for head < tail {
		current := queue[head]
		head += 1
		order[order_count] = current
		order_count += 1
		for i in 0 ..< int(genes.connection_count) {
			edge := genes.connections[i]
			if edge.source.role == .Hidden && edge.source.index == current &&
			   edge.destination.role == .Hidden {
				indegrees[edge.destination.index] -= 1
				if indegrees[edge.destination.index] == 0 {
					queue[tail] = edge.destination.index
					tail += 1
				}
			}
		}
	}
	if order_count != int(genes.hidden_count) {
		return .Cycle
	}

	hidden_sums: [MAX_HIDDEN_NODES]f32
	hidden_values: [MAX_HIDDEN_NODES]f32
	output_sums: [MAX_OUTPUT_NODES]f32

	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if edge.source.role != .Input {
			continue
		}
		value := Sanitize(inputs[edge.source.index]) * Sanitize(edge.weight)
		switch edge.destination.role {
		case .Hidden:
			accumulate(&hidden_sums[edge.destination.index], value)
		case .Output:
			accumulate(&output_sums[edge.destination.index], value)
		case .Input:
		}
	}

	for order_index in 0 ..< order_count {
		hidden_index := int(order[order_index])
		activation := genes.hidden_nodes[hidden_index].activation
		if activation == .LAT {
			hidden_values[hidden_index] = evaluate_latch(state, hidden_index, hidden_sums[hidden_index])
		} else {
			hidden_values[hidden_index] = Activate(activation, hidden_sums[hidden_index])
		}

		for i in 0 ..< int(genes.connection_count) {
			edge := genes.connections[i]
			if edge.source.role != .Hidden || int(edge.source.index) != hidden_index {
				continue
			}
			value := Sanitize(hidden_values[hidden_index] * Sanitize(edge.weight))
			switch edge.destination.role {
			case .Hidden:
				accumulate(&hidden_sums[edge.destination.index], value)
			case .Output:
				accumulate(&output_sums[edge.destination.index], value)
			case .Input:
			}
		}
	}

	for i in 0 ..< int(schema.output_count) {
		outputs[i] = Sanitize(output_sums[i])
	}
	return .Success
}
