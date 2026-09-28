-- Treino na esteira: quem fica em cima da lona (e para isso precisa correr, porque ela
-- empurra para trás) ganha 1 ponto a cada 3 s; cada 10 pontos = +1 de velocidade, até +10.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage:WaitForChild("Shared").Balance)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)

local TrainingService = {}

local TICK = 0.5
local SECONDS_PER_POINT = 3

local belts: { BasePart } = {}
local progress: { [Player]: number } = {}

local function onBelt(root: BasePart): boolean
	for _, belt in belts do
		local rel = belt.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) <= belt.Size.X / 2 + 0.3 and math.abs(rel.Z) <= belt.Size.Z / 2 and rel.Y > 0 and rel.Y < 5 then
			return true
		end
	end
	return false
end

local function tick(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	local training = onBelt(root)
	if player:GetAttribute("NaEsteira") ~= training then
		player:SetAttribute("NaEsteira", training)
	end
	if not training or (profile.training or 0) >= Balance.TRAIN_MAX then
		return
	end
	progress[player] = (progress[player] or 0) + TICK
	if progress[player] < SECONDS_PER_POINT then
		return
	end
	progress[player] = 0
	local before = Balance.trainedSpeed(profile)
	profile.training = (profile.training or 0) + 1
	player:SetAttribute("Treino", profile.training)
	if Balance.trainedSpeed(profile) > before then
		FarmService.applySpeed(player)
		DataService.push(player)
		Notify.toast(
			player,
			"🏃 +1 de velocidade pelo treino! Agora: " .. Balance.walkSpeed(profile),
			Color3.fromRGB(120, 230, 255)
		)
	end
end

function TrainingService.setup(player: Player)
	local profile = DataService.get(player)
	player:SetAttribute("Treino", if profile then profile.training or 0 else 0)
	player:SetAttribute("TreinoMax", Balance.TRAIN_MAX)
end

function TrainingService.init(plots)
	for _, plot in plots do
		table.insert(belts, plot.treadmill)
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
end

return TrainingService
