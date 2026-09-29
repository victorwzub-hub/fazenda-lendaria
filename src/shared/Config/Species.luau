-- base = moedas por segundo de um animal Comum. materials = {comum, incomum, raro} usados na evolução
-- (todos os bichos de uma rota usam os materiais dela).
-- buff = bônus que o bicho dá quando está equipado como pet (ver Balance.petBonus):
--   Velocidade (+⚡), Sorte (+%), Cesta (+itens), Moedas (+%), Treino (+%).
-- route/chance = em qual rota o ninho pode dar esse bicho e com que peso.
local Species = {}

local ROUTE_MATERIALS = {
	Galinheiro = { "Semente", "Pena", "PenaDourada" },
	Chiqueiro = { "Cenoura", "Abobora", "Trufa" },
	Pasto = { "Capim", "Trevo", "TrevoDaSorte" },
	Pradaria = { "Feno", "Maca", "FerraduraDourada" },
}

Species.byId = {
	Galinha = {
		name = "Galinha",
		feminine = true,
		emoji = "🐔",
		base = 1,
		shape = "ave",
		route = "Galinheiro",
		chance = 60,
		buff = { stat = "Moedas", amount = 5 },
		palette = {
			body = Color3.fromRGB(248, 246, 238),
			accent = Color3.fromRGB(228, 222, 208),
			beak = Color3.fromRGB(255, 170, 40),
			red = Color3.fromRGB(225, 45, 45),
		},
	},
	Pato = {
		name = "Pato",
		feminine = false,
		emoji = "🦆",
		base = 1.5,
		shape = "pato",
		route = "Galinheiro",
		chance = 30,
		buff = { stat = "Velocidade", amount = 1 },
		palette = {
			body = Color3.fromRGB(250, 250, 244),
			accent = Color3.fromRGB(215, 222, 230),
			head = Color3.fromRGB(45, 145, 80),
			beak = Color3.fromRGB(255, 165, 35),
		},
	},
	Peru = {
		name = "Peru",
		feminine = false,
		emoji = "🦃",
		base = 2.5,
		shape = "peru",
		route = "Galinheiro",
		chance = 10,
		buff = { stat = "Sorte", amount = 5 },
		palette = {
			body = Color3.fromRGB(125, 82, 50),
			accent = Color3.fromRGB(170, 115, 65),
			tip = Color3.fromRGB(240, 215, 150),
			skin = Color3.fromRGB(215, 95, 95),
			beak = Color3.fromRGB(235, 195, 125),
			red = Color3.fromRGB(220, 40, 40),
		},
	},
	Porco = {
		name = "Porco",
		feminine = false,
		emoji = "🐷",
		base = 6,
		shape = "porco",
		route = "Chiqueiro",
		chance = 60,
		buff = { stat = "Cesta", amount = 4 },
		palette = {
			body = Color3.fromRGB(255, 172, 188),
			accent = Color3.fromRGB(238, 128, 152),
		},
	},
	Javali = {
		name = "Javali",
		feminine = false,
		emoji = "🐗",
		base = 9,
		shape = "javali",
		route = "Chiqueiro",
		chance = 30,
		buff = { stat = "Velocidade", amount = 1.5 },
		palette = {
			body = Color3.fromRGB(118, 82, 56),
			accent = Color3.fromRGB(62, 42, 30),
			muzzle = Color3.fromRGB(96, 66, 46),
			nose = Color3.fromRGB(60, 40, 40),
			tusk = Color3.fromRGB(250, 245, 230),
		},
	},
	Bode = {
		name = "Bode",
		feminine = false,
		emoji = "🐐",
		base = 13,
		shape = "bode",
		route = "Chiqueiro",
		chance = 10,
		buff = { stat = "Treino", amount = 10 },
		palette = {
			body = Color3.fromRGB(238, 232, 215),
			accent = Color3.fromRGB(125, 98, 72),
			muzzle = Color3.fromRGB(215, 195, 180),
			horn = Color3.fromRGB(165, 152, 130),
		},
	},
	Vaca = {
		name = "Vaca",
		feminine = true,
		emoji = "🐮",
		base = 35,
		shape = "vaca",
		route = "Pasto",
		chance = 60,
		buff = { stat = "Moedas", amount = 8 },
		palette = {
			body = Color3.fromRGB(246, 246, 246),
			accent = Color3.fromRGB(35, 35, 35),
			muzzle = Color3.fromRGB(255, 180, 190),
			horn = Color3.fromRGB(240, 230, 200),
			bell = Color3.fromRGB(255, 200, 50),
		},
	},
	Ovelha = {
		name = "Ovelha",
		feminine = true,
		emoji = "🐑",
		base = 50,
		shape = "ovelha",
		route = "Pasto",
		chance = 30,
		buff = { stat = "Sorte", amount = 8 },
		palette = {
			body = Color3.fromRGB(252, 252, 246),
			accent = Color3.fromRGB(70, 64, 64),
			eye = Color3.fromRGB(245, 245, 245),
		},
	},
	Coelho = {
		name = "Coelho",
		feminine = false,
		emoji = "🐰",
		base = 75,
		shape = "coelho",
		route = "Pasto",
		chance = 10,
		buff = { stat = "Velocidade", amount = 2 },
		palette = {
			body = Color3.fromRGB(205, 180, 152),
			accent = Color3.fromRGB(255, 170, 190),
			tail = Color3.fromRGB(252, 252, 252),
		},
	},
	Cavalo = {
		name = "Cavalo",
		feminine = false,
		emoji = "🐴",
		base = 200,
		shape = "cavalo",
		route = "Pradaria",
		chance = 60,
		buff = { stat = "Velocidade", amount = 3 },
		palette = {
			body = Color3.fromRGB(150, 98, 55),
			accent = Color3.fromRGB(60, 40, 25),
			hoof = Color3.fromRGB(45, 40, 38),
		},
	},
	Burro = {
		name = "Burro",
		feminine = false,
		emoji = "🫏",
		base = 290,
		shape = "burro",
		route = "Pradaria",
		chance = 30,
		buff = { stat = "Cesta", amount = 12 },
		palette = {
			body = Color3.fromRGB(150, 145, 140),
			accent = Color3.fromRGB(80, 75, 72),
			muzzle = Color3.fromRGB(235, 230, 225),
			hoof = Color3.fromRGB(50, 45, 45),
		},
	},
	Alpaca = {
		name = "Alpaca",
		feminine = true,
		emoji = "🦙",
		base = 420,
		shape = "alpaca",
		route = "Pradaria",
		chance = 10,
		buff = { stat = "Treino", amount = 25 },
		palette = {
			body = Color3.fromRGB(242, 226, 192),
			accent = Color3.fromRGB(135, 92, 62),
			muzzle = Color3.fromRGB(218, 192, 160),
		},
	},
}

Species.order = {
	"Galinha",
	"Pato",
	"Peru",
	"Porco",
	"Javali",
	"Bode",
	"Vaca",
	"Ovelha",
	"Coelho",
	"Cavalo",
	"Burro",
	"Alpaca",
}

-- Bichos de cada rota, na ordem (o primeiro é o "principal", usado nos requisitos de rota).
Species.byRoute = {} :: { [string]: { string } }

for _, id in Species.order do
	local species = Species.byId[id]
	species.id = id
	species.materials = ROUTE_MATERIALS[species.route]
	Species.byRoute[species.route] = Species.byRoute[species.route] or {}
	table.insert(Species.byRoute[species.route], id)
end

-- Sorteia qual bicho sai de um ninho da rota (roll entre 0 e 1).
function Species.roll(routeId: string, roll: number): string
	local list = Species.byRoute[routeId]
	local total = 0
	for _, id in list do
		total += Species.byId[id].chance
	end
	local cursor = roll * total
	for _, id in list do
		cursor -= Species.byId[id].chance
		if cursor <= 0 then
			return id
		end
	end
	return list[#list]
end

-- Nome e emoji de cada bônus de pet.
Species.buffs = {
	Velocidade = { emoji = "⚡", label = "velocidade", suffix = "" },
	Sorte = { emoji = "🍀", label = "sorte", suffix = "%" },
	Cesta = { emoji = "🧺", label = "cesta", suffix = "" },
	Moedas = { emoji = "💰", label = "moedas", suffix = "%" },
	Treino = { emoji = "🏃", label = "treino", suffix = "%" },
}
Species.buffOrder = { "Velocidade", "Sorte", "Moedas", "Cesta", "Treino" }

return Species
