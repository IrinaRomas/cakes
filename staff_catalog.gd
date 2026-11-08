extends RefCounted
const ROLES=[
	{"id":"chef","title":"Кондитер","level":1,"requires":[],"description":"Готовит партии. Пока кассир не нанят, сам принимает и выдаёт заказы."},
	{"id":"cashier","title":"Кассир","level":4,"requires":["register"],"description":"Принимает заказы и выдаёт десерты, освобождая кондитера для производства. Найм бесплатный."},
	{"id":"assistant","title":"Помощник кондитера","level":7,"requires":["assistant_station"],"description":"Параллельно подготавливает следующий поднос. Нужен купленный рабочий стол; найм бесплатный."}
]
static func role(id: String) -> Dictionary:
	for entry in ROLES:
		if entry.id==id: return entry
	return {}
