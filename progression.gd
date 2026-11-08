extends RefCounted
const VERSION:=2
const LEVEL_XP=[0,60,180,380,680,1100,1700,2500]
const OLD_XP=[0,25,75,150]
const NEXT_TITLES=["Круассан","Печенье","Второй покупатель","Найм кассира","Сноровка персонала","Третий покупатель","Найм помощника","Больше поручений"]
const MILESTONES=[
	"Открытие кондитерской: один гость и кондитер",
	"Печенье и второй вид выпечки",
	"Второй покупатель и капкейки",
	"Открывается найм кассира и холодные десерты",
	"Скорость и сноровка персонала",
	"Третий покупатель и улучшения оборудования",
	"Рабочее место и найм помощника",
	"Организация: больше производственных поручений"
]
static func level_for_xp(xp: int) -> int:
	var level:=1
	for index in range(LEVEL_XP.size()):
		if xp>=LEVEL_XP[index]: level=index+1
	return level
static func buyers(level: int) -> int:
	return 3 if level>=6 else (2 if level>=3 else 1)
static func arrival_seconds(level: int) -> float:
	return 7.0 if level>=6 else (8.0 if level>=4 else (9.0 if level>=2 else 10.0))
static func migrate_xp(data: ConfigFile, xp: int) -> int:
	if int(data.get_value("progression","version",0))>=VERSION: return xp
	var old_level:=1
	for index in range(OLD_XP.size()):
		if xp>=OLD_XP[index]: old_level=index+1
	return int(LEVEL_XP[old_level-1])+xp-int(OLD_XP[old_level-1])
