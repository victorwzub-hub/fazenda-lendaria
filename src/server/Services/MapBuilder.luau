local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Routes = require(Shared.Config.Routes)
local Style = require(Shared.Style)

local MapBuilder = {}

local PLOT_COUNT = 8
local PLOT_RADIUS = 150
local PLOT_SIZE = 70
local PORTAL_RADIUS = 58
local HUB_SIZE = 440
local SAFE_RADIUS = 22

local GRASS = Color3.fromRGB(96, 196, 70)
local SAND = Color3.fromRGB(230, 212, 160)
local WOOD = Color3.fromRGB(150, 105, 65)
local FENCE = Color3.fromRGB(238, 228, 208)
local STONE = Color3.fromRGB(125, 125, 135)

export type Plot = {
	index: number,
	cframe: CFrame,
	spawn: CFrame,
	sign: TextLabel,
	animals: Folder,
	owner: Player?,
}

export type Zone = {
	routeId: string,
	origin: Vector3,
	size: number,
	spawn: CFrame,
	nodes: Folder,
	returnField: BasePart,
	safeCenter: Vector3,
	safeRadius: number,
}

local function rad(deg: number): number
	return math.rad(deg)
end

local function block(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function billboard(adornee: BasePart, size: UDim2, offset: Vector3, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

local function textLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	Style.outline(label, 4)
	label.Parent = parent
	return label
end

local function setupLighting()
	-- Dia claro e colorido: sombra suave e ambiente forte, para nada ficar escuro.
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(95, 95, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 175, 185)
	-- Sombra marcada do sol: é ela que dá volume aos blocos.
	Lighting.ShadowSoftness = 0.15
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.2
		atmosphere.Offset = 0.05
		atmosphere.Color = Color3.fromRGB(205, 228, 255)
		atmosphere.Decay = Color3.fromRGB(140, 175, 230)
		atmosphere.Glare = 0.1
		atmosphere.Haze = 0.4
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("Cor") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "Cor"
		color.Saturation = 0.25
		color.Contrast = 0.06
		color.Brightness = 0.02
		color.Parent = Lighting
	end
end

local function island(parent: Instance, center: Vector3, size: number, color: Color3, material: Enum.Material)
	Workspace.Terrain:FillBlock(
		CFrame.new(center.X, -8, center.Z),
		Vector3.new(size + 700, 12, size + 700),
		Enum.Material.Water
	)
	block(parent, Vector3.new(size + 24, 3, size + 24), CFrame.new(center.X, -2.5, center.Z), SAND, Enum.Material.Sand)
	block(parent, Vector3.new(size, 4, size), CFrame.new(center.X, -2, center.Z), color, material)
end

local function fenceLine(parent: Instance, cframe: CFrame, length: number)
	local posts = math.max(2, math.floor(length / 6) + 1)
	for i = 0, posts - 1 do
		local x = -length / 2 + i * (length / (posts - 1))
		block(parent, Vector3.new(0.6, 3.2, 0.6), cframe * CFrame.new(x, 1.6, 0), FENCE, Enum.Material.WoodPlanks)
	end
	for _, y in { 1.2, 2.4 } do
		block(parent, Vector3.new(length, 0.4, 0.3), cframe * CFrame.new(0, y, 0), FENCE, Enum.Material.WoodPlanks)
	end
end

local function barn(parent: Instance, cframe: CFrame, color: Color3, width: number, depth: number, height: number)
	local roofColor = Color3.fromRGB(95, 55, 45)
	block(
		parent,
		Vector3.new(width, height, depth),
		cframe * CFrame.new(0, height / 2, 0),
		color,
		Enum.Material.WoodPlanks
	)
	local rise = (width / 2) * math.tan(rad(30))
	local panel = (width / 2) / math.cos(rad(30)) + 1
	for _, side in { -1, 1 } do
		block(
			parent,
			Vector3.new(panel, 0.8, depth + 2),
			cframe * CFrame.new(side * width / 4, height + rise / 2 + 0.4, 0) * CFrame.Angles(0, 0, -side * rad(30)),
			roofColor,
			Enum.Material.WoodPlanks
		)
		local gable = Instance.new("WedgePart")
		gable.Anchored = true
		gable.Size = Vector3.new(depth, rise, width / 2)
		gable.CFrame = cframe
			* CFrame.new(side * width / 4, height + rise / 2, 0)
			* CFrame.Angles(0, -side * rad(90), 0)
		gable.Color = color
		gable.Material = Enum.Material.WoodPlanks
		gable.Parent = parent
	end
	block(
		parent,
		Vector3.new(width * 0.35, height * 0.65, 0.3),
		cframe * CFrame.new(0, height * 0.325, -depth / 2 - 0.1),
		Color3.fromRGB(70, 40, 30),
		Enum.Material.WoodPlanks
	)
	-- Acabamento branco: quinas, faixa no alto e moldura da porta.
	local trim = Color3.fromRGB(250, 246, 238)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			block(
				parent,
				Vector3.new(1, height, 1),
				cframe * CFrame.new(x * (width / 2), height / 2, z * (depth / 2)),
				trim,
				Enum.Material.WoodPlanks
			)
		end
	end
	block(
		parent,
		Vector3.new(width + 0.6, 0.8, depth + 0.6),
		cframe * CFrame.new(0, height - 0.4, 0),
		trim,
		Enum.Material.WoodPlanks
	)
	local doorWidth, doorHeight = width * 0.35, height * 0.65
	for _, x in { -1, 1 } do
		block(
			parent,
			Vector3.new(0.7, doorHeight + 0.7, 0.4),
			cframe * CFrame.new(x * (doorWidth / 2 + 0.35), (doorHeight + 0.7) / 2, -depth / 2 - 0.2),
			trim,
			Enum.Material.WoodPlanks
		)
	end
	block(
		parent,
		Vector3.new(doorWidth + 1.4, 0.7, 0.4),
		cframe * CFrame.new(0, doorHeight + 0.35, -depth / 2 - 0.2),
		trim,
		Enum.Material.WoodPlanks
	)
end

-- Árvore de blocos: tronco quadrado e copa de cubos empilhados em dois tons.
local function tree(parent: Instance, position: Vector3, foliage: Color3, rng: Random)
	local base = CFrame.new(position) * CFrame.Angles(0, rad(rng:NextInteger(0, 3) * 90 + rng:NextNumber(-12, 12)), 0)
	local height = math.floor(rng:NextNumber(6, 10))
	local trunk = Style.shade(Color3.fromRGB(150, 85, 40), rng:NextNumber(-0.1, 0.05))
	local dark = Style.shade(foliage, -0.18)
	local light = Style.shade(foliage, 0.12)
	block(parent, Vector3.new(2, height, 2), base * CFrame.new(0, height / 2, 0), trunk, Enum.Material.Wood)

	local width = math.floor(rng:NextNumber(8, 11))
	local top = height + 2
	block(parent, Vector3.new(width, 4, width), base * CFrame.new(0, top, 0), dark, Enum.Material.Grass)
	block(parent, Vector3.new(width - 3, 3, width - 3), base * CFrame.new(0.5, top + 3.5, -0.5), foliage, Enum.Material.Grass)
	block(parent, Vector3.new(width - 6, 2, width - 6), base * CFrame.new(0, top + 6, 0), light, Enum.Material.Grass)
	-- Tufos laterais deixam a silhueta menos "caixa".
	for _ = 1, 2 do
		local side = rng:NextInteger(0, 3) * 90
		local tuft = CFrame.Angles(0, rad(side), 0) * CFrame.new(width / 2, rng:NextNumber(-0.5, 1.5), 0)
		block(parent, Vector3.new(3, 3, 4), base * CFrame.new(0, top, 0) * tuft, foliage, Enum.Material.Grass)
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 170),
	Color3.fromRGB(255, 225, 60),
	Color3.fromRGB(255, 80, 70),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 255, 255),
}

-- Florzinha de blocos: caule, pétalas e miolo.
local function flower(parent: Instance, position: Vector3, rng: Random)
	local base = CFrame.new(position) * CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0)
	local height = rng:NextNumber(1.2, 2)
	decor(block(parent, Vector3.new(0.3, height, 0.3), base * CFrame.new(0, height / 2, 0), Color3.fromRGB(60, 150, 50)))
	local petals = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	decor(block(parent, Vector3.new(1.3, 0.4, 0.5), base * CFrame.new(0, height + 0.2, 0), petals))
	decor(block(parent, Vector3.new(0.5, 0.4, 1.3), base * CFrame.new(0, height + 0.2, 0), petals))
	decor(block(parent, Vector3.new(0.45, 0.5, 0.45), base * CFrame.new(0, height + 0.3, 0), Color3.fromRGB(255, 200, 40)))
end

-- Manchas de grama em outro tom quebram o chão "chapado".
local function patch(parent: Instance, position: Vector3, ground: Color3, rng: Random)
	local size = rng:NextNumber(6, 14)
	local tone = if rng:NextNumber() < 0.5 then -0.1 else 0.08
	decor(
		block(
			parent,
			Vector3.new(size, 0.2, size * rng:NextNumber(0.6, 1)),
			CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0),
			Style.shade(ground, tone),
			Enum.Material.Grass
		)
	)
end

-- Arbusto em degraus, como os dos simuladores.
local function bush(parent: Instance, position: Vector3, foliage: Color3, rng: Random)
	local base = CFrame.new(position) * CFrame.Angles(0, rad(rng:NextNumber(0, 90)), 0)
	local size = rng:NextNumber(4, 6)
	block(parent, Vector3.new(size, 1.6, size), base * CFrame.new(0, 0.8, 0), Style.shade(foliage, -0.15), Enum.Material.Grass)
	block(parent, Vector3.new(size - 1.6, 1.4, size - 1.6), base * CFrame.new(0, 2.3, 0), foliage, Enum.Material.Grass)
	block(parent, Vector3.new(size - 3, 1, size - 3), base * CFrame.new(0, 3.5, 0), Style.shade(foliage, 0.12), Enum.Material.Grass)
end

local function rock(parent: Instance, position: Vector3, rng: Random)
	local size = Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1.5, 3.5), rng:NextNumber(2, 5))
	block(
		parent,
		size,
		CFrame.new(position + Vector3.new(0, size.Y / 2 - 0.3, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), rad(rng:NextNumber(-10, 10))),
		STONE,
		Enum.Material.Slate
	)
end

local function buildPortal(
	parent: Instance,
	name: string,
	cframe: CFrame,
	color: Color3,
	title: string
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	for _, x in { -7, 7 } do
		block(model, Vector3.new(2, 15, 2), cframe * CFrame.new(x, 7.5, 0), STONE, Enum.Material.Slate)
	end
	local beam =
		block(model, Vector3.new(17, 2.4, 2.4), cframe * CFrame.new(0, 15.5, 0), color, Enum.Material.WoodPlanks)
	local field = block(model, Vector3.new(12, 14, 0.5), cframe * CFrame.new(0, 7.5, 0), color, Enum.Material.Neon)
	field.Name = "Campo"
	field.Transparency = 0.45
	field.CanCollide = false

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(0.5, 1)
	emitter.Size = NumberSequence.new(0.4, 0)
	emitter.Parent = field

	local gui = billboard(beam, UDim2.fromScale(28, 8), Vector3.new(0, 6, 0), 260)
	gui.Name = "Rotulo"
	textLabel(gui, "Titulo", title, UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0), Color3.new(1, 1, 1))
	textLabel(gui, "Status", "", UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.58), Color3.fromRGB(255, 235, 150))

	model.PrimaryPart = beam
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = parent
	return model, field
end

local function buildHub(world: Instance): SpawnLocation
	local hub = Instance.new("Model")
	hub.Name = "Centro"
	hub.Parent = world
	island(hub, Vector3.zero, HUB_SIZE, GRASS, Enum.Material.Grass)

	block(
		hub,
		Vector3.new(0.4, 44, 44),
		CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, rad(90)),
		Color3.fromRGB(200, 195, 185),
		Enum.Material.Cobblestone,
		Enum.PartType.Cylinder
	)
	block(
		hub,
		Vector3.new(3, 8, 8),
		CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, rad(90)),
		STONE,
		Enum.Material.Cobblestone,
		Enum.PartType.Cylinder
	)
	decor(
		block(
			hub,
			Vector3.new(0.2, 6.6, 6.6),
			CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, rad(90)),
			Color3.fromRGB(70, 150, 230),
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
	)
	for _, x in { -3.4, 3.4 } do
		block(hub, Vector3.new(0.6, 7, 0.6), CFrame.new(x, 6.5, 0), WOOD, Enum.Material.Wood)
	end
	block(hub, Vector3.new(9, 0.6, 5), CFrame.new(0, 10.2, 0), Color3.fromRGB(180, 60, 50), Enum.Material.WoodPlanks)

	local signAnchor = decor(block(hub, Vector3.one, CFrame.new(0, 44, 0), GRASS))
	signAnchor.Transparency = 1
	local sign = billboard(signAnchor, UDim2.fromScale(44, 9), Vector3.zero, 400)
	textLabel(
		sign,
		"Titulo",
		"🌾 FAZENDA LENDÁRIA 🌾",
		UDim2.fromScale(1, 0.7),
		UDim2.fromScale(0, 0),
		Color3.fromRGB(255, 215, 80)
	)
	textLabel(
		sign,
		"Sub",
		"Explore as rotas • Colete materiais • Evolua seus animais",
		UDim2.fromScale(1, 0.3),
		UDim2.fromScale(0, 0.7),
		Color3.new(1, 1, 1)
	)

	for i = 1, PLOT_COUNT do
		local angle = (i - 0.5) * (2 * math.pi / PLOT_COUNT)
		local length = PLOT_RADIUS - PLOT_SIZE / 2 - 22
		decor(
			block(
				hub,
				Vector3.new(8, 0.2, length),
				CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.1, 22 + length / 2),
				Color3.fromRGB(165, 125, 80),
				Enum.Material.Ground
			)
		)
	end

	-- Árvores entre os lotes e na borda da ilha, arbustos perto dos caminhos.
	local rng = Random.new(2024)
	local hubFoliage = Color3.fromRGB(70, 185, 60)
	for i = 1, PLOT_COUNT do
		local between = i * (2 * math.pi / PLOT_COUNT)
		tree(hub, (CFrame.Angles(0, between, 0) * CFrame.new(0, 0, PLOT_RADIUS)).Position, hubFoliage, rng)
		tree(hub, (CFrame.Angles(0, between + rad(8), 0) * CFrame.new(0, 0, 205)).Position, hubFoliage, rng)
		tree(hub, (CFrame.Angles(0, between - rad(9), 0) * CFrame.new(0, 0, 200)).Position, hubFoliage, rng)
		local path = (i - 0.5) * (2 * math.pi / PLOT_COUNT)
		for _, side in { -1, 1 } do
			bush(hub, (CFrame.Angles(0, path, 0) * CFrame.new(side * 9, 0, 80)).Position, hubFoliage, rng)
		end
		-- Flores na beira do caminho e manchas de grama perto da borda.
		for step = 1, 3 do
			local at = CFrame.Angles(0, path, 0) * CFrame.new(rng:NextNumber(-7, 7), 0, 30 + step * 12)
			flower(hub, at.Position, rng)
		end
		for _ = 1, 3 do
			local angle = between + rad(rng:NextNumber(-18, 18))
			patch(hub, (CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, rng:NextNumber(190, 212))).Position, GRASS, rng)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, 14)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = hub
	return spawn
end

local function buildPlot(parent: Instance, index: number): Plot
	local angle = (index - 0.5) * (2 * math.pi / PLOT_COUNT)
	local cframe = CFrame.Angles(0, angle, 0) * CFrame.new(0, 1, PLOT_RADIUS)
	local half = PLOT_SIZE / 2

	local model = Instance.new("Model")
	model.Name = "Lote" .. index
	model.Parent = parent

	block(
		model,
		Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		cframe * CFrame.new(0, -0.5, 0),
		Color3.fromRGB(118, 208, 78),
		Enum.Material.Grass
	)
	fenceLine(model, cframe * CFrame.new(0, 0, half), PLOT_SIZE)
	fenceLine(model, cframe * CFrame.new(half, 0, 0) * CFrame.Angles(0, rad(90), 0), PLOT_SIZE)
	fenceLine(model, cframe * CFrame.new(-half, 0, 0) * CFrame.Angles(0, rad(90), 0), PLOT_SIZE)
	fenceLine(model, cframe * CFrame.new(-(half + 7) / 2, 0, -half), half - 7)
	fenceLine(model, cframe * CFrame.new((half + 7) / 2, 0, -half), half - 7)

	for _, x in { -7.5, 7.5 } do
		block(model, Vector3.new(1, 9, 1), cframe * CFrame.new(x, 4.5, -half), WOOD, Enum.Material.Wood)
	end
	local beam =
		block(model, Vector3.new(17, 1.5, 1), cframe * CFrame.new(0, 9.5, -half), WOOD, Enum.Material.WoodPlanks)

	barn(model, cframe * CFrame.new(0, 0, 24), Color3.fromRGB(190, 45, 40), 16, 12, 9)
	for _, x in { -26, 26 } do
		block(
			model,
			Vector3.new(4, 3, 3),
			cframe * CFrame.new(x, 1.5, 22),
			Color3.fromRGB(225, 195, 95),
			Enum.Material.Fabric
		)
	end
	block(model, Vector3.new(8, 1.5, 2.5), cframe * CFrame.new(-22, 0.75, -12), WOOD, Enum.Material.WoodPlanks)
	decor(
		block(
			model,
			Vector3.new(7.4, 0.2, 1.9),
			cframe * CFrame.new(-22, 1.45, -12),
			Color3.fromRGB(80, 160, 230),
			Enum.Material.Glass
		)
	)

	local gui = billboard(beam, UDim2.fromScale(18, 3), Vector3.new(0, 2.4, 0), 250)
	local sign =
		textLabel(gui, "Dono", "Fazenda livre", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1))

	local animals = Instance.new("Folder")
	animals.Name = "Animais"
	animals.Parent = model

	return {
		index = index,
		cframe = cframe,
		spawn = cframe * CFrame.new(0, 3, -28) * CFrame.Angles(0, math.pi, 0),
		sign = sign,
		animals = animals,
		owner = nil,
	}
end

local ROUTE_DECOR: { [string]: (Instance, any, Random, (number) -> Vector3) -> () } = {
	Galinheiro = function(parent, route, rng, randomPoint)
		for _ = 1, 4 do
			barn(
				parent,
				CFrame.new(randomPoint(20)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				route.theme,
				8,
				6,
				5
			)
		end
	end,
	Chiqueiro = function(parent, _route, rng, randomPoint)
		for _ = 1, 12 do
			local diameter = rng:NextNumber(10, 20)
			decor(
				block(
					parent,
					Vector3.new(0.3, diameter, diameter),
					CFrame.new(randomPoint(12) + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, rad(90)),
					Color3.fromRGB(85, 60, 40),
					Enum.Material.Mud,
					Enum.PartType.Cylinder
				)
			)
		end
	end,
	Pasto = function(parent, _route, rng, randomPoint)
		local colors = {
			Color3.fromRGB(255, 240, 90),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 130, 200),
			Color3.fromRGB(170, 120, 255),
		}
		for _ = 1, 90 do
			decor(
				block(
					parent,
					Vector3.one * 0.9,
					CFrame.new(randomPoint(4) + Vector3.new(0, 0.4, 0)),
					colors[rng:NextInteger(1, #colors)],
					Enum.Material.SmoothPlastic,
					Enum.PartType.Ball
				)
			)
		end
	end,
	Pradaria = function(parent, _route, rng, randomPoint)
		for _ = 1, 16 do
			block(
				parent,
				Vector3.new(4, 5, 5),
				CFrame.new(randomPoint(8) + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color3.fromRGB(225, 195, 95),
				Enum.Material.Fabric,
				Enum.PartType.Cylinder
			)
		end
		for _ = 1, 6 do
			fenceLine(parent, CFrame.new(randomPoint(20)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), 24)
		end
	end,
}

local function buildZone(parent: Instance, routeId: string, index: number): Zone
	local route = Routes.byId[routeId]
	local origin: Vector3 = route.origin
	local size: number = route.size
	local half = size / 2
	local rng = Random.new(index * 97)

	local model = Instance.new("Model")
	model.Name = routeId
	model.Parent = parent
	island(model, origin, size, route.ground, route.groundMaterial)

	local spawnPosition = origin + Vector3.new(0, 3, half - 24)
	local spawn = CFrame.lookAt(spawnPosition, origin + Vector3.new(0, 3, 0))

	local function randomPoint(margin: number): Vector3
		for _ = 1, 20 do
			local point = origin
				+ Vector3.new(
					rng:NextNumber(-half + margin, half - margin),
					0,
					rng:NextNumber(-half + margin, half - margin)
				)
			if (point - Vector3.new(spawnPosition.X, 0, spawnPosition.Z)).Magnitude > 34 then
				return point
			end
		end
		return origin
	end

	local sign = decor(block(model, Vector3.one, CFrame.new(origin + Vector3.new(0, 30, 0)), route.theme))
	sign.Transparency = 1
	local gui = billboard(sign, UDim2.fromScale(40, 7), Vector3.zero, 500)
	textLabel(
		gui,
		"Titulo",
		route.name,
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		route.theme:Lerp(Color3.new(1, 1, 1), 0.35)
	)

	local _, returnField = buildPortal(
		model,
		"Retorno",
		CFrame.new(origin + Vector3.new(0, 0, half - 8)),
		Color3.fromRGB(110, 205, 110),
		"🏡 Voltar para a Fazenda"
	)
	barn(model, CFrame.new(origin + Vector3.new(-half + 26, 0, half - 26)), route.theme, 18, 14, 10)

	-- Zona segura em volta da chegada e do portal de volta: guardião não entra.
	local safeCenter = origin + Vector3.new(0, 0, half - 18)
	local safe = decor(
		block(
			model,
			Vector3.new(0.3, SAFE_RADIUS * 2, SAFE_RADIUS * 2),
			CFrame.new(safeCenter + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, rad(90)),
			Color3.fromRGB(120, 215, 255),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	)
	safe.Name = "ZonaSegura"
	safe.Transparency = 0.35
	decor(
		block(
			model,
			Vector3.new(0.3, SAFE_RADIUS * 2 + 2, SAFE_RADIUS * 2 + 2),
			CFrame.new(safeCenter + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, rad(90)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	)
	local safeSign = decor(block(model, Vector3.one, CFrame.new(safeCenter + Vector3.new(-SAFE_RADIUS + 4, 9, 0)), GRASS))
	safeSign.Transparency = 1
	textLabel(
		billboard(safeSign, UDim2.fromScale(16, 3.5), Vector3.zero, 160),
		"Titulo",
		"🛡️ ZONA SEGURA",
		UDim2.fromScale(1, 1),
		UDim2.fromScale(0, 0),
		Color3.fromRGB(150, 230, 255)
	)

	-- Trilha de pedras saindo da zona segura para o meio da rota.
	local pathRng = Random.new(index * 31)
	local toCenter = (origin - safeCenter).Unit
	local sideways = Vector3.new(toCenter.Z, 0, -toCenter.X)
	for step = 1, 9 do
		local at = safeCenter + toCenter * (SAFE_RADIUS + step * 5) + sideways * pathRng:NextNumber(-1.2, 1.2)
		decor(
			block(
				model,
				Vector3.new(3.4, 0.4, 3.4),
				CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rad(pathRng:NextNumber(-20, 20)), 0),
				Color3.fromRGB(215, 210, 200),
				Enum.Material.Slate
			)
		)
	end

	local scenery = Instance.new("Folder")
	scenery.Name = "Cenario"
	scenery.Parent = model
	for _ = 1, math.floor(size / 6) do
		tree(scenery, randomPoint(8), route.foliage, rng)
	end
	for _ = 1, math.floor(size / 8) do
		bush(scenery, randomPoint(6), route.foliage, rng)
	end
	for _ = 1, math.floor(size / 5) do
		patch(scenery, randomPoint(8), route.ground, rng)
	end
	for _ = 1, math.floor(size / 4) do
		flower(scenery, randomPoint(4), rng)
	end
	for _ = 1, 18 do
		rock(scenery, randomPoint(6), rng)
	end
	local decorate = ROUTE_DECOR[routeId]
	if decorate then
		decorate(scenery, route, rng, randomPoint)
	end

	local nodes = Instance.new("Folder")
	nodes.Name = "Nos"
	nodes.Parent = model

	return {
		routeId = routeId,
		origin = origin,
		size = size,
		spawn = spawn,
		nodes = nodes,
		returnField = returnField,
		safeCenter = safeCenter,
		safeRadius = SAFE_RADIUS,
	}
end

function MapBuilder.build(): { plots: { Plot }, zones: { [string]: Zone }, portals: { [string]: BasePart } }
	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	setupLighting()

	local world = Instance.new("Folder")
	world.Name = "Mundo"

	buildHub(world)

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Lotes"
	plotFolder.Parent = world
	local plots = {}
	for i = 1, PLOT_COUNT do
		plots[i] = buildPlot(plotFolder, i)
	end

	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "Portais"
	portalFolder.Parent = world
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "Rotas"
	zoneFolder.Parent = world

	local portals = {}
	local zones = {}
	for i, routeId in Routes.order do
		local route = Routes.byId[routeId]
		local angle = (i - 1) * (2 * math.pi / #Routes.order)
		local _, field = buildPortal(
			portalFolder,
			routeId,
			CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, PORTAL_RADIUS),
			route.theme,
			route.name
		)
		portals[routeId] = field
		zones[routeId] = buildZone(zoneFolder, routeId, i)
	end

	Style.apply(world)
	world.Parent = Workspace
	return { plots = plots, zones = zones, portals = portals }
end

return MapBuilder
