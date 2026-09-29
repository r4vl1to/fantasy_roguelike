class_name C_MoveTarget
extends Component

## Tile a player-controlled entity is walking toward (traditional roguelike
## click-to-move). `target` is in tile coordinates.
##
## `pending` = a destination was chosen but not confirmed yet: the tile and the
## trayecto are shown, waiting for confirmation, and the entity does NOT move.
## `active`  = destination confirmed: S_PlayerMovement advances one tile at a time.
@export var target: Vector2i = Vector2i.ZERO
@export var active: bool = false
@export var pending: bool = false
