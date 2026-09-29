-- Painel que aparece embaixo enquanto o jogador está na esteira: quanto ganha por segundo,
-- barra até o próximo +1 e "⚡ 18 → 19", com o próximo guardião a ultrapassar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Guardians = require(Shared.Config.Guardians)
local Style = require(Shared.Style)

local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.State)

local TrainingPanel = {}

local BLUE = Color3.fromRGB(120, 210, 255)

local player = Players.LocalPlayer
local holder: Frame
local title: TextLabel
local fill: Frame
local speedText: TextLabel
local goalText: TextLabel

local function text(props: { [string]: any }, outline: number): TextLabel
	local label = Kit.label(props)
	label.Font = Enum.Font.FredokaOne
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	Style.outline(label, outline)
	return label
end

function TrainingPanel.mount(gui: ScreenGui, scales: { UIScale })
	holder = Kit.new("Frame", {
		Name = "Treino",
		BackgroundColor3 = Color3.fromRGB(12, 24, 48),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(480, 132),
		Visible = false,
		Parent = gui,
	}, { Kit.corner(18), Kit.stroke(BLUE, 3), Kit.padding(10) })
	table.insert(scales, Kit.new("UIScale", { Parent = holder }))

	title = text({ Text = "🏃 TREINANDO  +10/s", TextSize = 28, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 30), Parent = holder }, 3)
	local bar = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(5, 10, 22),
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = holder,
	}, { Kit.corner(15) })
	fill = Kit.new("Frame", { BackgroundColor3 = BLUE, Size = UDim2.fromScale(0, 1), Parent = bar }, { Kit.corner(15) })
	speedText = text({ Text = "⚡ 16 → 17", TextSize = 24, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = bar }, 2.5)
	goalText = text({ Text = "", TextSize = 20, TextColor3 = Color3.fromRGB(255, 225, 90), Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 24), Parent = holder }, 2)
end

function TrainingPanel.tick()
	local profile = State.profile
	local training = player:GetAttribute("NaEsteira") == true
	holder.Visible = training and profile ~= nil
	if not holder.Visible then
		return
	end
	local points = player:GetAttribute("Treino") or 0
	local speed = Balance.walkSpeed(profile)
	if points >= Balance.TRAIN_MAX then
		title.Text = "🏃 TREINO COMPLETO!"
		speedText.Text = "⚡ " .. speed .. " (máximo)"
		fill.Size = UDim2.fromScale(1, 1)
		goalText.Text = "Compre 👢 Botas na Loja para ficar ainda mais rápido"
		return
	end
	title.Text = "🏃 TREINANDO  +" .. Balance.trainGain(profile) .. "/s"
	local within = points % Balance.TRAIN_PER_SPEED
	speedText.Text = "⚡ " .. speed .. "  →  " .. (speed + 1) .. "     (" .. within .. "/" .. Balance.TRAIN_PER_SPEED .. ")"
	TweenService:Create(fill, TweenInfo.new(0.45), { Size = UDim2.fromScale(within / Balance.TRAIN_PER_SPEED, 1) }):Play()
	-- Mostra o próximo guardião a ultrapassar: é o motivo de treinar.
	goalText.Text = "Você já corre mais que todos os guardiões! 🏆"
	for _, routeId in Guardians.order do
		local guardian = Guardians.byRoute[routeId]
		if speed <= guardian.speed then
			goalText.Text = "Próximo: passar o " .. guardian.emoji .. " " .. guardian.name .. " (⚡" .. guardian.speed .. ")"
			break
		end
	end
end

return TrainingPanel
