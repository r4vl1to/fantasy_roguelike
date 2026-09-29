class_name Player
extends Entity

func define_components() -> Array:
	return [C_Position.new(), C_CurrentChunk.new()]
