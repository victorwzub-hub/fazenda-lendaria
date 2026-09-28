-- tier 1-3 = comum/incomum/raro da rota; tier 4 = aparece em todas as rotas
local Materials = {}

Materials.byId = {
	Semente = { name = "Semente", emoji = "🌱", color = Color3.fromRGB(190, 145, 90), tier = 1 },
	Pena = { name = "Pena", emoji = "🕊️", color = Color3.fromRGB(245, 245, 245), tier = 2 },
	PenaDourada = { name = "Pena Dourada", emoji = "✨", color = Color3.fromRGB(255, 205, 60), tier = 3 },

	Cenoura = { name = "Cenoura", emoji = "🥕", color = Color3.fromRGB(255, 140, 40), tier = 1 },
	Abobora = { name = "Abóbora", emoji = "🎃", color = Color3.fromRGB(230, 110, 20), tier = 2 },
	Trufa = { name = "Trufa", emoji = "🍄", color = Color3.fromRGB(190, 120, 255), tier = 3 },

	Capim = { name = "Capim", emoji = "🌾", color = Color3.fromRGB(140, 200, 80), tier = 1 },
	Trevo = { name = "Trevo", emoji = "☘️", color = Color3.fromRGB(60, 170, 70), tier = 2 },
	TrevoDaSorte = { name = "Trevo de 4 Folhas", emoji = "🍀", color = Color3.fromRGB(80, 255, 120), tier = 3 },

	Feno = { name = "Feno", emoji = "🌾", color = Color3.fromRGB(230, 200, 100), tier = 1 },
	Maca = { name = "Maçã", emoji = "🍎", color = Color3.fromRGB(225, 50, 50), tier = 2 },
	FerraduraDourada = { name = "Ferradura Dourada", emoji = "🧲", color = Color3.fromRGB(255, 215, 80), tier = 3 },

	CristalEstelar = { name = "Cristal Estelar", emoji = "💎", color = Color3.fromRGB(90, 230, 255), tier = 4 },
}

Materials.order = {
	"Semente",
	"Pena",
	"PenaDourada",
	"Cenoura",
	"Abobora",
	"Trufa",
	"Capim",
	"Trevo",
	"TrevoDaSorte",
	"Feno",
	"Maca",
	"FerraduraDourada",
	"CristalEstelar",
}

return Materials
