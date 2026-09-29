class_name C_Sprite_Render
extends Component

# Remember components only hold data to operate on and mutate
# They don't provide functionality outside of data operations on itself
var sprite : AnimatedSprite2D
var tween : Tween

func _init(_s : AnimatedSprite2D) -> void:
	sprite = _s
