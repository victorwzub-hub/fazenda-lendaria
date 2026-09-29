local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Materials = require(Shared.Config.Materials)
local Rarities = require(Shared.Config.Rarities)
local Species = require(Shared.Config.Species)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.State)

local SELL_CONFIRM_SECONDS = 3

local function sorted(profile)
	local list = table.clone(profile.animals)
	table.sort(list, function(a, b)
		local ea, eb = Balance.isEquipped(profile, a.id), Balance.isEquipped(profile, b.id)
		if ea ~= eb then
			return ea
		end
		local pa, pb = Balance.animalProduction(a), Balance.animalProduction(b)
		if pa ~= pb then
			return pa > pb
		end
		return a.id < b.id
	end)
	return list
end

local function materialLine(profile, cost): (string, boolean)
	local parts = { "💰 " .. Format.number(cost.coins) }
	local enough = true
	for _, materialId in Materials.order do
		local need = cost.materials[materialId]
		if need then
			local have = profile.materials[materialId] or 0
			local ok = have >= need
			enough = enough and ok
			local material = Materials.byId[materialId]
			table.insert(
				parts,
				Kit.hex(
					if ok then Kit.colors.good else Kit.colors.bad,
					material.emoji .. " " .. Format.number(have) .. "/" .. Format.number(need)
				)
			)
		end
	end
	return table.concat(parts, "   "), enough
end

local function sellButton(parent: Instance, animal, ctx)
	local price = "Vender 💰 " .. Format.number(Balance.sellPrice(animal))
	local armed = false
	local button: TextButton
	button = Kit.button(price, Kit.colors.yellow, function()
		if not armed then
			armed = true
			button.Text = "Confirmar?"
			Kit.paint(button, Kit.colors.red)
			task.delay(SELL_CONFIRM_SECONDS, function()
				if armed and button.Parent then
					armed = false
					button.Text = price
					Kit.paint(button, Kit.colors.yellow)
				end
			end)
			return
		end
		armed = false
		ctx.act("Sell", animal.id)
	end, { Size = UDim2.fromOffset(150, 28), TextSize = 14, LayoutOrder = 3, Parent = parent })
end

local function buffText(animal): string
	local stat, value = Balance.buffOf(animal)
	local buff = Species.buffs[stat]
	return buff.emoji .. " +" .. value .. buff.suffix .. " " .. buff.label
end

return function(content: Frame, profile, ctx)
	local header = Kit.card(104, 0)
	header.Parent = content
	Kit.label({
		Text = "🏡 Espaços: " .. #profile.animals .. "/" .. State.capacity(),
		Font = Enum.Font.FredokaOne,
		TextSize = 21,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0.5, -14, 0, 26),
		Parent = header,
	})
	local equipped = #(profile.equipped or {})
	Kit.label({
		Text = "🐾 Pets: " .. equipped .. "/" .. Balance.petSlots(profile) .. "  •  pets andam com você e dão bônus!",
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(150, 90, 30),
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -200, 0, 32),
		Parent = header,
	})
	Kit.button("🐾 Equipar melhores", Kit.colors.blue, function()
		ctx.act("EquipBest")
	end, {
		Size = UDim2.fromOffset(176, 36),
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 60),
		Parent = header,
	})
	Kit.label({
		Text = "💰 " .. Format.rate(State.production()) .. " por segundo",
		Font = Enum.Font.FredokaOne,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromScale(0.5, 0) + UDim2.fromOffset(0, 6),
		Size = UDim2.new(0.5, -14, 0, 26),
		Parent = header,
	})
	Kit.label({
		Text = "Evolua com materiais das rotas: cada raridade produz MUITO mais moedas!",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Kit.colors.muted,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 22),
		Parent = header,
	})

	for order, animal in sorted(profile) do
		local species = Species.byId[animal.species]
		local rarity = Rarities.list[animal.rarity]
		local isPet = Balance.isEquipped(profile, animal.id)
		local card = Kit.card(116, order, if isPet then Kit.colors.blue else rarity.color)
		card.Parent = content

		Kit.label({
			Text = species.emoji,
			TextSize = 46,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.fromOffset(64, 116),
			Parent = card,
		})
		Kit.label({
			Text = (if isPet then "🐾 PET  " else "") .. buffText(animal),
			Font = Enum.Font.FredokaOne,
			TextSize = 14,
			TextColor3 = if isPet then Kit.colors.blue else Kit.colors.muted,
			Position = UDim2.fromOffset(74, 94),
			Size = UDim2.new(1, -250, 0, 18),
			Parent = card,
		})
		Kit.label({
			Text = Balance.animalName(animal),
			Font = Enum.Font.FredokaOne,
			TextSize = 22,
			TextColor3 = Kit.darken(rarity.color, 0.25),
			Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -250, 0, 26),
			Parent = card,
		})
		Kit.label({
			Text = "Produz 💰 " .. Format.rate(Balance.animalProduction(animal)) .. "/s",
			TextColor3 = Kit.colors.muted,
			TextSize = 15,
			Position = UDim2.fromOffset(74, 34),
			Size = UDim2.new(1, -250, 0, 20),
			Parent = card,
		})

		local layout = Kit.list(8)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		local buttons = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 108),
			Parent = card,
		}, { layout })
		layout.Padding = UDim.new(0, 5)
		Kit.button(if isPet then "✅ Pet (tirar)" else "🐾 Equipar", if isPet then Kit.colors.blue else Color3.fromRGB(120, 170, 70), function()
			ctx.act("Equip", animal.id)
		end, { Size = UDim2.fromOffset(150, 30), TextSize = 15, LayoutOrder = 2, Parent = buttons })

		if animal.rarity >= Rarities.MAX then
			Kit.label({
				Text = "⭐ RARIDADE MÁXIMA",
				Font = Enum.Font.FredokaOne,
				TextSize = 15,
				TextColor3 = Kit.darken(rarity.color, 0.2),
				Position = UDim2.fromOffset(74, 58),
				Size = UDim2.new(1, -250, 0, 36),
				Parent = card,
			})
		else
			local cost = Balance.evolveCost(animal.species, animal.rarity)
			if cost then
				local nextRarity = Rarities.list[animal.rarity + 1]
				local nextName = species.name .. " " .. Rarities.label(nextRarity.id, species.feminine)
				local line, materialsOk = materialLine(profile, cost)
				Kit.label({
					RichText = true,
					Text = "▶ " .. Kit.hex(Kit.darken(nextRarity.color, 0.25), nextName) .. "\n" .. line,
					TextSize = 14,
					TextYAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.fromOffset(74, 56),
					Size = UDim2.new(1, -250, 0, 44),
					Parent = card,
				})
				local evolve = Kit.button("⬆ Evoluir", Kit.colors.green, function()
					ctx.act("Evolve", animal.id)
				end, { Size = UDim2.fromOffset(150, 38), LayoutOrder = 1, Parent = buttons })
				ctx.track(evolve, if materialsOk then cost.coins else math.huge, function(affordable)
					Kit.paint(evolve, if affordable then Kit.colors.green else Kit.colors.gray)
				end)
			end
		end
		sellButton(buttons, animal, ctx)
	end
end
