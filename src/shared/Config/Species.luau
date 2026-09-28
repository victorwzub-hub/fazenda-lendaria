-- base = moedas por segundo de um animal Comum. materials = {comum, incomum, raro} usados na evolução.
local Species = {}

Species.byId = {
	Galinha = {
		id = "Galinha",
		name = "Galinha",
		feminine = true,
		emoji = "🐔",
		base = 1,
		shape = "ave",
		materials = { "Semente", "Pena", "PenaDourada" },
		palette = {
			body = Color3.fromRGB(248, 246, 238),
			accent = Color3.fromRGB(228, 222, 208),
			beak = Color3.fromRGB(255, 170, 40),
			red = Color3.fromRGB(225, 45, 45),
		},
	},
	Porco = {
		id = "Porco",
		name = "Porco",
		feminine = false,
		emoji = "🐷",
		base = 6,
		shape = "porco",
		materials = { "Cenoura", "Abobora", "Trufa" },
		palette = {
			body = Color3.fromRGB(255, 172, 188),
			accent = Color3.fromRGB(238, 128, 152),
		},
	},
	Vaca = {
		id = "Vaca",
		name = "Vaca",
		feminine = true,
		emoji = "🐮",
		base = 35,
		shape = "vaca",
		materials = { "Capim", "Trevo", "TrevoDaSorte" },
		palette = {
			body = Color3.fromRGB(246, 246, 246),
			accent = Color3.fromRGB(35, 35, 35),
			muzzle = Color3.fromRGB(255, 180, 190),
			horn = Color3.fromRGB(240, 230, 200),
			bell = Color3.fromRGB(255, 200, 50),
		},
	},
	Cavalo = {
		id = "Cavalo",
		name = "Cavalo",
		feminine = false,
		emoji = "🐴",
		base = 200,
		shape = "cavalo",
		materials = { "Feno", "Maca", "FerraduraDourada" },
		palette = {
			body = Color3.fromRGB(150, 98, 55),
			accent = Color3.fromRGB(60, 40, 25),
			hoof = Color3.fromRGB(45, 40, 38),
		},
	},
}

Species.order = { "Galinha", "Porco", "Vaca", "Cavalo" }

return Species
