extends RefCounted

const CAPACITY := 18
const IDS := ["croissant", "cookie", "cupcake", "mousse"]
var stock := {"croissant": 0, "cookie": 0, "cupcake": 0, "mousse": 0}
var reserved_id := ""
var reserved_count := 0

func total() -> int:
	var count := 0
	for id in IDS:
		count += int(stock[id])
	return count

func count_of(id: String) -> int:
	return int(stock.get(id, 0))

func free_space() -> int:
	return CAPACITY - total() - reserved_count

func can_fit(quantity: int) -> bool:
	return quantity > 0 and quantity <= free_space()

func reserve(id: String, quantity: int) -> bool:
	if id not in IDS or reserved_count > 0 or not can_fit(quantity):
		return false
	reserved_id = id
	reserved_count = quantity
	return true

func finish_batch() -> void:
	if reserved_count == 0:
		return
	stock[reserved_id] += reserved_count
	reserved_count = 0
	reserved_id = ""

func take_one(id: String) -> bool:
	if count_of(id) <= 0:
		return false
	stock[id] -= 1
	return true

func write_save(data: ConfigFile) -> void:
	for id in IDS:
		data.set_value("display", id, stock[id])
	data.set_value("production", "recipe", reserved_id)

func restore_save(data: ConfigFile) -> String:
	reserved_id = ""
	reserved_count = 0
	var free := CAPACITY
	for id in IDS:
		stock[id] = clampi(int(data.get_value("display", id, 0)), 0, free)
		free -= stock[id]
	var pending := str(data.get_value("production", "recipe", ""))
	return pending if pending in IDS else ""
