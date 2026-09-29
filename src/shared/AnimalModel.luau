local CollectionService = game:GetService("CollectionService")

local Config = script.Parent.Config
local Rarities = require(Config.Rarities)
local Species = require(Config.Species)
local Style = require(script.Parent.Style)

local AnimalModel = {}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local EYE = Color3.fromRGB(20, 20, 20)
local SHINY_TINT = Color3.fromRGB(255, 225, 120)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

-- Quanto cada raridade puxa a cor das partes para a cor da raridade (índice = raridade).
-- Detalhes (asas, manchas, crina) mudam bastante; o corpo muda pouco para o bicho continuar reconhecível.
local ACCENT_TINT = { 0, 0.55, 0.65, 0.75, 0.85, 0.9 }
local BODY_TINT = { 0, 0.1, 0.18, 0.32, 0.5, 0.3 }
-- Parte com esta tag muda de cor em arco-íris no cliente (ver client/Rainbow).
AnimalModel.RAINBOW_TAG = "Arcoiris"

type PartSpec = {
	size: Vector3,
	at: Vector3,
	color: string | Color3,
	shape: string?,
	rot: CFrame?,
	material: Enum.Material?,
}
type Shape = { parts: { PartSpec }, crown: Vector3, tag: number }

local function rad(deg: number): number
	return math.rad(deg)
end

local function eyes(y: number, z: number, x: number, size: number): { PartSpec }
	return {
		{ size = Vector3.one * size, at = Vector3.new(x, y, z), color = EYE },
		{ size = Vector3.one * size, at = Vector3.new(-x, y, z), color = EYE },
	}
end

local function legs(size: Vector3, x: number, z: number, color: string | Color3): { PartSpec }
	local result = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(result, { size = size, at = Vector3.new(sx * x, size.Y / 2, sz * z), color = color })
		end
	end
	return result
end

local function concat(...: { PartSpec }): { PartSpec }
	local result = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #result + 1, result)
	end
	return result
end

local SHAPES: { [string]: Shape } = {
	ave = {
		crown = Vector3.new(0, 4.4, -0.75),
		tag = 5.6,
		parts = concat({
			{ size = Vector3.new(2.2, 2, 2.6), at = Vector3.new(0, 1.8, 0), color = "body" },
			{
				size = Vector3.new(0.5, 1.2, 0.9),
				at = Vector3.new(0, 2.5, 1.15),
				color = "body",
				rot = CFrame.Angles(rad(-35), 0, 0),
			},
			{ size = Vector3.new(1.4, 1.4, 1.4), at = Vector3.new(0, 3.2, -0.9), color = "body" },
			{ size = Vector3.new(0.45, 0.3, 0.55), at = Vector3.new(0, 3.05, -1.8), color = "beak" },
			{ size = Vector3.new(0.22, 0.55, 0.8), at = Vector3.new(0, 3.95, -0.9), color = "red" },
			{ size = Vector3.new(0.22, 0.4, 0.22), at = Vector3.new(0, 2.7, -1.6), color = "red" },
			{ size = Vector3.new(0.3, 1.0, 1.5), at = Vector3.new(1.15, 1.9, 0.1), color = "accent" },
			{ size = Vector3.new(0.3, 1.0, 1.5), at = Vector3.new(-1.15, 1.9, 0.1), color = "accent" },
			{ size = Vector3.new(0.2, 0.8, 0.2), at = Vector3.new(0.45, 0.4, 0), color = "beak" },
			{ size = Vector3.new(0.2, 0.8, 0.2), at = Vector3.new(-0.45, 0.4, 0), color = "beak" },
		}, eyes(3.35, -1.62, 0.4, 0.28)),
	},
	porco = {
		crown = Vector3.new(0, 2.95, -1.9),
		tag = 4.4,
		parts = concat({
			{ size = Vector3.new(2.2, 1.8, 3.0), at = Vector3.new(0, 1.7, 0), color = "body" },
			{ size = Vector3.new(1.6, 1.5, 1.3), at = Vector3.new(0, 2.05, -1.9), color = "body" },
			{
				size = Vector3.new(0.35, 0.9, 0.9),
				at = Vector3.new(0, 1.85, -2.7),
				color = "accent",
				shape = "Cylinder",
				rot = CFrame.Angles(0, rad(90), 0),
			},
			{
				size = Vector3.new(0.5, 0.5, 0.15),
				at = Vector3.new(0.55, 2.9, -1.85),
				color = "accent",
				rot = CFrame.Angles(rad(-20), 0, rad(-15)),
			},
			{
				size = Vector3.new(0.5, 0.5, 0.15),
				at = Vector3.new(-0.55, 2.9, -1.85),
				color = "accent",
				rot = CFrame.Angles(rad(-20), 0, rad(15)),
			},
			{ size = Vector3.one * 0.4, at = Vector3.new(0, 2.2, 1.6), color = "accent", shape = "Ball" },
		}, eyes(2.4, -2.56, 0.42, 0.22), legs(Vector3.new(0.5, 0.8, 0.5), 0.7, 1.0, "body")),
	},
	vaca = {
		crown = Vector3.new(0, 4.3, -2.6),
		tag = 5.6,
		parts = concat({
			{ size = Vector3.new(2.6, 2.2, 4.0), at = Vector3.new(0, 2.6, 0), color = "body" },
			{ size = Vector3.new(0.1, 1.0, 1.3), at = Vector3.new(1.31, 2.8, 0.5), color = "accent" },
			{ size = Vector3.new(0.1, 0.9, 1.1), at = Vector3.new(-1.31, 2.4, -0.8), color = "accent" },
			{ size = Vector3.new(1.2, 0.1, 1.0), at = Vector3.new(0.3, 3.71, 0.9), color = "accent" },
			{ size = Vector3.new(1.6, 1.6, 1.6), at = Vector3.new(0, 3.3, -2.6), color = "body" },
			{ size = Vector3.new(1.4, 0.8, 0.5), at = Vector3.new(0, 2.85, -3.55), color = "muzzle" },
			{ size = Vector3.new(0.25, 0.6, 0.25), at = Vector3.new(0.6, 4.35, -2.6), color = "horn" },
			{ size = Vector3.new(0.25, 0.6, 0.25), at = Vector3.new(-0.6, 4.35, -2.6), color = "horn" },
			{ size = Vector3.new(0.6, 0.3, 0.2), at = Vector3.new(1.05, 3.7, -2.5), color = "accent" },
			{ size = Vector3.new(0.6, 0.3, 0.2), at = Vector3.new(-1.05, 3.7, -2.5), color = "accent" },
			{
				size = Vector3.one * 0.5,
				at = Vector3.new(0, 2.25, -2.25),
				color = "bell",
				shape = "Ball",
				material = Enum.Material.Metal,
			},
			{ size = Vector3.new(0.2, 1.4, 0.2), at = Vector3.new(0, 2.6, 2.05), color = "accent" },
		}, eyes(3.55, -3.42, 0.45, 0.24), legs(Vector3.new(0.55, 1.5, 0.55), 0.9, 1.4, "body")),
	},
	cavalo = {
		crown = Vector3.new(0, 6.75, -2.7),
		tag = 7.8,
		parts = concat(
			{
				{ size = Vector3.new(2.0, 2.2, 4.4), at = Vector3.new(0, 3.4, 0), color = "body" },
				{
					size = Vector3.new(1.1, 2.4, 1.2),
					at = Vector3.new(0, 4.9, -1.9),
					color = "body",
					rot = CFrame.Angles(rad(-25), 0, 0),
				},
				{ size = Vector3.new(1.0, 1.0, 2.0), at = Vector3.new(0, 6.0, -2.9), color = "body" },
				{
					size = Vector3.new(0.3, 2.4, 0.6),
					at = Vector3.new(0, 5.2, -1.4),
					color = "accent",
					rot = CFrame.Angles(rad(-25), 0, 0),
				},
				{ size = Vector3.new(0.25, 0.5, 0.2), at = Vector3.new(0.3, 6.7, -2.4), color = "body" },
				{ size = Vector3.new(0.25, 0.5, 0.2), at = Vector3.new(-0.3, 6.7, -2.4), color = "body" },
				{
					size = Vector3.new(0.35, 1.9, 0.35),
					at = Vector3.new(0, 3.2, 2.35),
					color = "accent",
					rot = CFrame.Angles(rad(20), 0, 0),
				},
			},
			eyes(6.2, -3.3, 0.52, 0.22),
			legs(Vector3.new(0.5, 2.3, 0.5), 0.7, 1.6, "body"),
			{
				{ size = Vector3.new(0.56, 0.3, 0.56), at = Vector3.new(0.7, 0.15, 1.6), color = "hoof" },
				{ size = Vector3.new(0.56, 0.3, 0.56), at = Vector3.new(-0.7, 0.15, 1.6), color = "hoof" },
				{ size = Vector3.new(0.56, 0.3, 0.56), at = Vector3.new(0.7, 0.15, -1.6), color = "hoof" },
				{ size = Vector3.new(0.56, 0.3, 0.56), at = Vector3.new(-0.7, 0.15, -1.6), color = "hoof" },
			}
		),
	},
}

local function addPart(
	model: Model,
	root: BasePart,
	spec: PartSpec,
	scale: number,
	color: Color3,
	shiny: boolean
): BasePart
	local part = Instance.new("Part")
	part.Size = spec.size * scale
	part.Color = color
	part.Material = spec.material or (if shiny then Enum.Material.Foil else Enum.Material.SmoothPlastic)
	if spec.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(spec.at * scale) * (spec.rot or CFrame.identity)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

local function addCrown(model: Model, root: BasePart, at: Vector3, scale: number, rarityColor: Color3)
	local gold = Color3.fromRGB(255, 200, 40)
	local base = addPart(model, root, { size = Vector3.new(1.0, 0.35, 1.0), at = at, color = gold }, scale, gold, false)
	base.Material = Enum.Material.Metal
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local offset = Vector3.new(math.cos(angle) * 0.38, 0.35, math.sin(angle) * 0.38)
		local spike = addPart(
			model,
			root,
			{ size = Vector3.new(0.2, 0.4, 0.2), at = at + offset, color = gold },
			scale,
			gold,
			false
		)
		spike.Material = Enum.Material.Metal
	end
	local gem = addPart(
		model,
		root,
		{ size = Vector3.one * 0.3, at = at + Vector3.new(0, 0.1, -0.52), color = rarityColor, shape = "Ball" },
		scale,
		rarityColor,
		false
	)
	gem.Material = Enum.Material.Neon
end

local function addSparkles(parent: BasePart, color: Color3, rate: number, spread: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.35 * spread),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = parent
end

-- Anel brilhante no chão com a cor da raridade (a partir de Incomum).
local function addRing(model: Model, root: BasePart, scale: number, rarity: number, color: Color3): BasePart
	local diameter = (3.4 + rarity * 0.5) * scale
	local ring = Instance.new("Part")
	ring.Name = "Anel"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, diameter, diameter)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.CastShadow = false
	ring.CFrame = root.CFrame * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = model
	return ring
end

-- Faíscas de fogo subindo (Lendário e Mítico).
local function addFlames(parent: BasePart, color: Color3, scale: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Chamas"
	emitter.Texture = FIRE_TEXTURE
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 120, 40))
	emitter.LightEmission = 0.9
	emitter.Rate = 10
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new(0.9 * scale, 0)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Parent = parent
end

local function addNameTag(root: BasePart, height: number, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(240, 34)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.Text = text
	label.TextColor3 = color
	Style.outline(label, 2.5)
	label.Parent = gui
	gui.Parent = root
end

-- Monta o modelo com o pivô no chão; o Root é ancorado e as demais peças são soldadas nele,
-- então mover o Root (CFrame/tween) move o animal inteiro.
-- plain = true: sem enfeites de raridade (usado pelos guardiões, que são bichos "selvagens").
function AnimalModel.build(speciesId: string, rarity: number, shiny: boolean, displayName: string, plain: boolean?): Model
	local species = Species.byId[speciesId]
	local shape = SHAPES[species.shape]
	local rarityInfo = Rarities.list[rarity]
	local fancy = not plain
	-- Cada raridade fica bem maior: Mítico = 1,6x o Comum.
	local scale = if fancy then 1 + 0.12 * (rarity - 1) else 1 + 0.07 * (rarity - 1)
	local mythic = fancy and rarity >= Rarities.MAX

	local model = Instance.new("Model")
	model.Name = displayName

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in shape.parts do
		local color: Color3 = if typeof(spec.color) == "Color3"
			then spec.color :: Color3
			else species.palette[spec.color :: string] or Color3.new(1, 0, 1)
		if shiny and spec.color == "body" then
			color = color:Lerp(SHINY_TINT, 0.55)
		end
		local isAccent = spec.color == "accent"
		if fancy and spec.color == "body" then
			color = color:Lerp(rarityInfo.color, BODY_TINT[rarity] or 0)
		elseif fancy and isAccent then
			color = color:Lerp(rarityInfo.color, ACCENT_TINT[rarity] or 0)
		end
		local part = addPart(model, root, spec, scale, color, shiny and spec.color == "body")
		-- Lendário: detalhes brilhando. Mítico: detalhes em arco-íris.
		if fancy and isAccent and rarity >= Rarities.LEGENDARY then
			part.Material = Enum.Material.Neon
		end
		if mythic and (isAccent or spec.color == "body") then
			CollectionService:AddTag(part, AnimalModel.RAINBOW_TAG)
		end
	end

	if fancy and rarity >= 2 then
		local ring = addRing(model, root, scale, rarity, rarityInfo.color)
		if mythic then
			CollectionService:AddTag(ring, AnimalModel.RAINBOW_TAG)
		end
	end
	if fancy and rarity == 3 then
		addSparkles(root, rarityInfo.color, 1.5, scale * 0.8)
	end
	if fancy and rarity >= Rarities.LEGENDARY then
		addFlames(root, rarityInfo.color, scale)
	end

	if fancy and rarity >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarityInfo.color
		light.Range = 8 + rarity
		light.Brightness = 1.2
		light.Parent = root
		addSparkles(root, rarityInfo.color, 2 + (rarity - 4) * 3, scale)
	end
	if fancy and rarity >= Rarities.LEGENDARY then
		addCrown(model, root, shape.crown, scale, rarityInfo.color)
	end
	if shiny then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = SHINY_TINT
		sparkles.Parent = root
	end

	addNameTag(root, shape.tag * scale, displayName, rarityInfo.color)
	return model
end

return AnimalModel
