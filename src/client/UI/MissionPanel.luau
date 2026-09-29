-- Painel fixo da missão atual (lado direito): número, texto, barra de progresso e prêmio.
-- Lê os atributos "Missao*" publicados pelo MissionService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Style = require(Shared.Style)

local Kit = require(script.Parent.Kit)

local MissionPanel = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(95, 235, 70)

local player = Players.LocalPlayer
local header: TextLabel
local body: TextLabel
local fill: Frame
local count: TextLabel
local reward: TextLabel
local scale: UIScale
local lastNumber = 0

local function text(props: { [string]: any }, outline: number): TextLabel
	local label = Kit.label(props)
	label.Font = Enum.Font.FredokaOne
	Style.outline(label, outline)
	return label
end

function MissionPanel.mount(gui: ScreenGui, scales: { UIScale })
	-- Duas camadas: o Roblox aplica só um UIScale por elemento (tamanho da tela + "pulo").
	local holder = Kit.new("Frame", {
		Name = "Missao",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -10),
		Size = UDim2.fromOffset(330, 150),
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = holder }))
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 22, 14),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, { Kit.corner(16), Kit.stroke(GOLD, 3), Kit.padding(12) })
	scale = Kit.new("UIScale", { Parent = frame })

	header = text({
		Text = "📜 MISSÃO 1",
		TextSize = 20,
		TextColor3 = GOLD,
		Size = UDim2.new(1, 0, 0, 22),
		TextWrapped = false,
		Parent = frame,
	}, 2)
	body = text({
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 52),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	}, 2.5)
	local bar = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(15, 10, 6),
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = frame,
	}, { Kit.corner(11) })
	fill = Kit.new("Frame", {
		BackgroundColor3 = GREEN,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Kit.corner(11) })
	count = text({
		Text = "0/10",
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = bar,
	}, 2)
	reward = text({
		Text = "🎁 +💰 0",
		TextSize = 20,
		TextColor3 = GREEN,
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 22),
		TextWrapped = false,
		Parent = frame,
	}, 2)
end

function MissionPanel.tick()
	local number = player:GetAttribute("MissaoNumero")
	if not number then
		return
	end
	local progress = player:GetAttribute("MissaoProgresso") or 0
	local goal = math.max(player:GetAttribute("MissaoMeta") or 1, 1)
	header.Text = "📜 MISSÃO " .. number
	body.Text = player:GetAttribute("MissaoTexto") or ""
	count.Text = if goal == 1 then (if progress >= 1 then "✅" else "0/1") else Format.number(progress) .. "/" .. Format.number(goal)
	reward.Text = "🎁 Prêmio: 💰 " .. Format.number(player:GetAttribute("MissaoPremio") or 0)
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(progress / goal, 0, 1), 1) }):Play()
	-- Missão nova: o painel dá um pulo para chamar atenção.
	if number ~= lastNumber then
		if lastNumber ~= 0 then
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastNumber = number
	end
end

return MissionPanel
