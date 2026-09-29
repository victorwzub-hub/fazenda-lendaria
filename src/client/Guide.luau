-- Diz ao jogador o que fazer agora, em poucas palavras, e mostra o caminho:
-- trilha de bolinhas no chão + seta pulando em cima do objetivo, ou seta num botão do menu.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Rarities = require(Shared.Config.Rarities)
local Routes = require(Shared.Config.Routes)
local Style = require(Shared.Style)
local Upgrades = require(Shared.Config.Upgrades)

local State = require(script.Parent.State)
local Hud = require(script.Parent.UI.Hud)

local Guide = {}

local DOT_COUNT = 22
local DOT_SPACING = 4
local DOT_SPEED = 6
local STOP_DISTANCE = 6
local ZONE_MARGIN = 30

local player = Players.LocalPlayer
local target: Vector3? = nil
local dots: { BasePart } = {}
local arrowAnchor: BasePart
local arrowGui: BillboardGui

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function currentZone(position: Vector3): string?
	for _, routeId in Routes.order do
		local route = Routes.byId[routeId]
		local offset = position - route.origin
		local half = route.size / 2 + ZONE_MARGIN
		if math.abs(offset.X) < half and math.abs(offset.Z) < half then
			return routeId
		end
	end
	return nil
end

local function nearestNode(routeId: string, from: Vector3, nestsOnly: boolean, speed: number?): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	local zone = zones and zones:FindFirstChild(routeId)
	local nodes = zone and zone:FindFirstChild("Nos")
	if not nodes then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, node in nodes:GetChildren() do
		local reachable = (node:GetAttribute("Requisito") or 0) <= (speed or math.huge)
		local wanted = if nestsOnly then node.Name == "Ninho" and reachable else node.Name ~= "Ninho"
		if node:IsA("Model") and wanted then
			local position = node:GetPivot().Position
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

local function nearestGuardian(routeId: string, from: Vector3): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	local zone = zones and zones:FindFirstChild(routeId)
	local folder = zone and zone:FindFirstChild("Guardioes")
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, model in (if folder then folder:GetChildren() else {}) do
		if model:IsA("Model") then
			local position = model:GetPivot().Position
			if (position - from).Magnitude < bestDistance then
				best, bestDistance = position, (position - from).Magnitude
			end
		end
	end
	return best
end

local function portalPosition(routeId: string): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local portals = world and world:FindFirstChild("Portais")
	local portal = portals and portals:FindFirstChild(routeId)
	local field = portal and portal:FindFirstChild("Campo")
	return if field then (field :: BasePart).Position else nil
end

local function returnPortalPosition(routeId: string): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	local zone = zones and zones:FindFirstChild(routeId)
	local portal = zone and zone:FindFirstChild("Retorno")
	local field = portal and portal:FindFirstChild("Campo")
	return if field then (field :: BasePart).Position else nil
end

local function safeZonePosition(routeId: string): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	local zone = zones and zones:FindFirstChild(routeId)
	local safe = zone and zone:FindFirstChild("ZonaSegura")
	return if safe then (safe :: BasePart).Position else nil
end

-- Esteira da fazenda deste jogador (a placa do lote tem o nome dele).
local function myTreadmill(): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local lotes = world and world:FindFirstChild("Lotes")
	if not lotes then
		return nil
	end
	for _, lote in lotes:GetChildren() do
		for _, label in lote:GetDescendants() do
			if label:IsA("TextLabel") and label.Name == "Dono" and string.find(label.Text, player.DisplayName, 1, true) then
				local belt = lote:FindFirstChild("Esteira") and lote.Esteira:FindFirstChild("Lona")
				return if belt then (belt :: BasePart).Position else nil
			end
		end
	end
	return nil
end

local function treasurePosition(routeId: string): Vector3?
	local world = Workspace:FindFirstChild("Mundo")
	local zones = world and world:FindFirstChild("Rotas")
	local zone = zones and zones:FindFirstChild(routeId)
	local tree = zone and zone:FindFirstChild("ArvoreDoTesouro")
	local chest = tree and tree:FindFirstChild("Bau")
	return if chest then (chest :: BasePart).Position else nil
end

-- Materiais guardados + o que está na cesta: "se eu levar isso para casa, dá para evoluir?".
local function withBasket(profile)
	local ok, basket = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("CestaItens") or "{}")
	if not ok or type(basket) ~= "table" or next(basket) == nil then
		return profile
	end
	local merged = table.clone(profile.materials)
	for materialId, amount in basket do
		merged[materialId] = (merged[materialId] or 0) + amount
	end
	return setmetatable({ materials = merged }, { __index = profile })
end

local function canEvolveSomething(profile, coins: number): boolean
	for _, animal in profile.animals do
		if animal.rarity < Rarities.MAX then
			local cost = Balance.evolveCost(animal.species, animal.rarity)
			if cost and Balance.missingForCost(profile, coins, cost) then
				return true
			end
		end
	end
	return false
end

local function canUnlockNextRoute(profile, coins: number): boolean
	for _, routeId in Routes.order do
		if not profile.routes[routeId] then
			return (Balance.canUnlockRoute(profile, coins, routeId))
		end
	end
	return false
end

local function bestUnlockedRoute(profile): string
	local best = Routes.order[1]
	for _, routeId in Routes.order do
		if profile.routes[routeId] then
			best = routeId
		end
	end
	return best
end

-- Decide o próximo passo: texto curtinho + um botão OU um lugar no mapa.
function Guide.update()
	local profile = State.profile
	local root = rootPart()
	if not profile or not root then
		return
	end
	local coins = State.coins()
	local zone = currentZone(root.Position)

	local text: string
	local button: string? = nil
	local place: Vector3? = nil
	local chaser = player:GetAttribute("Perseguido")
	local hint = player:GetAttribute("MissaoDica")
	local mission = player:GetAttribute("MissaoTexto") or ""
	local missionUpgrade = player:GetAttribute("MissaoUpgrade")
	local basket = player:GetAttribute("Cesta") or 0
	local basketFull = basket >= (player:GetAttribute("CestaMax") or math.huge)
	if player:GetAttribute("NaEsteira") then
		local points = player:GetAttribute("Treino") or 0
		if points >= (player:GetAttribute("TreinoMax") or math.huge) then
			text = "🏃 Treino completo! Velocidade máxima"
		else
			text = "🏃 Treinando! " .. (points % Balance.TRAIN_PER_SPEED) .. "/" .. Balance.TRAIN_PER_SPEED .. " para +1 velocidade"
		end
	elseif chaser then
		text = "🏃 Fuja para a zona segura ou 👊 bata (F)!"
		place = if zone then safeZonePosition(zone) else nil
	elseif zone and basketFull then
		text, place = "🧺 Cesta cheia! Volte para casa!", returnPortalPosition(zone)
	elseif zone and basket > 0 and not canEvolveSomething(profile, coins) and canEvolveSomething(withBasket(profile), coins) then
		text, place = "🧺 Leve a cesta para casa!", returnPortalPosition(zone)
	elseif hint == "esteira" and not zone then
		text, place = "🏃 " .. mission, myTreadmill()
	elseif hint == "loja" and missionUpgrade and coins >= Upgrades.cost(missionUpgrade, profile.upgrades[missionUpgrade] or 0) then
		text, button = "🛒 " .. mission, "Loja"
	elseif hint == "tesouro" and zone then
		text, place = "💎 Suba até o baú no topo da árvore!", treasurePosition(zone)
	elseif canEvolveSomething(profile, coins) then
		text, button = "⬆️ Evolua seu animal!", "Animais"
	elseif canUnlockNextRoute(profile, coins) then
		text, button = "🗺️ Libere uma rota nova!", "Rotas"
	elseif zone then
		-- Dentro da rota o guia segue o que a missão pede.
		local stat = player:GetAttribute("MissaoStat")
		local nest = nearestNode(zone, root.Position, true, Balance.walkSpeed(profile))
		local guardian = if type(stat) == "string" and string.sub(stat, 1, 3) == "ko_" then nearestGuardian(zone, root.Position) else nil
		if guardian then
			text, place = "👊 Bata no bicho 3 vezes (F)!", guardian
		elseif stat == "collected" or not nest then
			text, place = "✨ Colete os itens!", nearestNode(zone, root.Position, false)
		else
			text, place = "🥚 Abra o ninho!", nest
		end
	else
		text, place = "🌀 Entre no portal!", portalPosition(bestUnlockedRoute(profile))
	end

	Hud.setObjective(text)
	Hud.point(button)
	target = place
end

local function makeDot(parent: Instance): BasePart
	local dot = Instance.new("Part")
	dot.Name = "Trilha"
	-- Disco branco deitado no chão (sem Neon: com o Bloom ele virava uma bola de luz).
	dot.Shape = Enum.PartType.Cylinder
	dot.Size = Vector3.new(0.2, 1.8, 1.8)
	dot.Material = Enum.Material.SmoothPlastic
	dot.Color = Color3.new(1, 1, 1)
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false
	dot.CanTouch = false
	dot.CastShadow = false
	dot.Parent = parent
	return dot
end

local function render()
	local root = rootPart()
	local goal = target
	local show = root ~= nil and goal ~= nil
	arrowGui.Enabled = show
	if not show then
		for _, dot in dots do
			dot.Transparency = 1
		end
		return
	end
	local from = (root :: BasePart).Position - Vector3.new(0, 2.4, 0)
	local to = goal :: Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local distance = flat.Magnitude
	local direction = if distance > 0 then flat.Unit else Vector3.zero
	local phase = (os.clock() * DOT_SPEED) % DOT_SPACING

	for i, dot in dots do
		local along = i * DOT_SPACING - phase
		if along > 0 and along < distance - STOP_DISTANCE then
			local height = from.Y + (to.Y - from.Y) * math.clamp(along / distance, 0, 1)
			dot.CFrame = CFrame.new(Vector3.new(from.X, height, from.Z) + direction * along)
				* CFrame.Angles(0, 0, math.rad(90))
			-- Some aos poucos perto do jogador e no fim da trilha.
			dot.Transparency = math.clamp(1 - along / 6, 0, 0.8) + math.clamp((i - DOT_COUNT + 4) / 5, 0, 1)
		else
			dot.Transparency = 1
		end
	end

	arrowAnchor.Position = to + Vector3.new(0, 7 + math.abs(math.sin(os.clock() * 4)) * 2.5, 0)
end

function Guide.start()
	local folder = Instance.new("Folder")
	folder.Name = "Guia"
	folder.Parent = Workspace.CurrentCamera

	for i = 1, DOT_COUNT do
		dots[i] = makeDot(folder)
	end

	arrowAnchor = Instance.new("Part")
	arrowAnchor.Name = "SetaAlvo"
	arrowAnchor.Anchored = true
	arrowAnchor.CanCollide = false
	arrowAnchor.CanQuery = false
	arrowAnchor.CanTouch = false
	arrowAnchor.Transparency = 1
	arrowAnchor.Size = Vector3.one
	arrowAnchor.Parent = folder

	arrowGui = Instance.new("BillboardGui")
	arrowGui.Size = UDim2.fromScale(6, 6)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.Enabled = false
	arrowGui.Parent = arrowAnchor
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(255, 220, 60)
	Style.outline(arrow, 4)
	arrow.Parent = arrowGui

	RunService.RenderStepped:Connect(render)
end

return Guide
