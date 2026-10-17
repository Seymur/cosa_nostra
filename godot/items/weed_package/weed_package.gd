class_name WeedPackage
extends Equippable

## Maximum number of weed the package can hold.
@export var capacity := 10
## Number of weed currently in the package.
@export var weed_count := 0:
	set(value):
		weed_count = clampi(value, 0, capacity)

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D

func is_full() -> bool:
	return weed_count >= capacity

## Puts up to `amount` weed into the package. Returns how many did not fit.
func add_weed(amount := 1) -> int:
	var accepted := mini(amount, capacity - weed_count)
	weed_count += accepted
	return amount - accepted

## Takes up to `amount` weed out. Returns how many were actually removed.
func take_weed(amount := 1) -> int:
	var taken := mini(amount, weed_count)
	weed_count -= taken
	return taken
