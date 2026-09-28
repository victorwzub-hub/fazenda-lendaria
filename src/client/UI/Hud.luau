local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Routes = require(Shared.Config.Routes)
local Species = require(Shared.Config.Species)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.State)

export type MenuEntry = { emoji: string, label: string, color: Color3, onClick: () -> () }

local Hud = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local DARK = Color3.fromRGB(40, 30, 20)

local coinsLabel: TextLabel
local coinsScale: UIScale
local rateLabel: TextLabel
local luckLabel: TextLabel
local goldenFrame: Frame
local goldenLabel: TextLabel
local objectiveLabel: TextLabel

local function pill(parent: Instance, props: { [string]: any }, strokeColor: Color3): Frame
	local frame = Kit.new("Frame", {
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		Parent = parent,
	}, { Kit.corner(22), Kit.stroke(strokeColor, 3) })
	for key, value in props do
		(frame :: any)[key] = value
	end
	return frame
end

local function objective(profile): string
	if (profile.stats.collected or 0) == 0 then
		return "Entre no portal 🐔 Rota do Galinheiro (perto do poço) e colete itens"
	end
	for _, routeId in Routes.order do
		if not profile.routes[routeId] then
			local route = Routes.byId[routeId]
			local req = route.requirement
			if req and not Balance.hasAnimal(profile, req.species, req.rarity) then
				return "Evolua até ter " .. Balance.requirementText(routeId) .. " para liberar a " .. route.name
			end
			return "Libere a "
				.. route.name
				.. " por 🪙 "
				.. Format.number(route.unlockCost)
				.. " no menu 🗺️ Rotas"
		end
	end
	for _, speciesId in Species.order do
		if not Balance.hasAnimal(profile, speciesId, Rarities.LEGENDARY) then
			local species = Species.byId[speciesId]
			return "Consiga "
				.. species.emoji
				.. " "
				.. species.name
				.. " "
				.. Rarities.label(Rarities.LEGENDARY, species.feminine)
		end
	end
	return "Complete o 📖 Índice: encontre todos os animais Míticos!"
end

function Hud.mount(gui: ScreenGui, scales: { UIScale }, menu: { MenuEntry })
	local top = Kit.new("Frame", {
		Name = "Topo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(640, 120),
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = top }))

	local coins = pill(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(250, 68),
	}, GOLD)
	coinsLabel = Kit.label({
		Text = "🪙 0",
		Font = Enum.Font.FredokaOne,
		TextSize = 32,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 38),
		Parent = coins,
	})
	coinsScale = Kit.new("UIScale", { Parent = coinsLabel })
	rateLabel = Kit.label({
		Text = "+0/s",
		TextSize = 15,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = coins,
	})

	local luck = pill(top, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 135, 0, 13),
		Size = UDim2.fromOffset(130, 42),
	}, Color3.fromRGB(90, 220, 110))
	luckLabel = Kit.label({
		Text = "🍀 x1.00",
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = luck,
	})

	goldenFrame = pill(top, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -135, 0, 13),
		Size = UDim2.fromOffset(170, 42),
		BackgroundColor3 = Color3.fromRGB(120, 80, 10),
		Visible = false,
	}, GOLD)
	goldenLabel = Kit.label({
		Text = "🌟 0:00",
		Font = Enum.Font.FredokaOne,
		TextSize = 19,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = goldenFrame,
	})

	objectiveLabel = Kit.label({
		Text = "",
		TextSize = 15,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = top,
	})
	Kit.corner(15).Parent = objectiveLabel
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = objectiveLabel,
	})

	local menuLayout = Kit.list(8)
	menuLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local menuFrame = Kit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(84, #menu * 86),
		Parent = gui,
	}, { menuLayout })
	table.insert(scales, Kit.new("UIScale", { Parent = menuFrame }))

	for order, entry in menu do
		local button = Kit.button("", entry.color, entry.onClick, {
			Size = UDim2.fromOffset(80, 78),
			LayoutOrder = order,
			Parent = menuFrame,
		})
		Kit.label({
			Text = entry.emoji,
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = button,
		})
		Kit.label({
			Text = entry.label,
			Font = Enum.Font.FredokaOne,
			TextSize = 15,
			TextColor3 = Kit.colors.white,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = button,
		})
	end
end

function Hud.setCoins(value: number)
	coinsLabel.Text = "🪙 " .. Format.number(value)
	coinsScale.Scale = 1.08
	TweenService:Create(coinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Hud.tick()
	local profile = State.profile
	if profile then
		rateLabel.Text = "+" .. Format.rate(State.production()) .. " por segundo"
		luckLabel.Text = string.format("🍀 x%.2f", State.luck())
		objectiveLabel.Text = "🎯 " .. objective(profile)
	end
	local golden = State.isGoldenHour()
	goldenFrame.Visible = golden
	if golden then
		goldenLabel.Text = "🌟 Dourada " .. Format.time(State.goldenHourEnds() - Workspace:GetServerTimeNow())
	end
end

return Hud
