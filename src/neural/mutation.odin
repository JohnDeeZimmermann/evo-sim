package neural

import "core:math/rand"

mutation_result :: proc(kind: Mutation_Kind, status: Mutation_Status) -> Mutation_Result {
	return {
		status = status,
		attempted_kind = kind,
		runtime_reset_required = status == .Applied,
	}
}

mutation_config_is_valid :: proc(config: Mutation_Config) -> bool {
	if !Is_Finite(config.added_weight_min) ||
	   !Is_Finite(config.added_weight_max) ||
	   !Is_Finite(config.allowed_weight_min) ||
	   !Is_Finite(config.allowed_weight_max) ||
	   config.added_weight_min > config.added_weight_max ||
	   config.allowed_weight_min > config.allowed_weight_max ||
	   config.added_weight_min < config.allowed_weight_min ||
	   config.added_weight_max > config.allowed_weight_max {
		return false
	}
	total: f32
	for weight in config.operation_weights {
		if !Is_Finite(weight) || weight < 0 {
			return false
		}
		total += weight
	}
	return Is_Finite(total) && total > 0
}

Change_Weight :: proc(
	schema: Schema,
	genes: ^Genes,
	connection_index: int,
	delta: f32,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Change_Weight
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if connection_index < 0 || connection_index >= int(genes.connection_count) ||
	   !Is_Finite(delta) || !Is_Finite(min_weight) || !Is_Finite(max_weight) ||
	   min_weight > max_weight {
		return mutation_result(kind, .Invalid_Argument)
	}
	old_weight := genes.connections[connection_index].weight
	new_weight := f32(clamp(f64(old_weight) + f64(delta), f64(min_weight), f64(max_weight)))
	if new_weight == old_weight {
		return mutation_result(kind, .No_Candidate)
	}
	genes.connections[connection_index].weight = new_weight
	return mutation_result(kind, .Applied)
}

Remove_Weight :: proc(
	schema: Schema,
	genes: ^Genes,
	connection_index: int,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Remove_Weight
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if connection_index < 0 || connection_index >= int(genes.connection_count) {
		return mutation_result(kind, .Invalid_Argument)
	}
	for i in connection_index ..< int(genes.connection_count) - 1 {
		genes.connections[i] = genes.connections[i + 1]
	}
	genes.connection_count -= 1
	genes.connections[genes.connection_count] = {}
	return mutation_result(kind, .Applied)
}

Add_Weight :: proc(
	schema: Schema,
	genes: ^Genes,
	source, destination: Node_Ref,
	weight: f32,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Add_Weight
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if int(genes.connection_count) >= MAX_CONNECTIONS {
		return mutation_result(kind, .Connection_Capacity)
	}
	if !Endpoint_Is_Valid(schema, genes, source) ||
	   !Endpoint_Is_Valid(schema, genes, destination) ||
	   !Direction_Is_Legal(source, destination) ||
	   !Is_Finite(weight) || weight < min_weight || weight > max_weight ||
	   Edge_Exists(genes, source, destination) ||
	   Would_Create_Cycle(genes, source, destination) {
		return mutation_result(kind, .Invalid_Argument)
	}
	genes.connections[genes.connection_count] = {source, destination, weight}
	genes.connection_count += 1
	return mutation_result(kind, .Applied)
}

Split_Weight :: proc(
	schema: Schema,
	genes: ^Genes,
	connection_index: int,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Split_Weight
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if connection_index < 0 || connection_index >= int(genes.connection_count) {
		return mutation_result(kind, .Invalid_Argument)
	}
	if int(genes.hidden_count) >= MAX_HIDDEN_NODES {
		return mutation_result(kind, .Hidden_Capacity)
	}
	if int(genes.connection_count) >= MAX_CONNECTIONS {
		return mutation_result(kind, .Connection_Capacity)
	}

	old_edge := genes.connections[connection_index]
	new_hidden := Node_Ref{.Hidden, genes.hidden_count}
	genes.hidden_nodes[genes.hidden_count] = {.LIN}
	genes.hidden_count += 1
	genes.connections[connection_index] = {new_hidden, old_edge.destination, old_edge.weight}
	genes.connections[genes.connection_count] = {old_edge.source, new_hidden, 1}
	genes.connection_count += 1
	return mutation_result(kind, .Applied)
}

Remove_Hidden :: proc(
	schema: Schema,
	genes: ^Genes,
	hidden_index: int,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Remove_Hidden
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if hidden_index < 0 || hidden_index >= int(genes.hidden_count) {
		return mutation_result(kind, .Invalid_Argument)
	}

	removed := u8(hidden_index)
	last := genes.hidden_count - 1
	write_index := 0
	old_connection_count := int(genes.connection_count)
	for read_index in 0 ..< old_connection_count {
		edge := genes.connections[read_index]
		if (edge.source.role == .Hidden && edge.source.index == removed) ||
		   (edge.destination.role == .Hidden && edge.destination.index == removed) {
			continue
		}
		if removed != last {
			if edge.source.role == .Hidden && edge.source.index == last {
				edge.source.index = removed
			}
			if edge.destination.role == .Hidden && edge.destination.index == last {
				edge.destination.index = removed
			}
		}
		genes.connections[write_index] = edge
		write_index += 1
	}
	for i in write_index ..< old_connection_count {
		genes.connections[i] = {}
	}
	genes.connection_count = u16(write_index)

	if removed != last {
		genes.hidden_nodes[removed] = genes.hidden_nodes[last]
	}
	genes.hidden_nodes[last] = {}
	genes.hidden_count -= 1
	return mutation_result(kind, .Applied)
}

Change_Function :: proc(
	schema: Schema,
	genes: ^Genes,
	hidden_index: int,
	activation: Activation,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Mutation_Result {
	kind := Mutation_Kind.Change_Function
	if Validate(schema, genes, min_weight, max_weight) != .None {
		return mutation_result(kind, .Invalid_Genome)
	}
	if hidden_index < 0 || hidden_index >= int(genes.hidden_count) ||
	   !Is_Activation_Valid(activation) {
		return mutation_result(kind, .Invalid_Argument)
	}
	if genes.hidden_nodes[hidden_index].activation == activation {
		return mutation_result(kind, .No_Candidate)
	}
	genes.hidden_nodes[hidden_index].activation = activation
	return mutation_result(kind, .Applied)
}

selected_mutation_kind :: proc(config: Mutation_Config, generator: rand.Generator) -> Mutation_Kind {
	total: f32
	last_nonzero := Mutation_Kind.Change_Weight
	for weight, i in config.operation_weights {
		total += weight
		if weight > 0 {
			last_nonzero = Mutation_Kind(i)
		}
	}
	draw := rand.float32(generator) * total
	cumulative: f32
	for weight, i in config.operation_weights {
		cumulative += weight
		if draw < cumulative {
			return Mutation_Kind(i)
		}
	}
	return last_nonzero
}

add_candidate_count :: proc(schema: Schema, genes: ^Genes) -> int {
	count := 0
	source_roles := [2]Node_Role{.Input, .Hidden}
	destination_roles := [2]Node_Role{.Hidden, .Output}
	for source_role in source_roles {
		source_count := source_role == .Input ? int(schema.input_count) : int(genes.hidden_count)
		for source_index in 0 ..< source_count {
			source := Node_Ref{source_role, u8(source_index)}
			for destination_role in destination_roles {
				destination_count := destination_role == .Hidden ? int(genes.hidden_count) : int(schema.output_count)
				for destination_index in 0 ..< destination_count {
					destination := Node_Ref{destination_role, u8(destination_index)}
					if Direction_Is_Legal(source, destination) &&
					   !Edge_Exists(genes, source, destination) &&
					   !Would_Create_Cycle(genes, source, destination) {
						count += 1
					}
				}
			}
		}
	}
	return count
}

add_candidate_at :: proc(schema: Schema, genes: ^Genes, selected: int) -> (Node_Ref, Node_Ref, bool) {
	current := 0
	source_roles := [2]Node_Role{.Input, .Hidden}
	destination_roles := [2]Node_Role{.Hidden, .Output}
	for source_role in source_roles {
		source_count := source_role == .Input ? int(schema.input_count) : int(genes.hidden_count)
		for source_index in 0 ..< source_count {
			source := Node_Ref{source_role, u8(source_index)}
			for destination_role in destination_roles {
				destination_count := destination_role == .Hidden ? int(genes.hidden_count) : int(schema.output_count)
				for destination_index in 0 ..< destination_count {
					destination := Node_Ref{destination_role, u8(destination_index)}
					if !Direction_Is_Legal(source, destination) ||
					   Edge_Exists(genes, source, destination) ||
					   Would_Create_Cycle(genes, source, destination) {
						continue
					}
					if current == selected {
						return source, destination, true
					}
					current += 1
				}
			}
		}
	}
	return {}, {}, false
}

// Mutate consumes RNG draws in this order: rate gate, operation selection,
// candidate selection, then operation-specific numeric data when required.
Mutate :: proc(
	schema: Schema,
	genes: ^Genes,
	generator: rand.Generator,
	mutation_rate: f32,
	mutation_intensity: f32,
	config := DEFAULT_MUTATION_CONFIG,
) -> Mutation_Result {
	if !mutation_config_is_valid(config) {
		return mutation_result(.Change_Weight, .Invalid_Argument)
	}
	if Validate(schema, genes, config.allowed_weight_min, config.allowed_weight_max) != .None {
		return mutation_result(.Change_Weight, .Invalid_Genome)
	}

	rate := clamp(Sanitize(mutation_rate), f32(0), f32(1))
	intensity := max(f32(0), Sanitize(mutation_intensity))
	if rand.float32(generator) >= rate {
		return mutation_result(.Change_Weight, .Skipped_Rate)
	}
	kind := selected_mutation_kind(config, generator)

	switch kind {
	case .Change_Weight:
		if genes.connection_count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		index := rand.int_max(int(genes.connection_count), generator)
		delta := rand.float32_range(-intensity, intensity, generator)
		return Change_Weight(
			schema,
			genes,
			index,
			delta,
			config.allowed_weight_min,
			config.allowed_weight_max,
		)

	case .Remove_Weight:
		if genes.connection_count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		index := rand.int_max(int(genes.connection_count), generator)
		return Remove_Weight(
			schema,
			genes,
			index,
			config.allowed_weight_min,
			config.allowed_weight_max,
		)

	case .Add_Weight:
		if int(genes.connection_count) >= MAX_CONNECTIONS {
			return mutation_result(kind, .Connection_Capacity)
		}
		count := add_candidate_count(schema, genes)
		if count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		selected := rand.int_max(count, generator)
		source, destination, ok := add_candidate_at(schema, genes, selected)
		if !ok {
			return mutation_result(kind, .No_Candidate)
		}
		weight := rand.float32_range(config.added_weight_min, config.added_weight_max, generator)
		return Add_Weight(
			schema,
			genes,
			source,
			destination,
			weight,
			config.allowed_weight_min,
			config.allowed_weight_max,
		)

	case .Split_Weight:
		if genes.connection_count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		index := rand.int_max(int(genes.connection_count), generator)
		return Split_Weight(
			schema,
			genes,
			index,
			config.allowed_weight_min,
			config.allowed_weight_max,
		)

	case .Remove_Hidden:
		if genes.hidden_count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		index := rand.int_max(int(genes.hidden_count), generator)
		return Remove_Hidden(
			schema,
			genes,
			index,
			config.allowed_weight_min,
			config.allowed_weight_max,
		)

	case .Change_Function:
		candidate_count := int(genes.hidden_count) * (ACTIVATION_COUNT - 1)
		if candidate_count == 0 {
			return mutation_result(kind, .No_Candidate)
		}
		selected := rand.int_max(candidate_count, generator)
		hidden_index := selected / (ACTIVATION_COUNT - 1)
		activation_index := selected % (ACTIVATION_COUNT - 1)
		current := int(genes.hidden_nodes[hidden_index].activation)
		if activation_index >= current {
			activation_index += 1
		}
		return Change_Function(
			schema,
			genes,
			hidden_index,
			Activation(activation_index),
			config.allowed_weight_min,
			config.allowed_weight_max,
		)
	}

	return mutation_result(kind, .No_Candidate)
}
