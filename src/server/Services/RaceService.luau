-- 🏇 Corrida a cavalo (Rota da Pradaria): na largada, perto da chegada da rota, o jogador monta
-- num cavalo (velocidade 60) e precisa passar pelos 8 arcos em volta da rota antes do tempo
-- acabar. Ganha moedas e às vezes um ovo da Pradaria.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)
local Style = require(Shared.Style)

local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local FarmService = require(script.Parent.FarmService)
local Notify = require(script.Parent.Notify)

local RaceService = {}

local ROUTE = "Pradaria"
local CHECKPOINTS = 8
local RACE_SECONDS = 50
local HORSE_SPEED = 60
local RING_RADIUS = 12
local LOOP_RADIUS = 0.32
local COOLDOWN = 10
local REWARD = 2500
local EGG_CHANCE = 0.4
local EGG_LUCK = 3
local HIP_RAISE = 2.8
local GOLD = Color3.fromRGB(255, 205, 60)

type Race = { target: number, ends: number, started: number, horse: Model, hip: number }

local zone
local rings: { Vector3 } = {}
local racing: { [Player]: Race } = {}
local lastRace: { [Player]: number } = {}
local rng = Random.new()

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function part(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.Parent = parent
	return p
end

local function sign(adornee: BasePart, text: string, color: Color3, size: UDim2, offset: Vector3)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 300
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	Style.outline(label, 4)
	label.Parent = gui
	gui.Parent = adornee
end

-- Arcos numerados em volta da rota; o cliente destaca o próximo de quem está correndo.
local function buildCourse(parent: Instance)
	local folder = Instance.new("Model")
	folder.Name = "Corrida"
	local radius = zone.size * LOOP_RADIUS
	for i = 1, CHECKPOINTS do
		local angle = math.pi / 2 + (i - 1) * (2 * math.pi / CHECKPOINTS)
		rings[i] = zone.origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	for i, at in rings do
		local nextAt = rings[i % CHECKPOINTS + 1]
		local facing = CFrame.lookAt(at, Vector3.new(nextAt.X, at.Y, nextAt.Z))
		local arch = Instance.new("Model")
		arch.Name = "Arco" .. i
		local wood = Color3.fromRGB(150, 100, 55)
		for _, x in { -RING_RADIUS, RING_RADIUS } do
			part(arch, Vector3.new(1.4, 14, 1.4), facing * CFrame.new(x, 7, 0), wood, Enum.Material.WoodPlanks)
		end
		local bar = part(arch, Vector3.new(RING_RADIUS * 2 + 2, 1.6, 1.6), facing * CFrame.new(0, 14, 0), GOLD)
		bar.Name = "Barra"
		local glow = part(arch, Vector3.new(RING_RADIUS * 2 - 1.4, 12.4, 0.3), facing * CFrame.new(0, 6.8, 0), GOLD, Enum.Material.Neon)
		glow.Name = "Brilho"
		glow.Transparency = 0.85
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		sign(bar, tostring(i), Color3.new(1, 1, 1), UDim2.fromScale(5, 5), Vector3.new(0, 4, 0))
		arch.Parent = folder
	end
	Style.apply(folder)
	folder.Parent = parent
end

local function dismount(player: Player, message: string?, color: Color3?)
	local race = racing[player]
	if not race then
		return
	end
	racing[player] = nil
	lastRace[player] = os.clock()
	if race.horse then
		race.horse:Destroy()
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HipHeight = race.hip
	end
	player:SetAttribute("CorridaVelocidade", nil)
	player:SetAttribute("CorridaAlvo", nil)
	player:SetAttribute("CorridaFim", nil)
	FarmService.applySpeed(player)
	if message then
		Notify.big(player, message, nil, color or GOLD)
	end
end

-- Cavalo soldado embaixo do jogador; o jogador sobe (HipHeight) e fica montado.
local function mount(player: Player): (Model?, number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil, 0
	end
	local hip = humanoid.HipHeight
	humanoid.HipHeight = hip + HIP_RAISE
	local horse = AnimalModel.build("Cavalo", 3, false, "Montaria", true)
	local tag = horse.PrimaryPart and horse.PrimaryPart:FindFirstChild("Tag")
	if tag then
		tag:Destroy()
	end
	for _, descendant in horse:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local horseRoot = horse.PrimaryPart :: BasePart
	local offset = CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0.4)
	horse:PivotTo(root.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = horseRoot
	weld.C0 = offset
	weld.Parent = horseRoot
	horse.Name = "Montaria"
	horse.Parent = character
	return horse, hip
end

local function start(player: Player)
	local profile = DataService.get(player)
	local root = rootOf(player)
	if not profile or not root or racing[player] then
		return
	end
	if not profile.routes[ROUTE] then
		Notify.toast(player, "🔒 Libere a Rota da Pradaria para correr", Color3.fromRGB(255, 120, 100))
		return
	end
	if EggService.isCarrying(player) then
		Notify.toast(player, "🥚 Leve o ovo para a Chocadeira antes de correr", Color3.fromRGB(255, 200, 120))
		return
	end
	local wait = if lastRace[player] then lastRace[player] + COOLDOWN - os.clock() else 0
	if wait > 0 then
		Notify.toast(player, "🐴 O cavalo está descansando… " .. math.ceil(wait) .. "s", GOLD)
		return
	end
	local horse, hip = mount(player)
	if not horse then
		return
	end
	racing[player] = { target = 1, ends = os.clock() + RACE_SECONDS, started = os.clock(), horse = horse, hip = hip }
	player:SetAttribute("CorridaVelocidade", HORSE_SPEED)
	player:SetAttribute("CorridaAlvo", 1)
	player:SetAttribute("CorridaFim", Workspace:GetServerTimeNow() + RACE_SECONDS)
	FarmService.applySpeed(player)
	Notify.big(player, "🏇 VAI!", "Passe pelos " .. CHECKPOINTS .. " arcos em " .. RACE_SECONDS .. " segundos! Siga a seta", GOLD, "boost")
end

local function win(player: Player, race: Race)
	local profile = DataService.get(player)
	local seconds = os.clock() - race.started
	dismount(player)
	if not profile then
		return
	end
	profile.stats.races = (profile.stats.races or 0) + 1
	local coins = math.floor(REWARD * Balance.coinMultiplier(profile))
	DataService.addCoins(player, coins)
	DataService.push(player)
	Notify.big(
		player,
		"🏆 CORRIDA COMPLETA!",
		string.format("Tempo: %.1fs   +💰 %s", seconds, Format.number(coins)),
		GOLD,
		"revelar"
	)
	if rng:NextNumber() < EGG_CHANCE then
		local luck = Balance.luck(profile, false, false) * EGG_LUCK
		local rarity = Balance.rollRarity(luck, rng)
		task.delay(2.5, function()
			if player.Parent then
				EggService.give(player, Species.roll(ROUTE, rng:NextNumber()), rarity, Balance.rollShiny(luck, rng), "🏇 OVO DA CORRIDA!")
			end
		end)
	end
end

function RaceService.init(zones)
	zone = zones[ROUTE]
	if not zone then
		return
	end
	local parent = zone.nodes.Parent :: Instance
	buildCourse(parent)

	-- Largada: placa + cavalo parado, perto da zona segura.
	local post = Instance.new("Model")
	post.Name = "Largada"
	local at = CFrame.new(zone.safeCenter + Vector3.new(zone.safeRadius - 4, 0, -6))
	for _, x in { -3, 3 } do
		part(post, Vector3.new(0.8, 8, 0.8), at * CFrame.new(x, 4, 0), Color3.fromRGB(150, 100, 55), Enum.Material.WoodPlanks)
	end
	local banner = part(post, Vector3.new(8, 3, 0.4), at * CFrame.new(0, 7.5, 0), Color3.fromRGB(200, 50, 45))
	banner.Name = "Faixa"
	sign(banner, "🏇 CORRIDA A CAVALO", GOLD, UDim2.fromScale(16, 3), Vector3.new(0, 3, 0))
	local statue = AnimalModel.build("Cavalo", 3, false, "Cavalo de Corrida", true)
	statue:PivotTo(at * CFrame.new(-8, 0, 1) * CFrame.Angles(0, math.rad(90), 0))
	statue.Parent = post
	Style.apply(post)
	post.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Montar e correr"
	prompt.ObjectText = "🏇 Corrida (" .. RACE_SECONDS .. "s)"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = banner
	prompt.Triggered:Connect(start)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, race in racing do
			local root = rootOf(player)
			if not root or not player.Parent then
				dismount(player)
			elseif (root.Position - zone.origin).Magnitude > zone.size then
				dismount(player, "🏇 Você saiu da corrida", Color3.fromRGB(255, 120, 100))
			elseif now > race.ends then
				dismount(player, "⏰ O tempo acabou!", Color3.fromRGB(255, 120, 100))
			else
				local ring = rings[race.target]
				local offset = root.Position - ring
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= RING_RADIUS then
					race.target += 1
					if race.target > CHECKPOINTS then
						win(player, race)
					else
						player:SetAttribute("CorridaAlvo", race.target)
						Notify.toast(player, "✅ Arco " .. (race.target - 1) .. "/" .. CHECKPOINTS, GOLD, "coleta")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		racing[player] = nil
		lastRace[player] = nil
	end)
end

-- Morreu/resetou montado: termina a corrida.
function RaceService.onCharacter(player: Player)
	if racing[player] then
		racing[player] = nil
		player:SetAttribute("CorridaVelocidade", nil)
		player:SetAttribute("CorridaAlvo", nil)
		player:SetAttribute("CorridaFim", nil)
	end
end

return RaceService
