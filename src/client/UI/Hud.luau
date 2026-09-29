local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)
local Style = require(Shared.Style)

local Kit = require(script.Parent.Kit)
local SpeedMods = require(script.Parent.Parent.SpeedMods)
local State = require(script.Parent.Parent.State)

export type MenuEntry = { id: string, emoji: string, label: string, color: Color3, onClick: () -> () }

local Hud = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local MONEY = Color3.fromRGB(95, 235, 70)
local BUTTON_SIZE = Vector2.new(196, 62)

local coinsLabel: TextLabel
local coinsScale: UIScale
local rateLabel: TextLabel
local luckLabel: TextLabel
local basketLabel: TextLabel
local basketScale: UIScale
local boostLabels: { [string]: TextLabel } = {}
local speedLabel: TextLabel
local speedScale: UIScale
local petLabel: TextLabel

-- Texto ao lado da velocidade quando o terreno muda ela.
local TERRAIN_TEXT = {
	lama = "  🟫 lama: lento",
	escorrega = "  🛝 escorregando x1.8",
	arvore = "  🌳 máx ⚡20",
}

-- Boosts ativos (mesmos ids do BoostService no servidor).
local BOOSTS = {
	{ id = "Velocidade", emoji = "👟", color = Color3.fromRGB(80, 200, 255) },
	{ id = "Ima", emoji = "🧲", color = Color3.fromRGB(255, 90, 100) },
	{ id = "Escudo", emoji = "🛡️", color = Color3.fromRGB(255, 215, 70) },
}
local goldenFrame: Frame
local goldenLabel: TextLabel
local objectiveLabel: TextLabel
local objectiveScale: UIScale

type MenuButton = { button: TextButton, pointer: TextLabel, badge: Frame }
local buttons: { [string]: MenuButton } = {}
local pointed: string? = nil

-- Texto grande com contorno preto, o "jeito simulador" de escrever.
local function bigText(props: { [string]: any }, outline: number?): TextLabel
	local label = Kit.label(props)
	label.Font = Enum.Font.FredokaOne
	label.TextWrapped = false
	Style.outline(label, outline or 3)
	return label
end

local function menuButton(parent: Instance, entry: MenuEntry, order: number): MenuButton
	local button = Kit.button("", entry.color, entry.onClick, {
		Name = entry.id,
		Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
		LayoutOrder = order,
		Parent = parent,
	})
	-- Botão "gordinho": claro em cima, escuro embaixo, borda escura grossa.
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 3.5
		stroke.Color = Kit.darken(entry.color, 0.55)
	end
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175)),
		Rotation = 90,
		Parent = button,
	})
	Kit.label({
		Text = entry.emoji,
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(0, 52, 1, 0),
		Parent = button,
	})
	bigText({
		Text = entry.label,
		TextSize = 30,
		TextColor3 = Kit.colors.white,
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Parent = button,
	}, 2.5)

	local badge = Kit.new("Frame", {
		BackgroundColor3 = Kit.colors.red,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(30, 30),
		Visible = false,
		ZIndex = 3,
		Parent = button,
	}, { Kit.corner(15), Kit.stroke(Color3.new(1, 1, 1), 2.5) })
	bigText({
		Text = "!",
		TextSize = 24,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = badge,
	}, 2)

	local pointer = bigText({
		Text = "◀",
		TextSize = 44,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		Visible = false,
		Parent = button,
	}, 3)

	return { button = button, pointer = pointer, badge = badge }
end

function Hud.mount(gui: ScreenGui, scales: { UIScale }, menu: { MenuEntry })
	-- Topo: objetivo em letras grandes, como "Quebre um ovo".
	local top = Kit.new("Frame", {
		Name = "Topo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(760, 130),
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = top }))

	objectiveLabel = bigText({
		Text = "",
		TextSize = 44,
		TextColor3 = Kit.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Color3.fromRGB(20, 12, 8),
		BackgroundTransparency = 0.55,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = top,
	}, 4)
	Kit.corner(14).Parent = objectiveLabel
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 26),
		PaddingRight = UDim.new(0, 26),
		Parent = objectiveLabel,
	})
	objectiveScale = Kit.new("UIScale", { Parent = objectiveLabel })

	goldenFrame = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(120, 80, 10),
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(380, 76),
		Size = UDim2.fromOffset(260, 44),
		Visible = false,
		Parent = top,
	}, { Kit.corner(22), Kit.stroke(GOLD, 3) })
	goldenLabel = bigText({
		Text = "🌟 0:00",
		TextSize = 26,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = goldenFrame,
	}, 2.5)

	-- Esquerda: botões grandes com ícone e nome.
	local menuLayout = Kit.list(10)
	menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	menuLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local menuFrame = Kit.new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, -20),
		Size = UDim2.fromOffset(BUTTON_SIZE.X + 70, #menu * (BUTTON_SIZE.Y + 10)),
		Parent = gui,
	}, { menuLayout })
	table.insert(scales, Kit.new("UIScale", { Parent = menuFrame }))
	for order, entry in menu do
		buttons[entry.id] = menuButton(menuFrame, entry, order)
	end

	-- Canto de baixo: dinheiro enorme e verde.
	local money = Kit.new("Frame", {
		Name = "Dinheiro",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.fromOffset(420, 112),
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = money }))
	rateLabel = bigText({
		Text = "+0/s",
		TextSize = 26,
		TextColor3 = MONEY,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(130, 32),
		Parent = money,
	}, 2.5)
	luckLabel = bigText({
		Text = "🍀 x1.00",
		TextSize = 26,
		TextColor3 = Kit.colors.white,
		Position = UDim2.fromOffset(140, 0),
		Size = UDim2.fromOffset(130, 32),
		Parent = money,
	}, 2.5)
	basketLabel = bigText({
		Text = "🧺 0/20",
		TextSize = 26,
		TextColor3 = Kit.colors.white,
		Position = UDim2.fromOffset(272, 0),
		Size = UDim2.fromOffset(150, 32),
		Parent = money,
	}, 2.5)
	basketScale = Kit.new("UIScale", { Parent = basketLabel })

	-- Bônus dos pets equipados (e do índice/renascer), acima dos boosts.
	petLabel = bigText({
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 235, 170),
		Position = UDim2.fromOffset(8, -80),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = money,
	}, 2.5)

	-- Linha dos boosts ativos, logo acima do dinheiro.
	local boostLayout = Kit.list(14, true)
	boostLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local boostRow = Kit.new("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, -46),
		Size = UDim2.fromOffset(760, 42),
		Parent = money,
	}, { boostLayout })
	-- Velocidade atual sempre à mostra: é onde o treino e as botas aparecem.
	speedLabel = bigText({
		Text = "⚡ 16",
		TextSize = 30,
		TextColor3 = Color3.fromRGB(255, 225, 70),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 0,
		Parent = boostRow,
	}, 3)
	speedScale = Kit.new("UIScale", { Parent = speedLabel })
	for order, boost in BOOSTS do
		boostLabels[boost.id] = bigText({
			Text = boost.emoji,
			TextSize = 30,
			TextColor3 = boost.color,
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
			Visible = false,
			Parent = boostRow,
		}, 3)
	end
	-- Bônus dos pets fica na mesma linha, depois da velocidade e dos boosts.
	petLabel.Parent = boostRow
	petLabel.Position = UDim2.new()
	petLabel.Size = UDim2.fromOffset(0, 40)
	petLabel.LayoutOrder = 10
	Kit.label({
		Text = "💰",
		TextSize = 56,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.fromOffset(72, 72),
		Parent = money,
	})
	coinsLabel = bigText({
		Text = "0",
		TextSize = 60,
		TextColor3 = MONEY,
		Position = UDim2.fromOffset(78, 36),
		Size = UDim2.fromOffset(340, 72),
		Parent = money,
	}, 4.5)
	coinsScale = Kit.new("UIScale", { Parent = coinsLabel })

	-- A setinha do botão apontado fica pulando para chamar atenção.
	RunService.RenderStepped:Connect(function()
		if not pointed then
			return
		end
		local entry = buttons[pointed]
		if entry then
			local bounce = math.abs(math.sin(os.clock() * 6)) * 14
			entry.pointer.Position = UDim2.new(1, 10 + bounce, 0.5, 0)
		end
	end)
end

function Hud.setCoins(value: number)
	coinsLabel.Text = Format.number(value)
	coinsScale.Scale = 1.1
	TweenService:Create(coinsScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Hud.setObjective(text: string)
	if objectiveLabel.Text == text then
		return
	end
	objectiveLabel.Text = text
	objectiveScale.Scale = 1.25
	TweenService:Create(objectiveScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Aponta um botão do menu (ou nenhum, com nil): seta pulando + bolinha "!".
function Hud.point(id: string?)
	if pointed == id then
		return
	end
	for buttonId, entry in buttons do
		local active = buttonId == id
		entry.pointer.Visible = active
		entry.badge.Visible = active
	end
	pointed = id
end

-- Cesta: branca normal, vermelha e pulsando quando está cheia.
function Hud.setBasket(count: number, max: number)
	local text = "🧺 " .. count .. "/" .. max
	if basketLabel.Text ~= text then
		basketLabel.Text = text
		basketScale.Scale = 1.2
		TweenService:Create(basketScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	basketLabel.TextColor3 = if count >= max then Kit.colors.red else Kit.colors.white
end

function Hud.tick()
	local player = Players.LocalPlayer
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local base = player:GetAttribute("Velocidade")
		local shown = if type(base) == "number" then base else humanoid.WalkSpeed
		local terrain = SpeedMods.terrain
		local text = "⚡ " .. math.floor(shown + 0.5) .. (if terrain then TERRAIN_TEXT[terrain] or "" else "")
		if speedLabel.Text ~= text then
			speedLabel.Text = text
			speedScale.Scale = 1.4
			TweenService:Create(speedScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	local now = Workspace:GetServerTimeNow()
	for _, boost in BOOSTS do
		local left = (player:GetAttribute("Boost" .. boost.id) or 0) - now
		local label = boostLabels[boost.id]
		label.Visible = left > 0
		if left > 0 then
			label.Text = boost.emoji .. " " .. math.ceil(left) .. "s"
		end
	end
	Hud.setBasket(player:GetAttribute("Cesta") or 0, player:GetAttribute("CestaMax") or 20)
	if State.profile then
		rateLabel.Text = "+" .. Format.rate(State.production()) .. "/s"
		luckLabel.Text = string.format("🍀 x%.2f", State.luck())
		local bonus = Balance.petBonus(State.profile)
		local parts = {}
		for _, stat in Species.buffOrder do
			local value = bonus[stat]
			if value > 0 then
				local buff = Species.buffs[stat]
				local shownValue = if stat == "Velocidade" or stat == "Cesta" then math.floor(value) else value
				table.insert(parts, buff.emoji .. "+" .. shownValue .. buff.suffix)
			end
		end
		local equipped = #(State.profile.equipped or {})
		petLabel.Text = if equipped > 0
			then "🐾 " .. equipped .. "/" .. Balance.petSlots(State.profile) .. "  " .. table.concat(parts, "  ")
			else ""
	end
	local golden = State.isGoldenHour()
	goldenFrame.Visible = golden
	if golden then
		goldenLabel.Text = "🌟 Hora Dourada " .. Format.time(State.goldenHourEnds() - Workspace:GetServerTimeNow())
	end
end

return Hud
