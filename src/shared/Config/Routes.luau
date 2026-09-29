-- Cada rota é uma ilha separada. Nós de coleta nascem aleatoriamente; "nest" é um ninho que dá um animal.
local Routes = {}

Routes.byId = {
	Galinheiro = {
		id = "Galinheiro",
		name = "Rota do Galinheiro",
		species = "Galinha",
		origin = Vector3.new(2500, 0, 0),
		size = 260,
		-- Bioma: fazenda verde.
		ground = Color3.fromRGB(118, 214, 82),
		groundDark = Color3.fromRGB(88, 180, 62),
		groundMaterial = Enum.Material.Grass,
		foliage = Color3.fromRGB(95, 165, 70),
		tint = Color3.fromRGB(255, 255, 255),
		theme = Color3.fromRGB(220, 70, 55),
		requirement = nil,
		unlockCost = 0,
		nodeCount = 34,
		nodes = {
			{ material = "Semente", weight = 60, min = 1, max = 3 },
			{ material = "Pena", weight = 28, min = 1, max = 2 },
			{ material = "PenaDourada", weight = 7, min = 1, max = 1 },
			{ material = "CristalEstelar", weight = 0.6, min = 1, max = 1 },
			{ nest = true, weight = 4.4 },
		},
	},
	Chiqueiro = {
		id = "Chiqueiro",
		name = "Rota do Chiqueiro",
		species = "Porco",
		origin = Vector3.new(5000, 0, 0),
		size = 280,
		-- Bioma: lamaçal.
		ground = Color3.fromRGB(170, 125, 82),
		groundDark = Color3.fromRGB(135, 96, 62),
		groundMaterial = Enum.Material.Ground,
		foliage = Color3.fromRGB(110, 150, 60),
		tint = Color3.fromRGB(255, 236, 214),
		theme = Color3.fromRGB(255, 130, 160),
		requirement = { species = "Galinha", rarity = 3 },
		unlockCost = 500,
		nodeCount = 36,
		nodes = {
			{ material = "Cenoura", weight = 60, min = 1, max = 3 },
			{ material = "Abobora", weight = 28, min = 1, max = 2 },
			{ material = "Trufa", weight = 7, min = 1, max = 1 },
			{ material = "CristalEstelar", weight = 0.7, min = 1, max = 1 },
			{ nest = true, weight = 4.3 },
		},
	},
	Pasto = {
		id = "Pasto",
		name = "Rota do Pasto",
		species = "Vaca",
		origin = Vector3.new(7500, 0, 0),
		size = 300,
		-- Bioma: campo florido.
		ground = Color3.fromRGB(150, 232, 120),
		groundDark = Color3.fromRGB(112, 200, 96),
		groundMaterial = Enum.Material.LeafyGrass,
		foliage = Color3.fromRGB(60, 150, 70),
		tint = Color3.fromRGB(236, 255, 242),
		theme = Color3.fromRGB(70, 130, 230),
		requirement = { species = "Porco", rarity = 3 },
		unlockCost = 15000,
		nodeCount = 38,
		nodes = {
			{ material = "Capim", weight = 60, min = 1, max = 3 },
			{ material = "Trevo", weight = 28, min = 1, max = 2 },
			{ material = "TrevoDaSorte", weight = 7, min = 1, max = 1 },
			{ material = "CristalEstelar", weight = 0.8, min = 1, max = 1 },
			{ nest = true, weight = 4.2 },
		},
	},
	Pradaria = {
		id = "Pradaria",
		name = "Rota da Pradaria",
		species = "Cavalo",
		origin = Vector3.new(10000, 0, 0),
		size = 320,
		-- Bioma: savana dourada.
		ground = Color3.fromRGB(232, 206, 112),
		groundDark = Color3.fromRGB(205, 176, 88),
		groundMaterial = Enum.Material.Grass,
		foliage = Color3.fromRGB(165, 160, 60),
		tint = Color3.fromRGB(255, 240, 205),
		theme = Color3.fromRGB(255, 190, 40),
		requirement = { species = "Vaca", rarity = 4 },
		unlockCost = 250000,
		nodeCount = 40,
		nodes = {
			{ material = "Feno", weight = 60, min = 1, max = 3 },
			{ material = "Maca", weight = 28, min = 1, max = 2 },
			{ material = "FerraduraDourada", weight = 7, min = 1, max = 1 },
			{ material = "CristalEstelar", weight = 1, min = 1, max = 1 },
			{ nest = true, weight = 4 },
		},
	},
}

Routes.order = { "Galinheiro", "Chiqueiro", "Pasto", "Pradaria" }

return Routes
