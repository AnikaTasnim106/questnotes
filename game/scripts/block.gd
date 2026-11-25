class_name Block
extends StaticBody2D
## Invisible solid rectangle (the walls are painted by RoomView).

func setup(rect: Rect2) -> Block:
	position = rect.position
	collision_layer = 1
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = rect.size / 2.0
	add_child(cs)
	return self
