extends RefCounted

# Generic object pooling system that can be reused across the project
class_name GenericPool

var pool: Array = []
var max_pool_size: int = 100
var create_function: Callable
var reset_function: Callable

func _init(create_func: Callable, reset_func: Callable = Callable(), max_size: int = 100):
	create_function = create_func
	reset_function = reset_func
	max_pool_size = max_size

func get_object() -> Object:
	if pool.size() > 0:
		var object = pool.pop_back()
		if reset_function.is_valid():
			reset_function.call(object)
		return object
	else:
		return create_function.call()

func return_object(object: Object):
	if object and pool.size() < max_pool_size:
		pool.append(object)

func clear_pool():
	for object in pool:
		if is_instance_valid(object):
			object.queue_free()
	pool.clear()

func get_pool_size() -> int:
	return pool.size()

func get_max_pool_size() -> int:
	return max_pool_size 