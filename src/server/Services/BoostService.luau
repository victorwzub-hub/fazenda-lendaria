-- Boosts: ícones que aparecem nas rotas. Quem encosta ganha um poder por alguns segundos.
-- O fim de cada boost fica num atributo do jogador ("Boost<Id>", em tempo do servidor),
-- que o HUD usa para mostrar a contagem e os outros serviços usam para aplicar o efeito.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Style = require(Shared.Style)

local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)
local RouteService = require(script.Parent.RouteService)

local BoostService = {}

type BoostDef = { id: string, emoji: string, name: string, seconds: number, color: Color3, weight: number }

BoostService.DEFS = {
	{ id = "Velocidade", emoji = "👟", name = "Supervelocidade", seconds = 10, color = Color3.fromRGB(80, 200, 255), weight = 3 },
	{ id = "Ima", emoji = "🧲", name = "Ímã", seconds = 10, color = Color3.fromRGB(255, 80, 90), weight = 3 },
	{ id = "Escudo", emoji = "🛡️", name = "Escudo", seconds = 12, color = Color3.fromRGB(255, 215, 70), weight = 2 },
} :: { BoostDef }

local PER_ZONE = 3
local RESPAWN_MIN, RESPAWN_MAX = 20, 35
local MAGNET_RADIUS = 16
local MAGNET_TICK = 0.3

local rng = Random.new()

function BoostService.active(player: Player, id: string): boolean
	return (player:GetAttribute("Boost" .. id) or 0) > Workspace:GetServerTimeNow()
end

local function pick(): BoostDef
	local total = 0
	for _, def in BoostService.DEFS do
		total += def.weight
	end
	local roll = rng:NextNumber() * total
	for _, def in BoostService.DEFS do
		roll -= def.weight
		if roll <= 0 then
			return def
		end
	end
	return BoostService.DEFS[1]
end

local function apply(player: Player, def: BoostDef)
	local character = player.Character
	if not character then
		return
	end
	local ends = Workspace:GetServerTimeNow() + def.seconds
	player:SetAttribute("Boost" .. def.id, ends)
	Notify.toast(player, def.emoji .. " " .. def.name .. " por " .. def.seconds .. " segundos!", def.color)

	if def.id == "Velocidade" then
		FarmService.applySpeed(player)
	elseif def.id == "Escudo" then
		local old = character:FindFirstChild("EscudoBoost")
		if old then
			old:Destroy()
		end
		local field = Instance.new("ForceField")
		field.Name = "EscudoBoost"
		field.Parent = character
	end

	task.delay(def.seconds + 0.05, function()
		if BoostService.active(player, def.id) then
			return -- pegou outro igual no meio do caminho
		end
		if def.id == "Velocidade" then
			FarmService.applySpeed(player)
		elseif def.id == "Escudo" and player.Character then
			local field = player.Character:FindFirstChild("EscudoBoost")
			if field then
				field:Destroy()
			end
		end
	end)
end

local function spawnPickup(zone, randomPoint: () -> Vector3)
	local def = pick()
	local position = randomPoint()

	local model = Instance.new("Model")
	model.Name = "Boost" .. def.id
	local core = Instance.new("Part")
	core.Name = "Nucleo"
	core.Size = Vector3.one * 2.2
	core.Material = Enum.Material.Neon
	core.Color = def.color
	core.Transparency = 0.25
	core.Anchored = true
	core.CanCollide = false
	core.CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	core.Parent = model
	local base = Instance.new("Part")
	base.Size = Vector3.new(4, 0.4, 4)
	base.Color = Style.shade(def.color, -0.35)
	base.Material = Enum.Material.Plastic
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0))
	base.Parent = model
	Style.studs(base)

	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 12
	light.Brightness = 2
	light.Parent = core
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(def.color)
	sparkles.LightEmission = 1
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Parent = core

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 4)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Text = def.emoji
	icon.TextScaled = true
	icon.Parent = gui
	gui.Parent = core

	local used = false
	core.Touched:Connect(function(hit)
		if used then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		used = true
		model:Destroy()
		apply(player, def)
		task.delay(rng:NextNumber(RESPAWN_MIN, RESPAWN_MAX), spawnPickup, zone, randomPoint)
	end)
	model.Parent = zone.nodes.Parent
end

function BoostService.init(zones)
	for _, zone in zones do
		local half = zone.size / 2 - 16
		local function randomPoint(): Vector3
			return zone.origin + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		end
		for _ = 1, PER_ZONE do
			spawnPickup(zone, randomPoint)
		end
	end

	-- Ímã: puxa os itens comuns em volta de quem está com o boost.
	task.spawn(function()
		while true do
			task.wait(MAGNET_TICK)
			for _, player in Players:GetPlayers() do
				if BoostService.active(player, "Ima") then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						RouteService.pull(player, root.Position, MAGNET_RADIUS)
					end
				end
			end
		end
	end)
end

return BoostService
