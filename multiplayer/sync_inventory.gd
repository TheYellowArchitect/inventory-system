class_name SyncInventory
extends Node

@export var sync_item_added_signal := true
@export var sync_item_removed_signal := true

@export var inventory : Inventory

## Networked version of inventory where server sends rpcs to client for 
## slot update, add and remove signals
## 
## Why not use [MultiplayerSyncronizer]?
## The idea of using rpc signals only when changed saves a lot of bandwidth, 
## but at the cost of being sure which signals will be called, ie calling 
## slot[i] = new Dictionary is not replicated across the network.
## Also keep in mind that signals need to be handled if switching to a use of
## MultiplayerSyncronizer
##
## Note: Slot categories are not synced

var slots_sync : Array:
	set(value):
		slots_sync = value
		if not multiplayer.is_server():
			for i in range(slots_sync.size(), inventory.slots.size()):
				inventory.slots.remove_at(i)
			for i in slots_sync.size():
				if i >= inventory.slots.size():
					var slot = Slot.new()
					slot.item = Item.new()
					inventory.slots.append(slot)
				inventory.slots[i].amount = slots_sync[i].amount
				var item = inventory.database.get_item(slots_sync[i].item_id)
				inventory.slots[i].item.definition = item


func _ready():
	if Engine.is_editor_hint():
		return
	multiplayer.peer_connected.connect(_on_connected.bind())
	if(inventory != null):
		setup()

func setup():
	inventory.slot_added.connect(_on_slot_added.bind())
	inventory.updated_slot.connect(_on_updated_slot.bind())
	inventory.slot_removed.connect(_on_slot_removed.bind())
	if sync_item_added_signal:
		inventory.item_added.connect(_on_item_added.bind())
	if sync_item_removed_signal:
		inventory.item_removed.connect(_on_item_removed.bind())
	slots_sync.clear()
	for i in inventory.slots.size():
		var slot = inventory.slots[i]
		slots_sync.append({"item_id" = slot.get_item_id() , "amount" = slot.amount})
	

func _on_connected(id):
	if not multiplayer.is_server():
		return
	slots_sync.clear()
	for i in inventory.slots.size():
		var slot = inventory.slots[i]
		slots_sync.append({"item_id" = slot.get_item_id() , "amount" = slot.amount})
	_update_slots_rpc.rpc_id(id, slots_sync)


func _on_slot_added(slot_index : int):
	if not multiplayer.is_server():
		return
	var slot = inventory.slots[slot_index]
	var slot_dict = {"item_id" = ItemDefinition.NONE , "amount" = 0}
	slots_sync.append(slot_dict)
	_slot_added_rpc.rpc(slot_index)


func _on_updated_slot(slot_index : int):
	if not multiplayer.is_server():
		return
	var item : Item = inventory.slots[slot_index].item
	var item_id : int
	if item.definition == null:
		item_id = ItemDefinition.NONE
	else:
		item_id = item.definition.id
	var amount = inventory.slots[slot_index].amount
	slots_sync[slot_index]["item_id"] = item_id
	slots_sync[slot_index]["amount"] = amount
	slots_sync[slot_index]["properties"] = item.properties
	_updated_slot_rpc.rpc(slot_index, item_id, amount, item.properties)


func _on_slot_removed(slot_index : int):
	if not multiplayer.is_server():
		return
	slots_sync.remove_at(slot_index)
	_slot_removed_rpc.rpc(slot_index)


func _on_item_added(item : Item, amount : int):
	if not multiplayer.is_server():
		return
	_item_added_rpc.rpc(item.definition.id, amount)


func _on_item_removed(definition : ItemDefinition, amount : int):
	if not multiplayer.is_server():
		return
	_item_removed_rpc.rpc(definition.id, amount)


@rpc
func _update_slots_rpc(slots_sync : Array):
	self.slots_sync = slots_sync


@rpc
func _slot_added_rpc(slot_index : int):
	if multiplayer.is_server():
		return
	inventory.add_slot(slot_index)


@rpc
func _updated_slot_rpc(slot_index : int, item_id : int, amount : int, properties : Dictionary):
	if multiplayer.is_server():
		return
	var item : ItemDefinition = inventory.get_item_from_id(item_id)
	inventory.set_slot_content(slot_index, item, properties, amount)


@rpc
func _slot_removed_rpc(slot_index : int):
	if multiplayer.is_server():
		return
	inventory.remove_slot(slot_index)


@rpc
func _item_added_rpc(item_id : int, amount : int):
	if multiplayer.is_server():
		return
	var item = Item.new()
	item.definition = inventory.database.get_item(item_id)
	if item.definition == null:
		return
	inventory.item_added.emit(item, amount)


@rpc
func _item_removed_rpc(item_id : int, amount : int):
	if multiplayer.is_server():
		return
	var definition : ItemDefinition = inventory.database.get_item(item_id)
	if definition == null:
		return
	inventory.item_removed.emit(definition, amount)
