local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local GamePasses = require(Shared.Config.GamePasses)
local Upgrades = require(Shared.Config.Upgrades)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.State)

local priceCache: { [number]: number } = {}

local EFFECTS: { [string]: (any) -> string } = {
	Sorte = function(profile)
		return string.format("Sorte base: x%.2f", 1 + Balance.LUCK_PER_LEVEL * (profile.upgrades.Sorte or 0))
	end,
	Fazenda = function()
		return "Espaços: " .. State.capacity()
	end,
	Velocidade = function(profile)
		return "Velocidade: " .. Balance.walkSpeed(profile)
	end,
	Rede = function(profile)
		return string.format("Itens a mais: +%.2f por coleta", Balance.NET_CHANCE_PER_LEVEL * (profile.upgrades.Rede or 0))
	end,
	Cesta = function(profile)
		return "Cesta: " .. Balance.basketCapacity(profile) .. " itens"
	end,
}

local function showPrice(button: TextButton, passId: number)
	local function apply(price: number)
		if button.Parent then
			button.Text = "Comprar • " .. price .. " Robux"
		end
	end
	if priceCache[passId] then
		apply(priceCache[passId])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)
		end)
		if ok and info and info.PriceInRobux then
			priceCache[passId] = info.PriceInRobux
			apply(info.PriceInRobux)
		end
	end)
end

local function upgradeCards(content: Frame, profile, ctx, ids: { string }, firstOrder: number)
	for index, upgradeId in ids do
		local order = firstOrder + index
		local def = Upgrades.byId[upgradeId]
		local level = profile.upgrades[upgradeId] or 0
		local card = Kit.card(92, order)
		card.Parent = content
		Kit.label({
			Text = def.emoji .. " " .. def.name .. "   " .. Kit.hex(Kit.colors.muted, "Nv " .. level .. "/" .. def.max),
			RichText = true,
			Font = Enum.Font.FredokaOne,
			TextSize = 21,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -200, 0, 26),
			Parent = card,
		})
		Kit.label({
			Text = def.desc .. "\n" .. EFFECTS[upgradeId](profile),
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = Kit.colors.muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -200, 0, 44),
			Parent = card,
		})
		local buttonProps = {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(160, 48),
			Parent = card,
		}
		if level >= def.max then
			Kit.button("MÁXIMO ⭐", Kit.colors.gray, function() end, buttonProps)
		else
			local cost = Upgrades.cost(upgradeId, level)
			local buy = Kit.button("💰 " .. Format.number(cost), Kit.colors.gray, function()
				ctx.act("BuyUpgrade", upgradeId)
			end, buttonProps)
			ctx.track(buy, cost, function(affordable)
				Kit.paint(buy, if affordable then Kit.colors.green else Kit.colors.gray)
			end)
		end
	end
end

return function(content: Frame, profile, ctx)
	Kit.section("🎒 Equipamentos", 0).Parent = content
	upgradeCards(content, profile, ctx, Upgrades.equipment, 0)
	Kit.section("⚒️ Melhorias da Fazenda", 10).Parent = content
	upgradeCards(content, profile, ctx, Upgrades.farm, 10)

	Kit.section("⭐ Passes Premium", 20).Parent = content

	for order, key in GamePasses.order do
		local pass = GamePasses.byId[key]
		local owned = State.hasPass(key)
		local card = Kit.card(80, 20 + order, Kit.colors.yellow)
		card.Parent = content
		Kit.label({
			Text = pass.emoji .. " " .. pass.name,
			Font = Enum.Font.FredokaOne,
			TextSize = 21,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -220, 0, 26),
			Parent = card,
		})
		Kit.label({
			Text = pass.desc,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = Kit.colors.muted,
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -220, 0, 32),
			Parent = card,
		})
		local props = {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(190, 46),
			TextSize = 16,
			Parent = card,
		}
		if owned then
			Kit.button("✅ Ativo", Kit.colors.green, function() end, props)
		elseif pass.id <= 0 then
			Kit.button("Em breve", Kit.colors.gray, function() end, props)
		else
			local buy = Kit.button("Comprar", Kit.colors.yellow, function()
				ctx.act("BuyPass", key)
			end, props)
			showPrice(buy, pass.id)
		end
	end
end
