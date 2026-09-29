local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Rarities = require(Shared.Config.Rarities)
local Species = require(Shared.Config.Species)

local Kit = require(script.Parent.Parent.Kit)

return function(content: Frame, profile, _ctx)
	local total = #Species.order * Rarities.MAX
	local found = 0
	for _ in profile.index do
		found += 1
	end

	local header = Kit.card(78, 0)
	header.Parent = content
	Kit.label({
		Text = string.format("📖 Descobertos: %d/%d (%d%%)", found, total, math.floor(found / total * 100)),
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = header,
	})
	local toNext = Balance.INDEX_STEP - found % Balance.INDEX_STEP
	Kit.label({
		Text = "💰 Bônus do índice: +" .. Balance.indexBonus(profile) .. "% moedas  •  faltam " .. toNext .. " descobertas para +" .. Balance.INDEX_BONUS .. "%",
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = Kit.colors.good,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = header,
	})

	for order, speciesId in Species.order do
		local species = Species.byId[speciesId]
		local card = Kit.card(104, order)
		card.Parent = content
		Kit.label({
			Text = species.emoji .. " " .. species.name,
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -28, 0, 26),
			Parent = card,
		})

		local layout = Kit.list(6, true)
		local row = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 38),
			Size = UDim2.new(1, -16, 0, 56),
			Parent = card,
		}, { layout })

		for _, rarity in Rarities.list do
			local discovered = profile.index[speciesId .. ":" .. rarity.id] == true
			Kit.new("TextLabel", {
				BackgroundColor3 = if discovered then rarity.color else Kit.colors.gray,
				BackgroundTransparency = if discovered then 0 else 0.4,
				Size = UDim2.new(1 / Rarities.MAX, -6, 1, 0),
				LayoutOrder = rarity.id,
				Font = Enum.Font.FredokaOne,
				TextScaled = true,
				TextColor3 = Kit.colors.white,
				TextStrokeTransparency = 0.4,
				Text = if discovered then Rarities.label(rarity.id, species.feminine) else "?",
				Parent = row,
			}, { Kit.corner(10), Kit.padding(6) })
		end
	end
end
