package neural

Schema_Is_Valid :: proc(schema: Schema) -> bool {
	return schema.input_count > 0 &&
	       schema.input_count <= MAX_INPUT_NODES &&
	       schema.output_count > 0 &&
	       schema.output_count <= MAX_OUTPUT_NODES
}

Counts_Are_Valid :: proc(genes: ^Genes) -> bool {
	return int(genes.hidden_count) <= MAX_HIDDEN_NODES &&
	       int(genes.connection_count) <= MAX_CONNECTIONS
}

Endpoint_Is_Valid :: proc(schema: Schema, genes: ^Genes, node: Node_Ref) -> bool {
	switch node.role {
	case .Input:
		return node.index < schema.input_count
	case .Hidden:
		return node.index < genes.hidden_count
	case .Output:
		return node.index < schema.output_count
	}
	return false
}

Direction_Is_Legal :: proc(source, destination: Node_Ref) -> bool {
	if source == destination {
		return false
	}
	return (source.role == .Input || source.role == .Hidden) &&
	       (destination.role == .Hidden || destination.role == .Output)
}

Edge_Exists :: proc(genes: ^Genes, source, destination: Node_Ref) -> bool {
	if !Counts_Are_Valid(genes) {
		return false
	}
	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if edge.source == source && edge.destination == destination {
			return true
		}
	}
	return false
}

Would_Create_Cycle :: proc(genes: ^Genes, source, destination: Node_Ref) -> bool {
	if source == destination {
		return true
	}
	if source.role != .Hidden || destination.role != .Hidden {
		return false
	}
	if !Counts_Are_Valid(genes) {
		return true
	}

	visited: [MAX_HIDDEN_NODES]bool
	queue: [MAX_HIDDEN_NODES]u8
	head, tail := 0, 0
	queue[tail] = destination.index
	tail += 1
	visited[destination.index] = true

	for head < tail {
		current := queue[head]
		head += 1
		if current == source.index {
			return true
		}

		for i in 0 ..< int(genes.connection_count) {
			edge := genes.connections[i]
			if edge.source.role != .Hidden || edge.source.index != current ||
			   edge.destination.role != .Hidden {
				continue
			}
			next := edge.destination.index
			if int(next) >= MAX_HIDDEN_NODES || visited[next] {
				continue
			}
			visited[next] = true
			queue[tail] = next
			tail += 1
		}
	}

	return false
}

Validate :: proc(
	schema: Schema,
	genes: ^Genes,
	min_weight := DEFAULT_MIN_WEIGHT,
	max_weight := DEFAULT_MAX_WEIGHT,
) -> Validation_Error {
	if !Schema_Is_Valid(schema) {
		return .Invalid_Schema
	}
	if !Counts_Are_Valid(genes) {
		return .Invalid_Count
	}
	if !Is_Finite(min_weight) || !Is_Finite(max_weight) || min_weight > max_weight {
		return .Weight_Out_Of_Range
	}

	for i in 0 ..< int(genes.hidden_count) {
		if !Is_Activation_Valid(genes.hidden_nodes[i].activation) {
			return .Invalid_Activation
		}
	}

	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if !Endpoint_Is_Valid(schema, genes, edge.source) ||
		   !Endpoint_Is_Valid(schema, genes, edge.destination) {
			return .Invalid_Endpoint
		}
		if !Direction_Is_Legal(edge.source, edge.destination) {
			return .Illegal_Direction
		}
		if !Is_Finite(edge.weight) {
			return .Non_Finite_Weight
		}
		if edge.weight < min_weight || edge.weight > max_weight {
			return .Weight_Out_Of_Range
		}
		for j in 0 ..< i {
			other := genes.connections[j]
			if edge.source == other.source && edge.destination == other.destination {
				return .Duplicate_Edge
			}
		}
	}

	for i in 0 ..< int(genes.connection_count) {
		edge := genes.connections[i]
		if Would_Create_Cycle(genes, edge.source, edge.destination) {
			return .Cycle
		}
	}

	return .None
}
