class_name C_Vision
extends Component

## Cone of vision for a player-controlled entity.
##
## The owner perceives other entities only when they fall inside an open cone
## (its "vision"): a wedge centred on the entity's tile, of length `radius_tiles`
## and total opening `cone_angle_degrees`, pointing along `facing`.
##
## The fixed world (terrain) is NOT gated by this component: it is always drawn
## and remembered. Only other entities' sprites are hidden outside the cone
## (see S_Vision). The cone is also drawn as an overlay by VisionOverlay.
##
## `facing` is a unit direction in tile space. It turns with movement and can be
## aimed freely toward a clicked tile with Ctrl + click (see S_ClickToMove).

## How far the entity sees, in tiles — the length of the cone.
@export var radius_tiles: float = 10.0

## Full opening angle of the cone in degrees; the cone spans ±angle/2 around
## `facing`.
@export var cone_angle_degrees: float = 90.0

## Unit direction the entity is looking at, in tile space.
@export var facing: Vector2 = Vector2.RIGHT
## Direction of travel is tracked separately so the player may move while facing
## another direction; releasing Ctrl restores facing to this movement direction.
@export var movement_facing: Vector2 = Vector2.RIGHT

## When false, vision never hides anything (debugging / deterministic tests).
@export var enabled: bool = true