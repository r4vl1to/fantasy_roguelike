@tool
class_name E_Player
extends Entity

func define_components() -> Array:
	return [
		C_Position.new(),
		C_CurrentChunk.new(),
		C_PlayerControl.new(),
		C_MoveSpeed.new(),
		C_MoveTarget.new(),
	]
