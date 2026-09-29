local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local GamePasses = require(Shared.Config.GamePasses)
local Upgrades = require(Shared.Config.Upgrades)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.State)

local priceCache: { [number]: number } = {}

-- Cada efeito devolve (nome, valor) para mostrar "agora → depois de comprar".
local EFFECTS: { [string]: (any) -> (string, string) } = {
	Sorte = function(profile)
		return "Sorte", string.format("x%.2f", 1 + Balance.LUCK_PER_LEVEL * (profile.upgrades.Sorte or 0))
	end,
	Fazenda = function(profile)
		return "Espaços", tostring(Balance.capacity(profile, State.hasPass("FazendaGigante")))
	end,
	Velocidade = function(profile)
		return "Velocidade", "⚡" .. Balance.walkSpeed(profile)
	end,
	Pulo = function(profile)
		return "Pulos seguidos", (1 + Balance.extraJumps(profile)) .. " (altura " .. string.format("%.1f", Balance.jumpHeight(profile)) .. ")"
	end,
	Rede = function(profile)
		return "Itens a mais", string.format("+%.1f por coleta", Balance.NET_CHANCE_PER_LEVEL * (profile.upgrades.Rede or 0))
	end,
	Cesta = function(profile)
		return "Cesta", Balance.basketCapacity(profile) .. " itens"
	end,
	Esteira = function(profile)
		return "Treino", "+" .. Balance.trainGain(profile) .. "/s"
	end,
}

-- Perfil de mentira com um nível a mais, para calcular o "depois".
local function withLevel(profile, upgradeId: string, level: number)
	local upgrades = table.clone(profile.upgrades)
	upgrades[upgradeId] = level
	return setmetatable({ upgrades = upgrades }, { __index = profile })
end

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
		local label, now = EFFECTS[upgradeId](profile)
		local effect = label .. ": " .. now
		if level < def.max then
			local _, after = EFFECTS[upgradeId](withLevel(profile, upgradeId, level + 1))
			effect = label .. ": " .. now .. "  →  " .. Kit.hex(Kit.colors.good, "<b>" .. after .. "</b>")
		end
		Kit.label({
			Text = def.desc .. "\n" .. effect,
			RichText = true,
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
		-- Item que a missão atual pede ganha destaque.
		if Players.LocalPlayer:GetAttribute("MissaoUpgrade") == upgradeId and level < def.max then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Kit.colors.yellow
				stroke.Thickness = 4
			end
			Kit.label({
				Text = "⭐ MISSÃO",
				Font = Enum.Font.FredokaOne,
				TextSize = 15,
				TextColor3 = Color3.fromRGB(200, 120, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 2),
				Size = UDim2.fromOffset(160, 18),
				Parent = card,
			})
		end
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

local REBIRTH_CONFIRM_SECONDS = 4
local PURPLE = Color3.fromRGB(165, 95, 225)

-- Cartão do Renascer: o que ganha, o que perde e o botão (clique duas vezes para confirmar).
local function rebirthCard(content: Frame, profile, ctx)
	local rebirths = profile.rebirths or 0
	local card = Kit.card(150, -1, PURPLE)
	card.Parent = content
	Kit.label({
		Text = "♻️ RENASCER" .. (if rebirths > 0 then "  " .. Kit.hex(Kit.colors.muted, "(já renasceu " .. rebirths .. "x)") else ""),
		RichText = true,
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -200, 0, 28),
		Parent = card,
	})
	local nextCoins = 1 + Balance.REBIRTH_COIN_BONUS * (rebirths + 1)
	local nextLuck = 1 + Balance.REBIRTH_LUCK_BONUS * (rebirths + 1)
	local nextSlots = Balance.PET_SLOTS + math.min(rebirths + 1, Balance.REBIRTH_MAX_SLOTS)
	Kit.label({
		RichText = true,
		Text = Kit.hex(Kit.colors.good, string.format("<b>Ganha para sempre:</b> 💰 x%.1f moedas • 🍀 x%.1f sorte • 🐾 %d pets", nextCoins, nextLuck, nextSlots))
			.. "\n" .. Kit.hex(Kit.colors.bad, "<b>Recomeça:</b> moedas, materiais, melhorias, treino, rotas e bichos que não são pets")
			.. "\nFica com: 🐾 pets equipados, 🥚 ovos, 📖 índice",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Kit.colors.muted,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -200, 0, 100),
		Parent = card,
	})
	local cost = Balance.rebirthCost(profile)
	local needsRoute = not profile.routes[Balance.REBIRTH_ROUTE]
	local label = if needsRoute then "🔒 Libere o Pasto" else "♻️ 💰 " .. Format.number(cost)
	local armed = false
	local button: TextButton
	button = Kit.button(label, Kit.colors.gray, function()
		if needsRoute then
			return
		end
		if not armed then
			armed = true
			button.Text = "Tem certeza? ♻️"
			Kit.paint(button, Kit.colors.red)
			task.delay(REBIRTH_CONFIRM_SECONDS, function()
				if armed and button.Parent then
					armed = false
					button.Text = label
					Kit.paint(button, Kit.colors.gray)
				end
			end)
			return
		end
		armed = false
		ctx.act("Rebirth")
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(170, 52),
		TextSize = 17,
		Parent = card,
	})
	ctx.track(button, if needsRoute then math.huge else cost, function(affordable)
		if not armed then
			Kit.paint(button, if affordable then PURPLE else Kit.colors.gray)
		end
	end)
end

return function(content: Frame, profile, ctx)
	rebirthCard(content, profile, ctx)
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
