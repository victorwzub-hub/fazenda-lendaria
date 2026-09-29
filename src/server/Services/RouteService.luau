local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Materials = require(Shared.Config.Materials)
local Rarities = require(Shared.Config.Rarities)
local Routes = require(Shared.Config.Routes)
local Species = require(Shared.Config.Species)
local Guardians = require(Shared.Config.Guardians)
local Style = require(Shared.Style)

local Basket = require(script.Parent.Basket)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local FarmService = require(script.Parent.FarmService)
local GuardianService = require(script.Parent.GuardianService)
local Notify = require(script.Parent.Notify)
local PassService = require(script.Parent.PassService)
local Teleport = require(script.Parent.Teleport)

local RouteService = {}

local GOLDEN_INTERVAL = 12 * 60
local GOLDEN_DURATION = 2 * 60
local GOLDEN_RARE_BOOST = 3
local RESPAWN_MIN, RESPAWN_MAX = 6, 14
local TOUCH_COOLDOWN = 2
local NEST_HOLD = 1.5
-- Ninhal no meio de cada rota: 3 ninhos fixos, sempre visíveis. Os melhores pedem velocidade
-- mínima (velocidade do guardião da rota + extra) e dão muito mais sorte na raridade.
local NEST_TIERS = {
	{ name = "Ninho", emoji = "🥚", extra = nil, luck = 1, hold = 1.5, respawn = 12, egg = Color3.fromRGB(255, 248, 230), neon = false },
	{ name = "Ninho Raro", emoji = "💙", extra = 3, luck = 3, hold = 2, respawn = 25, egg = Color3.fromRGB(90, 160, 255), neon = false },
	{ name = "Ninho Dourado", emoji = "💛", extra = 9, luck = 8, hold = 2.5, respawn = 50, egg = Color3.fromRGB(255, 205, 50), neon = true },
}
local NEST_SPACING = 12
local NINHAL_CLEAR = 26 -- itens aleatórios não nascem em cima do Ninhal
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 205, 60)

local zones = {}
local rng = Random.new()
local lastTouch: { [Player]: number } = {}
local magnetic: { [Model]: { root: BasePart, take: (Player) -> boolean } } = {}

function RouteService.isGoldenHour(): boolean
	return (Workspace:GetAttribute("GoldenHourEnds") or 0) > Workspace:GetServerTimeNow()
end

local function piece(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function glow(part: BasePart, color: Color3, rate: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLES
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Parent = part
end

local function buildNode(def, route): (Model, BasePart)
	local model = Instance.new("Model")
	local root: BasePart
	if def.nest then
		-- Ninho quadrado de palha, com borda e um ovo oval com pintinhas da cor da rota.
		model.Name = "Ninho"
		local straw = Color3.fromRGB(222, 180, 90)
		root = piece(model, Vector3.new(4.4, 0.6, 4.4), CFrame.new(0, 0.3, 0), straw, Enum.Material.Fabric)
		for i = 0, 3 do
			local side = CFrame.Angles(0, i * math.pi / 2, 0)
			piece(
				model,
				Vector3.new(4.4, 0.9, 0.9),
				side * CFrame.new(0, 0.95, 1.75),
				Style.shade(straw, -0.18),
				Enum.Material.Fabric
			)
		end
		local egg = piece(
			model,
			Vector3.one * 1.9,
			CFrame.new(0, 2, 0),
			Color3.fromRGB(255, 248, 230),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.3, 1)
		mesh.Parent = egg
		for _, spot in { Vector3.new(0.62, 2.4, -0.6), Vector3.new(-0.7, 1.9, -0.45), Vector3.new(0.2, 2.9, 0.7) } do
			piece(model, Vector3.new(0.45, 0.45, 0.45), CFrame.new(spot), route.theme, Enum.Material.SmoothPlastic)
		end
		glow(egg, route.theme, 4)
	else
		local material = Materials.byId[def.material]
		model.Name = material.name
		if material.tier == 1 then
			-- Arbustinho em degraus com frutinhas quadradas.
			root = piece(
				model,
				Vector3.new(3, 1.4, 3),
				CFrame.new(0, 0.7, 0),
				Style.shade(route.foliage, -0.1),
				Enum.Material.Grass
			)
			piece(model, Vector3.new(2, 1.1, 2), CFrame.new(0, 1.95, 0), route.foliage, Enum.Material.Grass)
			for i = 0, 2 do
				local angle = i * math.pi * 2 / 3
				piece(
					model,
					Vector3.new(0.7, 0.7, 0.7),
					CFrame.new(math.cos(angle) * 1.2, 1.9 + (i % 2) * 0.7, math.sin(angle) * 1.2)
						* CFrame.Angles(0, angle, 0),
					material.color,
					Enum.Material.SmoothPlastic
				)
			end
		elseif material.tier == 2 then
			-- Caixote de madeira com faixas escuras e tampa colorida.
			local wood = Color3.fromRGB(190, 130, 70)
			root = piece(model, Vector3.one * 2.4, CFrame.new(0, 1.2, 0), wood, Enum.Material.WoodPlanks)
			for _, y in { 0.45, 1.95 } do
				piece(
					model,
					Vector3.new(2.55, 0.35, 2.55),
					CFrame.new(0, y, 0),
					Style.shade(wood, -0.3),
					Enum.Material.WoodPlanks
				)
			end
			piece(model, Vector3.new(2.6, 0.4, 2.6), CFrame.new(0, 2.6, 0), material.color, Enum.Material.SmoothPlastic)
		elseif material.tier == 3 then
			-- Pedra com uma gema de cubo girado brilhando em cima.
			root = piece(
				model,
				Vector3.new(2.6, 1.2, 2.6),
				CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(20), 0),
				Color3.fromRGB(140, 145, 160),
				Enum.Material.Slate
			)
			piece(
				model,
				Vector3.new(1.6, 0.6, 1.6),
				CFrame.new(0.2, 1.5, 0.1) * CFrame.Angles(0, math.rad(50), 0),
				Color3.fromRGB(165, 170, 185),
				Enum.Material.Slate
			)
			local gem = piece(
				model,
				Vector3.one * 1.2,
				CFrame.new(0, 2.8, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				material.color,
				Enum.Material.Neon
			)
			glow(gem, material.color, 5)
		else
			root = piece(
				model,
				Vector3.new(1.1, 4, 1.1),
				CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.rad(45), math.rad(8)),
				material.color,
				Enum.Material.Neon
			)
			piece(
				model,
				Vector3.new(0.7, 2.4, 0.7),
				CFrame.new(0.9, 1.1, 0.3) * CFrame.Angles(0, 0, math.rad(-25)),
				material.color,
				Enum.Material.Neon
			)
			piece(
				model,
				Vector3.new(0.6, 2, 0.6),
				CFrame.new(-0.8, 1, -0.4) * CFrame.Angles(math.rad(20), 0, math.rad(22)),
				material.color,
				Enum.Material.Neon
			)
			glow(root, material.color, 10)
		end
	end
	model.WorldPivot = CFrame.identity
	Style.apply(model)
	return model, root
end

local function pickDef(route, golden: boolean)
	local weights = {}
	for i, def in route.nodes do
		local boosted = def.nest or Materials.byId[def.material].tier >= 3
		weights[i] = if def.nest then 0 else def.weight * (if golden and boosted then GOLDEN_RARE_BOOST else 1)
	end
	return route.nodes[Balance.pickWeighted(weights, rng:NextNumber())]
end

local function randomNodeCFrame(zone): CFrame
	local half = zone.size / 2 - 10
	local spawnFlat = Vector3.new(zone.spawn.Position.X, 0, zone.spawn.Position.Z)
	local barnFlat = zone.origin + Vector3.new(-zone.size / 2 + 26, 0, zone.size / 2 - 26)
	local point = zone.origin
	for _ = 1, 30 do
		point = zone.origin + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		local clearOfNinhal = (point - zone.origin).Magnitude > NINHAL_CLEAR
		if (point - spawnFlat).Magnitude > 30 and (point - barnFlat).Magnitude > 16 and clearOfNinhal then
			break
		end
	end
	return CFrame.new(point) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function collect(player: Player, route, def, luckMult: number?): boolean
	local profile = DataService.get(player)
	if not profile or not profile.routes[route.id] then
		return false
	end
	local luck = Balance.luck(profile, PassService.has(player, "SorteDupla"), RouteService.isGoldenHour()) * (luckMult or 1)

	if def.nest then
		local rarity = Balance.rollRarity(luck, rng)
		local shiny = Balance.rollShiny(luck, rng)
		profile.stats.nests += 1
		-- O ninho dá um ovo; ele choca na Chocadeira da fazenda (EggService).
		EggService.give(player, route.species, rarity, shiny, "🥚 NINHO ABERTO!")
		return true
	end

	local material = Materials.byId[def.material]
	local amount = rng:NextInteger(def.min, def.max)
	local doubled = rng:NextNumber() < Balance.doubleDropChance(luck)
	if doubled then
		amount *= 2
	end
	amount += Balance.netBonus(profile, rng:NextNumber())
	-- Vai para a cesta: só vira material de verdade quando o jogador volta para a fazenda.
	amount = Basket.add(player, def.material, amount)
	profile.stats.collected += 1
	if material.tier >= 4 then
		Notify.big(
			player,
			"💎 CRISTAL ESTELAR!",
			"Material ultra-raro usado para criar animais Míticos",
			material.color
		)
	else
		Notify.toast(
			player,
			"+" .. amount .. " " .. material.emoji .. " " .. material.name .. (if doubled then "   🍀 x2!" else ""),
			material.color,
			"coleta"
		)
	end
	return true
end

local function spawnNode(routeId: string)
	local zone = zones[routeId]
	local route = Routes.byId[routeId]
	local def = pickDef(route, RouteService.isGoldenHour())
	local model, root = buildNode(def, route)
	model:PivotTo(randomNodeCFrame(zone))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if def.nest then "Abrir ninho" else "Coletar"
	prompt.ObjectText = model.Name
	-- Ninho demora para abrir: é a janela em que o guardião chega correndo.
	prompt.HoldDuration = if def.nest then NEST_HOLD elseif Materials.byId[def.material].tier >= 3 then 0.6 else 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local alertChance = if def.nest then 1 elseif Materials.byId[def.material].tier >= 3 then 0.5 else 0.15
	prompt.PromptButtonHoldBegan:Connect(function(player)
		GuardianService.alert(player, root.Position, alertChance)
	end)

	local taken = false
	local function take(player: Player): boolean
		if taken then
			return false
		end
		local profile = DataService.get(player)
		if not profile or not profile.routes[routeId] then
			return false
		end
		if not def.nest and Basket.space(player) <= 0 then
			Notify.toast(player, "🧺 Cesta cheia! Volte para a fazenda para guardar", Color3.fromRGB(255, 120, 100))
			return false
		end
		taken = true
		magnetic[model] = nil
		model:Destroy()
		collect(player, route, def)
		task.delay(rng:NextNumber(RESPAWN_MIN, RESPAWN_MAX), spawnNode, routeId)
		return true
	end
	prompt.Triggered:Connect(take)

	-- Itens comuns podem ser puxados pelo boost de ímã.
	if not def.nest and Materials.byId[def.material].tier <= 2 then
		magnetic[model] = { root = root, take = take }
	end
	model.Parent = zone.nodes
end

-- Ímã: coleta sozinho os itens comuns perto do jogador. Devolve quantos pegou.
function RouteService.pull(player: Player, position: Vector3, radius: number): number
	local count = 0
	for _, node in magnetic do
		if (node.root.Position - position).Magnitude <= radius and node.take(player) then
			count += 1
		end
	end
	return count
end

local function nestRequirement(routeId: string, tier): number?
	local guardian = Guardians.byRoute[routeId]
	return if tier.extra and guardian then guardian.speed + tier.extra else nil
end

local function nestSign(root: BasePart, tier, requirement: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Placa"
	-- Tamanho em studs: encolhe com a distância e as 3 placas não se sobrepõem.
	gui.Size = UDim2.fromScale(10, 3.2)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = tier.emoji .. " " .. string.upper(tier.name)
	title.TextColor3 = tier.egg:Lerp(Color3.new(1, 1, 1), 0.2)
	Style.outline(title, 3)
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.fromScale(1, 0.45)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.Text = if requirement then "precisa de ⚡" .. requirement else "qualquer um abre"
	sub.TextColor3 = Color3.new(1, 1, 1)
	Style.outline(sub, 2.5)
	sub.Parent = gui
	gui.Parent = root
end

local function spawnFixedNest(routeId: string, tierIndex: number)
	local zone = zones[routeId]
	local route = Routes.byId[routeId]
	local tier = NEST_TIERS[tierIndex]
	local requirement = nestRequirement(routeId, tier)
	local model, root = buildNode({ nest = true }, route)
	model.Name = "Ninho"
	model:SetAttribute("Requisito", requirement or 0)
	model:SetAttribute("Tipo", tier.name)
	-- Ovo da cor do ninho; o dourado brilha.
	for _, part in model:GetDescendants() do
		if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
			part.Color = tier.egg
			if tier.neon then
				part.Material = Enum.Material.Neon
			end
		end
	end
	local offset = (tierIndex - 2) * NEST_SPACING
	model:PivotTo(CFrame.new(zone.origin + Vector3.new(offset, 0.8, 0)))
	nestSign(root, tier, requirement)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir ninho"
	prompt.ObjectText = tier.name .. (if requirement then " (⚡" .. requirement .. ")" else "")
	prompt.HoldDuration = tier.hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local function fastEnough(player: Player): boolean
		local profile = DataService.get(player)
		return profile ~= nil and (requirement == nil or Balance.walkSpeed(profile) >= requirement)
	end
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if fastEnough(player) then
			GuardianService.alert(player, root.Position, 1)
		end
	end)
	local taken = false
	prompt.Triggered:Connect(function(player)
		local profile = DataService.get(player)
		if taken or not profile or not profile.routes[routeId] then
			return
		end
		if not fastEnough(player) then
			Notify.toast(player, "🔒 Precisa de ⚡" .. requirement .. " para o " .. tier.name .. ". Treine na esteira!", Color3.fromRGB(255, 120, 100))
			return
		end
		taken = true
		model:Destroy()
		collect(player, route, { nest = true }, tier.luck)
		task.delay(tier.respawn, spawnFixedNest, routeId, tierIndex)
	end)
	model.Parent = zone.nodes
end

function RouteService.travel(player: Player, target: string): (boolean, string?)
	if target == "Fazenda" then
		return FarmService.teleportHome(player)
	end
	local route = Routes.byId[target]
	local profile = DataService.get(player)
	if not route or not profile then
		return false, "Rota inválida"
	end
	if not profile.routes[target] then
		return false,
			"🔒 " .. route.name .. ": precisa de " .. Balance.requirementText(target) .. " + 💰 " .. Format.number(
				route.unlockCost
			) .. ". Desbloqueie no menu 🗺️ Rotas"
	end
	Teleport.to(player, zones[target].spawn)
	local species = Species.byId[route.species]
	Notify.big(
		player,
		species.emoji .. " " .. route.name,
		"Colete materiais e procure ninhos de " .. species.name .. "!",
		route.theme
	)
	return true, nil
end

function RouteService.unlock(player: Player, routeId: string): (boolean, string?)
	local profile = DataService.get(player)
	local ok, reason = Balance.canUnlockRoute(profile, profile.coins, routeId)
	if not ok then
		return false, reason
	end
	local route = Routes.byId[routeId]
	if not DataService.spendCoins(player, route.unlockCost) then
		return false, "Moedas insuficientes"
	end
	profile.routes[routeId] = true
	DataService.push(player)
	Notify.big(
		player,
		"🔓 " .. route.name .. " desbloqueada!",
		"Entre no portal ou toque em Ir no menu de rotas",
		route.theme
	)
	return true, nil
end

local function onPortalTouched(hit: BasePart, target: string)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then
		return
	end
	local now = os.clock()
	if lastTouch[player] and now - lastTouch[player] < TOUCH_COOLDOWN then
		return
	end
	lastTouch[player] = now
	local ok, message = RouteService.travel(player, target)
	if not ok and message then
		Notify.toast(player, message, Color3.fromRGB(255, 120, 100))
	end
end

function RouteService.init(zoneMap, portals: { [string]: BasePart })
	zones = zoneMap
	for routeId, zone in zones do
		for _ = 1, Routes.byId[routeId].nodeCount do
			spawnNode(routeId)
		end
		for tierIndex = 1, #NEST_TIERS do
			spawnFixedNest(routeId, tierIndex)
		end
		zone.returnField.Touched:Connect(function(hit)
			onPortalTouched(hit, "Fazenda")
		end)
	end
	for routeId, field in portals do
		field.Touched:Connect(function(hit)
			onPortalTouched(hit, routeId)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTouch[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GOLDEN_INTERVAL)
			Workspace:SetAttribute("GoldenHourEnds", Workspace:GetServerTimeNow() + GOLDEN_DURATION)
			Notify.bigAll("🌟 HORA DOURADA! 🌟", "Sorte x2 e itens raros aparecendo mais por 2 minutos!", GOLD)
		end
	end)
end

return RouteService
