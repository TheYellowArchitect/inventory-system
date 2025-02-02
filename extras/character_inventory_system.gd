@tool
@icon("res://addons/inventory-system/icons/character_inventory_system.svg")
class_name CharacterInventorySystem
extends NodeInventories

signal dropped(node : Node)
signal opened_station(station : CraftStation)
signal closed_station(station : CraftStation)
signal opened_inventory(inventory : Inventory)
signal closed_inventory(inventory : Inventory)

@export_group("🗃️ Inventory Nodes")
@export_node_path("InventoryHandler") var inventory_handler_path := NodePath("InventoryHandler")
@onready var inventory_handler : InventoryHandler = get_node(inventory_handler_path)
@export_node_path("Hotbar") var hotbar_path := NodePath("Hotbar")
@onready var hotbar : Hotbar = get_node(hotbar_path)
@export_node_path("Crafter") var crafter_path := NodePath("Crafter")
@onready var crafter : Crafter = get_node(crafter_path)
@export_node_path("Interactor") var interactor_path := NodePath("Interactor")
@onready var interactor : Interactor = get_node(interactor_path)
@export_node_path var drop_parent_path := NodePath("../..");
@onready var drop_parent : Node = get_node(drop_parent_path)
@export_node_path var drop_parent_position_path := NodePath("..");
@onready var drop_parent_position : Node = get_node(drop_parent_position_path)

var opened_stations : Array[CraftStation]
var opened_inventories : Array[Inventory]


@export_group("⌨️ Inputs")
## Change mouse state based on inventory status
@export var change_mouse_state : bool = true
@export var check_inputs : bool = true
@export var toggle_inventory_input : String = "toggle_inventory"
@export var exit_inventory_and_craft_panel_input : String = "escape"
@export var toggle_craft_panel_input : String = "toggle_craft_panel"


@export_group("🫴 Interact")
@export var can_interact : bool = true
@export var raycast : RayCast3D:
	set(value):
		raycast = value
		var interactor = get_node(interactor_path)
		if interactor != null and value != null:
			interactor.raycast_path = interactor.get_path_to(value)
@export var camera_3d : Camera3D:
	set(value):
		camera_3d = value
		var interactor = get_node(interactor_path)
		if interactor != null and value != null:
			interactor.camera_path = interactor.get_path_to(value)


func _ready():
	if Engine.is_editor_hint():
		return
	inventory_handler.request_drop_obj.connect(_on_request_drop_obj.bind())
	
	# Setup for enabled/disabled mouse 🖱️😀
	if change_mouse_state:
		opened_inventory.connect(_update_opened_inventories.bind())
		closed_inventory.connect(_update_opened_inventories.bind())
		opened_station.connect(_update_opened_stations.bind())
		closed_station.connect(_update_opened_stations.bind())
		_update_opened_inventories(inventory_handler.get_inventory(0))


func _input(event : InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if check_inputs:
		hot_bar_inputs(event)
		inventory_inputs()


func _physics_process(_delta : float):
	if Engine.is_editor_hint():
		return
	if not can_interact:
		return
	interactor.try_interact()


func is_any_station_or_inventory_opened() -> bool:
	return is_open_any_station() or is_open_main_inventory()


func _update_opened_inventories(_inventory : Inventory):
	_check_inputs()


func _update_opened_stations(_craft_station : CraftStation):
	_check_inputs()


func _check_inputs():
	if is_any_station_or_inventory_opened():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func inventory_inputs():
	if Input.is_action_just_released(toggle_inventory_input):
		if not is_any_station_or_inventory_opened():
			open_main_inventory()
	
	if Input.is_action_just_released(exit_inventory_and_craft_panel_input):
		close_inventories()
		close_craft_stations()
			
	if Input.is_action_just_released(toggle_craft_panel_input):
		if not is_any_station_or_inventory_opened():
			open_main_craft_station()


#region Inventories/Handler
func move_between_inventories_at(from : Inventory, from_slot_index : int, amount : int, to : Inventory, to_slot_index : int):
	inventory_handler.move_between_inventories_at(from, from_slot_index, amount, to, to_slot_index)


func to_transaction(slot_index : int, inventory : Inventory, amount : int):
	inventory_handler.to_transaction(slot_index, inventory, amount)


func transaction_to(inventory : Inventory):
	inventory_handler.transaction_to(inventory)


func transaction_to_at(slot_index : int, inventory : Inventory, amount_to_move : int = -1):
	inventory_handler.transaction_to_at(slot_index, inventory, amount_to_move)


func pick_to_inventory(node : Node):
	inventory_handler.pick_to_inventory(node)


func add_to_inventory(item : Item, amount : int):
	inventory_handler.add_to_inventory(inventory_handler.get_inventory(0), item, amount)

func drop_transaction():
	inventory_handler.drop_transaction()


func _on_request_drop_obj(dropped_item : String, item : Item):
	var packed_scene : PackedScene = load(dropped_item)
	var node = packed_scene.instantiate()
	drop_parent.add_child(node)
	node.set("item", item)
	node.set("position", drop_parent_position.get("position"))
	node.set("rotation", drop_parent_position.get("position"))
	dropped.emit(node)
#endregion

#region Crafter
func craft(craft_station : CraftStation, recipe_index : int):
	craft_station.craft(recipe_index)

#endregion

#region Hotbar
func hot_bar_inputs(event : InputEvent):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				hotbar_previous_item()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				hotbar_next_item()
	if event is InputEventKey:
		var input_key_event = event as InputEventKey
		if event.is_pressed() and not event.is_echo():
			if input_key_event.keycode > KEY_0 and input_key_event.keycode < KEY_9:
				hotbar_change_selection(input_key_event.keycode - KEY_1)


func hotbar_change_selection(index : int):
	hotbar.change_selection(index)


func hotbar_previous_item():
	hotbar.previous_item()
	

func hotbar_next_item():
	hotbar.next_item()

#endregion

#region Open Inventories
func is_open_inventory(inventory : Inventory):
	return opened_inventories.find(inventory) != -1

func open_inventory(inventory : Inventory):
	if is_open_inventory(inventory):
		return
	add_open_inventory(inventory)


func add_open_inventory(inventory : Inventory):
	opened_inventories.append(inventory)
	opened_inventory.emit(inventory)
	if not is_open_main_inventory():
		open_main_inventory()
	
func open_main_inventory():
	open_inventory(inventory_handler.get_inventory(0))
	
	
func close_inventory(inventory : Inventory):
	if inventory_handler.inventories_path.find(inventory_handler.get_path_to(inventory)) == -1:
		inventory.get_parent().close(get_parent())
	remove_open_inventory(inventory)


func remove_open_inventory(inventory : Inventory):
	var index = opened_inventories.find(inventory)
	opened_inventories.remove_at(index)
	closed_inventory.emit(inventory)


func close_inventories():
	for index in range(opened_inventories.size() - 1, -1, -1):
		close_inventory(opened_inventories[index])


func is_open_any_inventory():
	return !opened_inventories.is_empty()
	
func is_open_main_inventory():
	return is_open_inventory(inventory_handler.get_inventory(0))
#endregion

#region Open Craft Stations
func is_open_station(station : CraftStation):
	return opened_stations.find(station) != -1


func open_station(station : CraftStation):
	if is_open_station(station):
		return
	add_open_station(station)


func add_open_station(station : CraftStation):
	opened_stations.append(station)
	opened_station.emit(station)


func close_station(station : CraftStation):
	if not is_open_station(station):
		return
	remove_open_station(station)


func remove_open_station(station : CraftStation):
	var index = opened_stations.find(station)
	opened_stations.remove_at(index)
	closed_station.emit(station)
	if crafter.get_node(crafter.main_station) != station:
		station.get_parent().close(get_parent())


func open_main_craft_station():
	open_station(crafter.get_node(crafter.main_station))


func close_craft_stations():
	for index in range(opened_stations.size() - 1, -1, -1):
		close_station(opened_stations[index])

func is_open_any_station():
	return !opened_stations.is_empty()
	
	
#endregion
