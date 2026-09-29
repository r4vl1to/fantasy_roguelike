@tool
class_name E_ChunkProbe
extends Entity


func define_components() -> Array:
	return [C_Position.new(), C_CurrentChunk.new(), C_ChunkResident.new()]
