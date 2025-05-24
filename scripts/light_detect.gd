extends Node3D

var light_level: float

func _process(_delta) -> void:
	var mesh_instance := get_node("MeshInstance3D")
	get_node("SubViewportContainer/SubViewport/Camera3D").global_position = Vector3(mesh_instance.global_position.x, mesh_instance.global_position.y + 0.3, mesh_instance.global_position.z)
	var image: Image = get_node("SubViewportContainer/SubViewport").get_texture().get_image()
	var floats: Array[float]
	for y in range(0, image.get_height()):
		for x in range(0, image.get_width()):
			var pixel = image.get_pixel(x, y)
			var light_value = (pixel.r + pixel.g + pixel.b) / 3.0
			floats.append(light_value)
	light_level = average(floats)
	pass

func average(numbers: Array) -> float:
	var sum = 0.0
	for n in numbers:
		sum += n
	return sum / numbers.size()
