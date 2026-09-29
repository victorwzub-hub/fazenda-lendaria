-- ⚔️ Chefões: de tempos em tempos um bicho gigante (Galo Rei, Porco Rei…) aparece numa rota
-- onde tem gente. Todo mundo bate nele com 👊; ele persegue devagar e pisoteia o chão.
-- Quem ajudou ganha moedas, um ovo com muita sorte e comidas de poder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalModel = require(Shared.AnimalModel)
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Guardians = require(Shared.Config.Guardians)
local Rarities = require(Shared.Config.Rarities)
local Species = require(Shared.Config.Species)
local Remotes = require(Shared.Remotes)
local Routes = require(Shared.Config.Routes)
local Style = require(Shared.Style)

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local Notify = require(script.Parent.Notify)

local BossService = {}

local FIRST_DELAY = 3 * 60
local INTERVAL_MIN, INTERVAL_MAX = 4 * 60, 6 * 60
local TIME_LIMIT = 90
local BASE_HP = 12
local HP_PER_EXTRA_PLAYER = 6
local MODEL_SCALE = 3.2
local HIT_RANGE = 16
local HIT_COOLDOWN = 0.6
local SPEED_FACTOR = 0.55 -- em relação ao guardião da rota
local STOMP_EVERY = 5
local STOMP_WINDUP = 1
local STOMP_RADIUS = 16
local EGG_LUCK = 10
local COINS_PER_ROUTE = 300
local FOOD_DROPS = 5
local KING = Color3.fromRGB(255, 200, 40)

type Boss = {
	routeId: string,
	zone: any,
	def: any,
	model: Model,
	root: BasePart,
	hp: number,
	maxHp: number,
	ends: number,
	nextStomp: number,
	windupEnds: number,
	bar: Frame,
	hpText: TextLabel,
	warning: BillboardGui,
	helpers: { [Player]: boolean },
}

local zones = {}
local current: Boss? = nil
local lastHit: { [Player]: number } = {}
local rng = Random.new()
local EffectRemote: RemoteEvent

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inZone(zone, position: Vector3): boolean
	local offset = position - zone.origin
	local half = zone.size / 2
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half
end

local function inSafe(zone, position: Vector3): boolean
	return (flat(position) - flat(zone.safeCenter)).Magnitude <= zone.safeRadius + 2
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function playersIn(zone): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and inZone(zone, root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function kingName(routeId: string): string
	local def = Guardians.byRoute[routeId]
	return (string.gsub(def.name, " Bravo", "")):gsub(" Selvagem", "") .. " Rei"
end

local function healthBar(root: BasePart, title: string): (Frame, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Vida"
	gui.Size = UDim2.fromOffset(360, 80)
	gui.StudsOffset = Vector3.new(0, 30, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 40)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = "👑 " .. string.upper(title)
	name.TextColor3 = KING
	Style.outline(name, 3)
	name.Parent = gui
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	back.Position = UDim2.fromOffset(0, 44)
	back.Size = UDim2.new(1, 0, 0, 30)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 12)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 12)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.ZIndex = 2
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	Style.outline(text, 2)
	text.Parent = back
	gui.Parent = root
	return fill, text
end

local function warningSign(root: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 10)
	gui.StudsOffset = Vector3.new(0, 22, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "⚠️"
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = root
	return gui
end

local function updateBar(boss: Boss)
	boss.hpText.Text = "❤️ " .. boss.hp .. " / " .. boss.maxHp
	TweenService:Create(boss.bar, TweenInfo.new(0.2), { Size = UDim2.fromScale(boss.hp / boss.maxHp, 1) }):Play()
end

local function despawn(boss: Boss)
	if current == boss then
		current = nil
	end
	Workspace:SetAttribute("ChefeRota", nil)
	Workspace:SetAttribute("ChefeNome", nil)
	boss.model:Destroy()
end

-- Onda de choque no chão (anel que cresce e some).
local function shockwave(at: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 4, 4)
	ring.Color = KING
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CFrame = CFrame.new(Vector3.new(at.X, 0.3, at.Z)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	local size = STOMP_RADIUS * 2
	TweenService:Create(ring, TweenInfo.new(0.4), { Size = Vector3.new(0.3, size, size), Transparency = 1 }):Play()
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

local function stomp(boss: Boss)
	local center = boss.root.Position
	shockwave(center)
	for _, player in playersIn(boss.zone) do
		local root = rootOf(player)
		local shielded = (player:GetAttribute("BoostEscudo") or 0) > Workspace:GetServerTimeNow()
		if root and not shielded and (flat(root.Position) - flat(center)).Magnitude <= STOMP_RADIUS then
			-- Só empurra e deixa tonto: chefão é para ser divertido, não para roubar a cesta.
			EffectRemote:FireClient(player, { kind = "knock", from = center })
		end
	end
end

local function reward(boss: Boss)
	local index = table.find(Routes.order, boss.routeId) or 1
	local coins = COINS_PER_ROUTE * index
	local names = {}
	for player in boss.helpers do
		local profile = DataService.get(player)
		if profile and player.Parent then
			table.insert(names, player.DisplayName)
			DataService.addCoins(player, coins)
			profile.stats.bosses = (profile.stats.bosses or 0) + 1
			local route = Routes.byId[boss.routeId]
			local luck = Balance.luck(profile, false, false) * EGG_LUCK
			local rarity = Balance.rollRarity(luck, rng)
			local shiny = Balance.rollShiny(luck, rng)
			EggService.give(player, Species.roll(route.id, rng:NextNumber()), rarity, shiny, "👑 OVO DO REI!")
			Notify.toast(player, "⚔️ Você ajudou a derrotar o " .. kingName(boss.routeId) .. "! +💰 " .. Format.number(coins), KING)
			DataService.push(player)
		end
	end
	for i = 1, FOOD_DROPS do
		local angle = (i / FOOD_DROPS) * math.pi * 2
		local at = boss.root.Position + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
		BoostService.dropFood(boss.zone, Vector3.new(at.X, 0, at.Z), boss.def.food)
	end
	Notify.bigAll("⚔️ " .. kingName(boss.routeId) .. " DERROTADO!", "Heróis: " .. table.concat(names, ", "), KING)
end

-- Golpe do jogador no chefão. Devolve true se acertou (aí o golpe não vai para os guardiões).
function BossService.hit(player: Player): boolean
	local boss = current
	local root = rootOf(player)
	if not boss or not root then
		return false
	end
	local distance = (flat(boss.root.Position) - flat(root.Position)).Magnitude
	if distance > HIT_RANGE then
		return false
	end
	local now = os.clock()
	if lastHit[player] and now - lastHit[player] < HIT_COOLDOWN then
		return true
	end
	lastHit[player] = now
	boss.helpers[player] = true
	boss.hp -= 1
	EffectRemote:FireClient(player, { kind = "pow", at = boss.root.Position + Vector3.new(0, 6, 0) })
	updateBar(boss)
	if boss.hp <= 0 then
		reward(boss)
		despawn(boss)
	end
	return true
end

local function spawnBoss(routeId: string)
	local zone = zones[routeId]
	local def = Guardians.byRoute[routeId]
	local here = playersIn(zone)
	local name = kingName(routeId)
	local model = AnimalModel.build(def.species, Rarities.LEGENDARY, false, name)
	model.Name = "Chefe"
	model:ScaleTo(MODEL_SCALE)
	local root = model.PrimaryPart :: BasePart
	local tag = root:FindFirstChild("Tag")
	if tag then
		tag:Destroy()
	end
	local start = zone.origin + Vector3.new(0, 0, -40)
	model:PivotTo(CFrame.new(start))
	model.Parent = zone.nodes.Parent

	local maxHp = BASE_HP + HP_PER_EXTRA_PLAYER * math.max(0, #here - 1)
	local bar, hpText = healthBar(root, name)
	local boss: Boss = {
		routeId = routeId,
		zone = zone,
		def = def,
		model = model,
		root = root,
		hp = maxHp,
		maxHp = maxHp,
		ends = os.clock() + TIME_LIMIT,
		nextStomp = os.clock() + STOMP_EVERY,
		windupEnds = 0,
		bar = bar,
		hpText = hpText,
		warning = warningSign(root),
		helpers = {},
	}
	updateBar(boss)
	current = boss
	Workspace:SetAttribute("ChefeRota", routeId)
	Workspace:SetAttribute("ChefeNome", name)
	Notify.bigAll(
		"⚔️ CHEFÃO: " .. string.upper(name) .. "!",
		"Apareceu na " .. Routes.byId[routeId].name .. ". Bata nele com 👊 junto com todo mundo!",
		KING,
		"galo"
	)
end

local function step(boss: Boss, dt: number, now: number)
	if now > boss.ends then
		Notify.bigAll("💨 O " .. kingName(boss.routeId) .. " fugiu!", "Fique atento: outro chefão aparece daqui a pouco", KING)
		despawn(boss)
		return
	end
	local position = boss.root.Position
	-- Pisão: avisa (⚠️ e pulinho alto), depois bate no chão.
	if boss.windupEnds > 0 then
		local hop = math.sin(math.clamp(1 - (boss.windupEnds - now) / STOMP_WINDUP, 0, 1) * math.pi) * 6
		boss.root.CFrame = CFrame.new(position.X, hop, position.Z) * boss.root.CFrame.Rotation
		if now >= boss.windupEnds then
			boss.windupEnds = 0
			boss.warning.Enabled = false
			boss.root.CFrame = CFrame.new(position.X, 0, position.Z) * boss.root.CFrame.Rotation
			stomp(boss)
			boss.nextStomp = now + STOMP_EVERY
		end
		return
	end
	if now >= boss.nextStomp then
		boss.windupEnds = now + STOMP_WINDUP
		boss.warning.Enabled = true
		return
	end
	-- Anda devagar atrás do jogador mais perto (fora da zona segura).
	local target: BasePart? = nil
	local best = math.huge
	for _, player in playersIn(boss.zone) do
		local root = rootOf(player)
		if root and not inSafe(boss.zone, root.Position) then
			local distance = (flat(root.Position) - flat(position)).Magnitude
			if distance < best then
				target, best = root, distance
			end
		end
	end
	if not target or best < 6 then
		return
	end
	local direction = (flat((target :: BasePart).Position) - flat(position)).Unit
	local moved = flat(position) + direction * boss.def.speed * SPEED_FACTOR * dt
	if inSafe(boss.zone, moved) then
		return
	end
	local hop = math.abs(math.sin(now * 5)) * 0.8
	local at = Vector3.new(moved.X, hop, moved.Z)
	boss.root.CFrame = CFrame.lookAt(at, at + direction)
end

local function tryStart()
	if current then
		return
	end
	local candidates = {}
	for _, routeId in Routes.order do
		local zone = zones[routeId]
		if zone and #playersIn(zone) > 0 then
			table.insert(candidates, routeId)
		end
	end
	if #candidates > 0 then
		spawnBoss(candidates[rng:NextInteger(1, #candidates)])
	end
end

function BossService.init(zoneMap)
	zones = zoneMap
	EffectRemote = Remotes.event("Effect")

	RunService.Heartbeat:Connect(function(dt)
		local boss = current
		if boss then
			step(boss, dt, os.clock())
		end
	end)

	task.spawn(function()
		task.wait(FIRST_DELAY)
		while true do
			tryStart()
			-- Sem ninguém nas rotas, tenta de novo logo; senão espera o intervalo.
			task.wait(if current then rng:NextNumber(INTERVAL_MIN, INTERVAL_MAX) else 20)
		end
	end)

	-- Só no Studio: marcar Workspace.ForcarChefe = true chama um chefão na hora (para testar).
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("ForcarChefe"):Connect(function()
			if Workspace:GetAttribute("ForcarChefe") then
				Workspace:SetAttribute("ForcarChefe", nil)
				tryStart()
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		if current then
			current.helpers[player] = nil
		end
	end)
end

return BossService
