local Rarities = {}

Rarities.list = {
	{ id = 1, name = "Comum", nameF = "Comum", color = Color3.fromRGB(205, 205, 205), mult = 1, weight = 70 },
	{ id = 2, name = "Incomum", nameF = "Incomum", color = Color3.fromRGB(90, 205, 95), mult = 2.5, weight = 22 },
	{ id = 3, name = "Raro", nameF = "Rara", color = Color3.fromRGB(70, 145, 255), mult = 6, weight = 6 },
	{ id = 4, name = "Épico", nameF = "Épica", color = Color3.fromRGB(175, 90, 255), mult = 15, weight = 1.7 },
	{ id = 5, name = "Lendário", nameF = "Lendária", color = Color3.fromRGB(255, 190, 40), mult = 40, weight = 0.29 },
	{ id = 6, name = "Mítico", nameF = "Mítica", color = Color3.fromRGB(255, 70, 125), mult = 100, weight = 0.01 },
}

Rarities.MAX = #Rarities.list
Rarities.LEGENDARY = 5

function Rarities.label(id: number, feminine: boolean?): string
	local rarity = Rarities.list[id]
	return if feminine then rarity.nameF else rarity.name
end

return Rarities
