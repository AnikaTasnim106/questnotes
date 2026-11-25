class_name Door
extends StaticBody2D
## Wooden double door in a room's north wall. Opens when the room is cleared.

var sprite: Sprite2D
var _shape: CollisionShape2D
var is_open := false


func setup(top_left: Vector2, tile: float) -> Door:
	position = top_left
	collision_layer = 1
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture = Art.tex("doors_leaf_closed")
	sprite.centered = false
	sprite.scale = Vector2(Art.SCALE, Art.SCALE)
	add_child(sprite)
	for side in [["doors_frame_left", -tile], ["doors_frame_right", tile * 2.0]]:
		var f := Sprite2D.new()
		f.texture = Art.tex(side[0])
		f.centered = false
		f.scale = Vector2(Art.SCALE, Art.SCALE)
		f.position = Vector2(side[1], 0)
		add_child(f)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tile * 2.0, tile * 2.0)
	_shape = CollisionShape2D.new()
	_shape.shape = shape
	_shape.position = shape.size / 2.0
	add_child(_shape)
	return self


func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	sprite.texture = Art.tex("doors_leaf_open")
	Sfx.play("door", -2.0)
	var tw := create_tween()
	sprite.modulate = Color(1.6, 1.4, 1.0)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.6)
