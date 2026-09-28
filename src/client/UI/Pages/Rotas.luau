local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Materials = require(Shared.Config.Materials)
local Routes = require(Shared.Config.Routes)
local Species = require(Shared.Config.Species)

local Kit = require(script.Parent.Parent.Kit)

return function(content: Frame, profile, ctx)
	Kit.button("🏡 Voltar para a minha fazenda", Kit.colors.green, function()
		local ok = ctx.act("Travel", "Fazenda")
		if ok then
			ctx.close()
		end
	end, { Size = UDim2.new(1, -8, 0, 46), TextSize = 20, LayoutOrder = 0, Parent = content })

	for order, routeId in Routes.order do
		local route = Routes.byId[routeId]
		local species = Species.byId[route.species]
		local unlocked = profile.routes[routeId] == true
		local card = Kit.card(118, order, if unlocked then route.theme else Kit.colors.gray)
		card.Parent = content

		local materialNames = {}
		for _, materialId in species.materials do
			local material = Materials.byId[materialId]
			table.insert(materialNames, material.emoji .. " " .. material.name)
		end

		Kit.label({
			Text = species.emoji .. " " .. route.name,
			Font = Enum.Font.FredokaOne,
			TextSize = 23,
			TextColor3 = Kit.darken(route.theme, 0.3),
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -200, 0, 28),
			Parent = card,
		})
		Kit.label({
			Text = table.concat(materialNames, "  •  ")
				.. "\n🥚 Ninhos de "
				.. species.name
				.. "  •  💎 Cristal Estelar (raro)",
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = Kit.colors.muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -200, 0, 40),
			Parent = card,
		})

		if unlocked then
			Kit.button("Ir agora ➜", route.theme, function()
				local ok = ctx.act("Travel", routeId)
				if ok then
					ctx.close()
				end
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(160, 50),
				TextSize = 21,
				Parent = card,
			})
		else
			local req = route.requirement
			local hasReq = req == nil or Balance.hasAnimal(profile, req.species, req.rarity)
			Kit.label({
				RichText = true,
				Text = Kit.hex(
					if hasReq then Kit.colors.good else Kit.colors.bad,
					(if hasReq then "✔ " else "✖ ") .. Balance.requirementText(routeId)
				),
				TextSize = 14,
				Position = UDim2.fromOffset(14, 84),
				Size = UDim2.new(1, -200, 0, 24),
				Parent = card,
			})
			local unlock = Kit.button("🔓 🪙 " .. Format.number(route.unlockCost), Kit.colors.gray, function()
				ctx.act("UnlockRoute", routeId)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(160, 50),
				TextSize = 19,
				Parent = card,
			})
			ctx.track(unlock, if hasReq then route.unlockCost else math.huge, function(affordable)
				Kit.paint(unlock, if affordable then Kit.colors.blue else Kit.colors.gray)
			end)
		end
	end
end
