extends Node

# Object pooling system for background parallax objects using GenericPool
const GenericPool = preload("res://scripts/utils/GenericPool.gd")
var object_pools: Array[GenericPool] = []
var pool_size: int = 20  # Objects per pool

# References to other systems
var background_parallax: Node

func _ready():
	# Get reference to the main background parallax system
	background_parallax = get_parent()

func initialize_object_pools():
	# Initialize object pools for each layer using GenericPool
	var layer_speeds = background_parallax.layer_speeds
	for i in range(layer_speeds.size() + 1):  # +1 for foreground layer
		var create_func: Callable
		var reset_func: Callable
		
		if i == 0:  # Foreground layer
			create_func = background_parallax.create_foreground_object
			reset_func = _reset_foreground_object
		else:  # Background layers
			create_func = background_parallax.create_random_object.bind(i - 1)
			reset_func = _reset_background_object.bind(i - 1)
		
		var pool = GenericPool.new(create_func, reset_func, pool_size)
		object_pools.append(pool)

func get_object_from_pool(layer_index: int) -> Node2D:
	var clamped_layer_index = clamp(layer_index, 0, object_pools.size() - 1)
	return object_pools[clamped_layer_index].get_object()

func return_object_to_pool(object: Node2D, layer_index: int):
	var clamped_layer_index = clamp(layer_index, 0, object_pools.size() - 1)
	object_pools[clamped_layer_index].return_object(object)

func clear_all_pools():
	# Clear all object pools completely
	for pool in object_pools:
		pool.clear_pool()

func _reset_foreground_object(object: Node2D):
	object.visible = false
	object.position = Vector2.ZERO

func _reset_background_object(object: Node2D, layer_index: int):
	object.visible = false
	object.position = Vector2.ZERO
	background_parallax.regenerate_object_shape(object, layer_index) 