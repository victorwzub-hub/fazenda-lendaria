local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Materials = require(Shared.Config.Materials)

local Kit = require(script.Parent.Parent.Kit)

return function(content: Frame, profile, _ctx)
	Kit.label({
		Text = "Materiais são usados para evoluir seus animais. Itens brilhantes nas rotas são raros!",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Kit.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -8, 0, 22),
		LayoutOrder = 0,
		Parent = content,
	})

	local grid = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = content,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(142, 78),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	for order, materialId in Materials.order do
		local material = Materials.byId[materialId]
		local count = profile.materials[materialId] or 0
		local cell = Kit.new("Frame", {
			BackgroundColor3 = Kit.colors.card,
			BackgroundTransparency = if count > 0 then 0 else 0.5,
			LayoutOrder = order,
			Parent = grid,
		}, { Kit.corner(12), Kit.stroke(if material.tier >= 3 then material.color else Kit.colors.border, 2) })
		Kit.label({
			Text = material.emoji,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(0, 46, 1, -8),
			Parent = cell,
		})
		Kit.label({
			Text = material.name,
			TextSize = 13,
			Position = UDim2.fromOffset(46, 8),
			Size = UDim2.new(1, -50, 0, 32),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = cell,
		})
		Kit.label({
			Text = "x" .. Format.number(count),
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
			TextColor3 = if count > 0 then Kit.colors.text else Kit.colors.muted,
			Position = UDim2.fromOffset(46, 44),
			Size = UDim2.new(1, -50, 0, 26),
			Parent = cell,
		})
	end
end
