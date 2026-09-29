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
AnimalModel.ANIMATED_TAG = "Bicho"

-- g = grupo da junta (Motor6D) que o cliente anima (ver client/AnimalAnimator):
--   "head" (cabeça/pescoço), "tail" (rabo), "wingL"/"wingR" (asas),
--   "legFL"/"legFR"/"legBL"/"legBR" (patas) ou "legL"/"legR" (aves).
-- O pivô da junta de cada pata é o topo da primeira peça do grupo; os outros vêm de `joints`.
type PartSpec = {
	size: Vector3,
	at: Vector3,
	color: string | Color3,
	shape: string?,
	rot: CFrame?,
	material: Enum.Material?,
	g: string?,
}
type Shape = { parts: { PartSpec }, crown: Vector3, tag: number, joints: { [string]: Vector3 }, pet: number }

local function rad(deg: number): number
	return math.rad(deg)
end

local function eyes(y: number, z: number, x: number, size: number, color: (string | Color3)?): { PartSpec }
	return {
		{ size = Vector3.one * size, at = Vector3.new(x, y, z), color = color or EYE, g = "head" },
		{ size = Vector3.one * size, at = Vector3.new(-x, y, z), color = color or EYE, g = "head" },
	}
end

-- Quatro patas; a da frente fica no -Z.
local function legs(size: Vector3, x: number, z: number, color: string | Color3): { PartSpec }
	local result = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local group = "leg" .. (if sz < 0 then "F" else "B") .. (if sx < 0 then "L" else "R")
			table.insert(result, { size = size, at = Vector3.new(sx * x, size.Y / 2, sz * z), color = color, g = group })
		end
	end
	return result
end

-- Cascos na ponta das patas (mesmo grupo: vêm depois das patas, então usam o pivô delas).
local function hooves(size: Vector3, x: number, z: number, color: string | Color3): { PartSpec }
	local result = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local group = "leg" .. (if sz < 0 then "F" else "B") .. (if sx < 0 then "L" else "R")
			table.insert(result, { size = size, at = Vector3.new(sx * x, size.Y / 2, sz * z), color = color, g = group })
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

-- Leque do peru: placas em arco atrás do corpo.
local function fan(center: Vector3): { PartSpec }
	local result = {}
	for i = -3, 3 do
		local angle = rad(i * 22)
		local rot = CFrame.Angles(0, 0, angle)
		local offset = (rot * CFrame.new(0, 1.7, 0)).Position
		table.insert(result, {
			size = Vector3.new(0.9, 3.2, 0.25),
			at = center + offset,
			rot = rot,
			color = if i % 2 == 0 then "accent" else "tip",
			g = "tail",
		})
	end
	return result
end

local SHAPES: { [string]: Shape } = {
	ave = {
		crown = Vector3.new(0, 4.4, -0.75),
		tag = 5.6,
		pet = 0.75,
		joints = {
			head = Vector3.new(0, 2.6, -0.8),
			tail = Vector3.new(0, 2.3, 0.8),
			wingL = Vector3.new(-1.05, 2.35, 0.1),
			wingR = Vector3.new(1.05, 2.35, 0.1),
		},
		parts = concat({
			{ size = Vector3.new(0.2, 0.8, 0.2), at = Vector3.new(0.45, 0.4, 0), color = "beak", g = "legR" },
			{ size = Vector3.new(0.2, 0.8, 0.2), at = Vector3.new(-0.45, 0.4, 0), color = "beak", g = "legL" },
			{ size = Vector3.new(2.2, 2, 2.6), at = Vector3.new(0, 1.8, 0), color = "body" },
			{
				size = Vector3.new(0.5, 1.2, 0.9),
				at = Vector3.new(0, 2.5, 1.15),
				color = "body",
				rot = CFrame.Angles(rad(-35), 0, 0),
				g = "tail",
			},
			{ size = Vector3.new(1.4, 1.4, 1.4), at = Vector3.new(0, 3.2, -0.9), color = "body", g = "head" },
			{ size = Vector3.new(0.45, 0.3, 0.55), at = Vector3.new(0, 3.05, -1.8), color = "beak", g = "head" },
			{ size = Vector3.new(0.22, 0.55, 0.8), at = Vector3.new(0, 3.95, -0.9), color = "red", g = "head" },
			{ size = Vector3.new(0.22, 0.4, 0.22), at = Vector3.new(0, 2.7, -1.6), color = "red", g = "head" },
			{ size = Vector3.new(0.3, 1.0, 1.5), at = Vector3.new(1.15, 1.9, 0.1), color = "accent", g = "wingR" },
			{ size = Vector3.new(0.3, 1.0, 1.5), at = Vector3.new(-1.15, 1.9, 0.1), color = "accent", g = "wingL" },
		}, eyes(3.35, -1.62, 0.4, 0.28)),
	},
	pato = {
		crown = Vector3.new(0, 4.2, -1.1),
		tag = 5.2,
		pet = 0.75,
		joints = {
			head = Vector3.new(0, 2.1, -0.8),
			tail = Vector3.new(0, 1.9, 1.2),
			wingL = Vector3.new(-1.15, 2.1, 0.2),
			wingR = Vector3.new(1.15, 2.1, 0.2),
		},
		parts = concat({
			{ size = Vector3.new(0.22, 0.7, 0.22), at = Vector3.new(0.5, 0.35, 0.1), color = "beak", g = "legR" },
			{ size = Vector3.new(0.22, 0.7, 0.22), at = Vector3.new(-0.5, 0.35, 0.1), color = "beak", g = "legL" },
			{ size = Vector3.new(0.7, 0.14, 0.8), at = Vector3.new(0.5, 0.07, -0.15), color = "beak", g = "legR" },
			{ size = Vector3.new(0.7, 0.14, 0.8), at = Vector3.new(-0.5, 0.07, -0.15), color = "beak", g = "legL" },
			{ size = Vector3.new(2.4, 1.6, 2.8), at = Vector3.new(0, 1.5, 0.1), color = "body" },
			{
				size = Vector3.new(0.9, 0.6, 0.7),
				at = Vector3.new(0, 2.1, 1.55),
				color = "body",
				rot = CFrame.Angles(rad(30), 0, 0),
				g = "tail",
			},
			{ size = Vector3.new(0.9, 1.3, 0.9), at = Vector3.new(0, 2.6, -1.0), color = "head", g = "head" },
			{ size = Vector3.new(1.2, 1.2, 1.3), at = Vector3.new(0, 3.4, -1.1), color = "head", g = "head" },
			{ size = Vector3.new(0.95, 0.25, 0.95), at = Vector3.new(0, 3.12, -2.1), color = "beak", g = "head" },
			{ size = Vector3.new(0.3, 0.9, 1.7), at = Vector3.new(1.25, 1.7, 0.2), color = "accent", g = "wingR" },
			{ size = Vector3.new(0.3, 0.9, 1.7), at = Vector3.new(-1.25, 1.7, 0.2), color = "accent", g = "wingL" },
		}, eyes(3.55, -1.76, 0.42, 0.22)),
	},
	peru = {
		crown = Vector3.new(0, 4.75, -1.3),
		tag = 6.4,
		pet = 0.65,
		joints = {
			head = Vector3.new(0, 2.9, -1.1),
			tail = Vector3.new(0, 2.4, 1.3),
			wingL = Vector3.new(-1.25, 2.7, 0.2),
			wingR = Vector3.new(1.25, 2.7, 0.2),
		},
		parts = concat({
			{ size = Vector3.new(0.25, 0.9, 0.25), at = Vector3.new(0.55, 0.45, 0.1), color = "beak", g = "legR" },
			{ size = Vector3.new(0.25, 0.9, 0.25), at = Vector3.new(-0.55, 0.45, 0.1), color = "beak", g = "legL" },
			{ size = Vector3.new(2.6, 2.4, 2.8), at = Vector3.new(0, 2.0, 0.1), color = "body" },
			{ size = Vector3.new(0.6, 1.4, 0.6), at = Vector3.new(0, 3.3, -1.2), color = "skin", g = "head" },
			{ size = Vector3.new(0.9, 0.9, 0.9), at = Vector3.new(0, 4.1, -1.3), color = "skin", g = "head" },
			{ size = Vector3.new(0.3, 0.25, 0.4), at = Vector3.new(0, 4.0, -1.9), color = "beak", g = "head" },
			{ size = Vector3.new(0.2, 0.7, 0.2), at = Vector3.new(0.05, 3.6, -1.78), color = "red", g = "head" },
			{ size = Vector3.new(0.3, 1.4, 1.8), at = Vector3.new(1.35, 2.1, 0.2), color = "accent", g = "wingR" },
			{ size = Vector3.new(0.3, 1.4, 1.8), at = Vector3.new(-1.35, 2.1, 0.2), color = "accent", g = "wingL" },
		}, fan(Vector3.new(0, 2.4, 1.6)), eyes(4.25, -1.76, 0.3, 0.18)),
	},
	porco = {
		crown = Vector3.new(0, 2.95, -1.9),
		tag = 4.4,
		pet = 0.8,
		joints = {
			head = Vector3.new(0, 2.0, -1.3),
			tail = Vector3.new(0, 2.2, 1.5),
		},
		parts = concat(legs(Vector3.new(0.5, 0.8, 0.5), 0.7, 1.0, "body"), {
			{ size = Vector3.new(2.2, 1.8, 3.0), at = Vector3.new(0, 1.7, 0), color = "body" },
			{ size = Vector3.new(1.6, 1.5, 1.3), at = Vector3.new(0, 2.05, -1.9), color = "body", g = "head" },
			{
				size = Vector3.new(0.35, 0.9, 0.9),
				at = Vector3.new(0, 1.85, -2.7),
				color = "accent",
				shape = "Cylinder",
				rot = CFrame.Angles(0, rad(90), 0),
				g = "head",
			},
			{
				size = Vector3.new(0.5, 0.5, 0.15),
				at = Vector3.new(0.55, 2.9, -1.85),
				color = "accent",
				rot = CFrame.Angles(rad(-20), 0, rad(-15)),
				g = "head",
			},
			{
				size = Vector3.new(0.5, 0.5, 0.15),
				at = Vector3.new(-0.55, 2.9, -1.85),
				color = "accent",
				rot = CFrame.Angles(rad(-20), 0, rad(15)),
				g = "head",
			},
			{ size = Vector3.one * 0.4, at = Vector3.new(0, 2.2, 1.6), color = "accent", shape = "Ball", g = "tail" },
		}, eyes(2.4, -2.56, 0.42, 0.22)),
	},
	javali = {
		crown = Vector3.new(0, 3.1, -2.0),
		tag = 4.7,
		pet = 0.75,
		joints = {
			head = Vector3.new(0, 2.1, -1.3),
			tail = Vector3.new(0, 2.6, 1.6),
		},
		parts = concat(legs(Vector3.new(0.55, 0.9, 0.55), 0.75, 1.1, "accent"), {
			{ size = Vector3.new(2.2, 2.0, 3.2), at = Vector3.new(0, 1.9, 0), color = "body" },
			{ size = Vector3.new(0.6, 0.6, 2.8), at = Vector3.new(0, 3.1, 0.1), color = "accent" },
			{ size = Vector3.new(1.5, 1.4, 1.5), at = Vector3.new(0, 2.1, -2.0), color = "body", g = "head" },
			{ size = Vector3.new(1.0, 0.8, 0.8), at = Vector3.new(0, 1.8, -2.9), color = "muzzle", g = "head" },
			{ size = Vector3.new(0.9, 0.6, 0.15), at = Vector3.new(0, 1.8, -3.32), color = "nose", g = "head" },
			{
				size = Vector3.new(0.2, 0.7, 0.2),
				at = Vector3.new(0.5, 1.75, -3.05),
				color = "tusk",
				rot = CFrame.Angles(rad(-25), 0, rad(-15)),
				g = "head",
			},
			{
				size = Vector3.new(0.2, 0.7, 0.2),
				at = Vector3.new(-0.5, 1.75, -3.05),
				color = "tusk",
				rot = CFrame.Angles(rad(-25), 0, rad(15)),
				g = "head",
			},
			{ size = Vector3.new(0.4, 0.5, 0.2), at = Vector3.new(0.5, 2.95, -1.8), color = "accent", g = "head" },
			{ size = Vector3.new(0.4, 0.5, 0.2), at = Vector3.new(-0.5, 2.95, -1.8), color = "accent", g = "head" },
			{
				size = Vector3.new(0.2, 0.9, 0.2),
				at = Vector3.new(0, 2.2, 1.75),
				color = "accent",
				rot = CFrame.Angles(rad(25), 0, 0),
				g = "tail",
			},
		}, eyes(2.45, -2.76, 0.42, 0.22)),
	},
	bode = {
		crown = Vector3.new(0, 4.05, -1.9),
		tag = 5.6,
		pet = 0.7,
		joints = {
			head = Vector3.new(0, 3.0, -1.4),
			tail = Vector3.new(0, 3.1, 1.45),
		},
		parts = concat(legs(Vector3.new(0.4, 1.6, 0.4), 0.6, 1.1, "body"), {
			{ size = Vector3.new(1.8, 1.6, 3.0), at = Vector3.new(0, 2.4, 0), color = "body" },
			{ size = Vector3.new(1.1, 1.1, 1.4), at = Vector3.new(0, 3.3, -1.9), color = "body", g = "head" },
			{ size = Vector3.new(0.8, 0.6, 0.6), at = Vector3.new(0, 3.0, -2.7), color = "muzzle", g = "head" },
			{
				size = Vector3.new(0.25, 1.1, 0.25),
				at = Vector3.new(0.3, 4.2, -1.55),
				color = "horn",
				rot = CFrame.Angles(rad(-35), 0, 0),
				g = "head",
			},
			{
				size = Vector3.new(0.25, 1.1, 0.25),
				at = Vector3.new(-0.3, 4.2, -1.55),
				color = "horn",
				rot = CFrame.Angles(rad(-35), 0, 0),
				g = "head",
			},
			{ size = Vector3.new(0.3, 0.7, 0.3), at = Vector3.new(0, 2.45, -2.55), color = "accent", g = "head" },
			{ size = Vector3.new(0.6, 0.25, 0.3), at = Vector3.new(0.75, 3.4, -1.8), color = "body", g = "head" },
			{ size = Vector3.new(0.6, 0.25, 0.3), at = Vector3.new(-0.75, 3.4, -1.8), color = "body", g = "head" },
			{
				size = Vector3.new(0.3, 0.6, 0.25),
				at = Vector3.new(0, 3.35, 1.55),
				color = "accent",
				rot = CFrame.Angles(rad(30), 0, 0),
				g = "tail",
			},
		}, eyes(3.5, -2.62, 0.4, 0.2)),
	},
	vaca = {
		crown = Vector3.new(0, 4.3, -2.6),
		tag = 5.6,
		pet = 0.6,
		joints = {
			head = Vector3.new(0, 3.2, -1.9),
			tail = Vector3.new(0, 3.3, 2.05),
		},
		parts = concat(legs(Vector3.new(0.55, 1.5, 0.55), 0.9, 1.4, "body"), {
			{ size = Vector3.new(2.6, 2.2, 4.0), at = Vector3.new(0, 2.6, 0), color = "body" },
			{ size = Vector3.new(0.1, 1.0, 1.3), at = Vector3.new(1.31, 2.8, 0.5), color = "accent" },
			{ size = Vector3.new(0.1, 0.9, 1.1), at = Vector3.new(-1.31, 2.4, -0.8), color = "accent" },
			{ size = Vector3.new(1.2, 0.1, 1.0), at = Vector3.new(0.3, 3.71, 0.9), color = "accent" },
			{ size = Vector3.new(1.6, 1.6, 1.6), at = Vector3.new(0, 3.3, -2.6), color = "body", g = "head" },
			{ size = Vector3.new(1.4, 0.8, 0.5), at = Vector3.new(0, 2.85, -3.55), color = "muzzle", g = "head" },
			{ size = Vector3.new(0.25, 0.6, 0.25), at = Vector3.new(0.6, 4.35, -2.6), color = "horn", g = "head" },
			{ size = Vector3.new(0.25, 0.6, 0.25), at = Vector3.new(-0.6, 4.35, -2.6), color = "horn", g = "head" },
			{ size = Vector3.new(0.6, 0.3, 0.2), at = Vector3.new(1.05, 3.7, -2.5), color = "accent", g = "head" },
			{ size = Vector3.new(0.6, 0.3, 0.2), at = Vector3.new(-1.05, 3.7, -2.5), color = "accent", g = "head" },
			{
				size = Vector3.one * 0.5,
				at = Vector3.new(0, 2.25, -2.25),
				color = "bell",
				shape = "Ball",
				material = Enum.Material.Metal,
				g = "head",
			},
			{ size = Vector3.new(0.2, 1.4, 0.2), at = Vector3.new(0, 2.6, 2.05), color = "accent", g = "tail" },
		}, eyes(3.55, -3.42, 0.45, 0.24)),
	},
	ovelha = {
		crown = Vector3.new(0, 4.35, -1.6),
		tag = 5.2,
		pet = 0.7,
		joints = {
			head = Vector3.new(0, 2.7, -1.2),
			tail = Vector3.new(0, 2.4, 1.7),
		},
		parts = concat(legs(Vector3.new(0.35, 1.3, 0.35), 0.6, 0.8, "accent"), {
			{ size = Vector3.one * 2.6, at = Vector3.new(0, 2.3, 0), color = "body", shape = "Ball" },
			{ size = Vector3.one * 1.9, at = Vector3.new(0.8, 2.4, 0.8), color = "body", shape = "Ball" },
			{ size = Vector3.one * 1.9, at = Vector3.new(-0.8, 2.4, 0.8), color = "body", shape = "Ball" },
			{ size = Vector3.one * 1.9, at = Vector3.new(0.8, 2.4, -0.7), color = "body", shape = "Ball" },
			{ size = Vector3.one * 1.9, at = Vector3.new(-0.8, 2.4, -0.7), color = "body", shape = "Ball" },
			{ size = Vector3.one * 2.0, at = Vector3.new(0, 3.1, 0.1), color = "body", shape = "Ball" },
			{ size = Vector3.one * 1.7, at = Vector3.new(0, 2.3, 1.3), color = "body", shape = "Ball" },
			{ size = Vector3.new(1.0, 1.2, 1.1), at = Vector3.new(0, 2.9, -1.75), color = "accent", g = "head" },
			{ size = Vector3.one * 1.0, at = Vector3.new(0, 3.6, -1.6), color = "body", shape = "Ball", g = "head" },
			{ size = Vector3.new(0.6, 0.25, 0.3), at = Vector3.new(0.65, 3.1, -1.6), color = "accent", g = "head" },
			{ size = Vector3.new(0.6, 0.25, 0.3), at = Vector3.new(-0.65, 3.1, -1.6), color = "accent", g = "head" },
			{ size = Vector3.one * 0.8, at = Vector3.new(0, 2.5, 2.0), color = "body", shape = "Ball", g = "tail" },
		}, eyes(3.05, -2.3, 0.3, 0.22, "eye")),
	},
	coelho = {
		crown = Vector3.new(0, 2.95, -0.55),
		tag = 4.6,
		pet = 0.85,
		joints = {
			head = Vector3.new(0, 1.8, -0.6),
			tail = Vector3.new(0, 1.4, 1.2),
		},
		parts = concat({
			{ size = Vector3.new(0.35, 0.6, 0.35), at = Vector3.new(-0.4, 0.3, -0.5), color = "body", g = "legFL" },
			{ size = Vector3.new(0.35, 0.6, 0.35), at = Vector3.new(0.4, 0.3, -0.5), color = "body", g = "legFR" },
			{ size = Vector3.new(0.45, 0.5, 1.0), at = Vector3.new(-0.55, 0.25, 0.7), color = "body", g = "legBL" },
			{ size = Vector3.new(0.45, 0.5, 1.0), at = Vector3.new(0.55, 0.25, 0.7), color = "body", g = "legBR" },
			{ size = Vector3.new(1.6, 1.5, 2.0), at = Vector3.new(0, 1.2, 0.2), color = "body" },
			{ size = Vector3.new(1.2, 1.2, 1.2), at = Vector3.new(0, 2.2, -0.9), color = "body", g = "head" },
			{
				size = Vector3.new(0.4, 1.6, 0.2),
				at = Vector3.new(0.3, 3.5, -0.9),
				color = "body",
				rot = CFrame.Angles(0, 0, rad(-10)),
				g = "head",
			},
			{
				size = Vector3.new(0.4, 1.6, 0.2),
				at = Vector3.new(-0.3, 3.5, -0.9),
				color = "body",
				rot = CFrame.Angles(0, 0, rad(10)),
				g = "head",
			},
			{
				size = Vector3.new(0.22, 1.2, 0.05),
				at = Vector3.new(0.31, 3.5, -1.02),
				color = "accent",
				rot = CFrame.Angles(0, 0, rad(-10)),
				g = "head",
			},
			{
				size = Vector3.new(0.22, 1.2, 0.05),
				at = Vector3.new(-0.31, 3.5, -1.02),
				color = "accent",
				rot = CFrame.Angles(0, 0, rad(10)),
				g = "head",
			},
			{ size = Vector3.new(0.3, 0.22, 0.1), at = Vector3.new(0, 2.15, -1.52), color = "accent", g = "head" },
			{ size = Vector3.one * 0.7, at = Vector3.new(0, 1.4, 1.3), color = "tail", shape = "Ball", g = "tail" },
		}, eyes(2.4, -1.5, 0.35, 0.2)),
	},
	cavalo = {
		crown = Vector3.new(0, 6.75, -2.7),
		tag = 7.8,
		pet = 0.5,
		joints = {
			head = Vector3.new(0, 4.0, -1.5),
			tail = Vector3.new(0, 4.2, 2.2),
		},
		parts = concat(
			legs(Vector3.new(0.5, 2.3, 0.5), 0.7, 1.6, "body"),
			hooves(Vector3.new(0.56, 0.3, 0.56), 0.7, 1.6, "hoof"),
			{
				{ size = Vector3.new(2.0, 2.2, 4.4), at = Vector3.new(0, 3.4, 0), color = "body" },
				{
					size = Vector3.new(1.1, 2.4, 1.2),
					at = Vector3.new(0, 4.9, -1.9),
					color = "body",
					rot = CFrame.Angles(rad(-25), 0, 0),
					g = "head",
				},
				{ size = Vector3.new(1.0, 1.0, 2.0), at = Vector3.new(0, 6.0, -2.9), color = "body", g = "head" },
				{
					size = Vector3.new(0.3, 2.4, 0.6),
					at = Vector3.new(0, 5.2, -1.4),
					color = "accent",
					rot = CFrame.Angles(rad(-25), 0, 0),
					g = "head",
				},
				{ size = Vector3.new(0.25, 0.5, 0.2), at = Vector3.new(0.3, 6.7, -2.4), color = "body", g = "head" },
				{ size = Vector3.new(0.25, 0.5, 0.2), at = Vector3.new(-0.3, 6.7, -2.4), color = "body", g = "head" },
				{
					size = Vector3.new(0.35, 1.9, 0.35),
					at = Vector3.new(0, 3.2, 2.35),
					color = "accent",
					rot = CFrame.Angles(rad(20), 0, 0),
					g = "tail",
				},
			},
			eyes(6.2, -3.3, 0.52, 0.22)
		),
	},
	burro = {
		crown = Vector3.new(0, 5.2, -2.4),
		tag = 6.6,
		pet = 0.55,
		joints = {
			head = Vector3.new(0, 3.3, -1.3),
			tail = Vector3.new(0, 3.3, 1.7),
		},
		parts = concat(
			legs(Vector3.new(0.45, 1.8, 0.45), 0.6, 1.3, "body"),
			hooves(Vector3.new(0.5, 0.25, 0.5), 0.6, 1.3, "hoof"),
			{
				{ size = Vector3.new(1.8, 1.8, 3.4), at = Vector3.new(0, 2.7, 0), color = "body" },
				{
					size = Vector3.new(0.9, 1.8, 1.0),
					at = Vector3.new(0, 3.8, -1.6),
					color = "body",
					rot = CFrame.Angles(rad(-25), 0, 0),
					g = "head",
				},
				{ size = Vector3.new(0.9, 0.9, 1.7), at = Vector3.new(0, 4.6, -2.4), color = "body", g = "head" },
				{ size = Vector3.new(0.95, 0.7, 0.6), at = Vector3.new(0, 4.4, -3.2), color = "muzzle", g = "head" },
				{
					size = Vector3.new(0.3, 1.4, 0.35),
					at = Vector3.new(0.35, 5.6, -2.0),
					color = "body",
					rot = CFrame.Angles(0, 0, rad(-14)),
					g = "head",
				},
				{
					size = Vector3.new(0.3, 1.4, 0.35),
					at = Vector3.new(-0.35, 5.6, -2.0),
					color = "body",
					rot = CFrame.Angles(0, 0, rad(14)),
					g = "head",
				},
				{
					size = Vector3.new(0.25, 1.6, 0.5),
					at = Vector3.new(0, 4.1, -1.3),
					color = "accent",
					rot = CFrame.Angles(rad(-25), 0, 0),
					g = "head",
				},
				{
					size = Vector3.new(0.25, 1.5, 0.25),
					at = Vector3.new(0, 2.6, 1.85),
					color = "accent",
					rot = CFrame.Angles(rad(20), 0, 0),
					g = "tail",
				},
			},
			eyes(4.85, -3.0, 0.45, 0.2)
		),
	},
	alpaca = {
		crown = Vector3.new(0, 7.55, -1.2),
		tag = 8.2,
		pet = 0.5,
		joints = {
			head = Vector3.new(0, 3.9, -1.0),
			tail = Vector3.new(0, 3.7, 1.4),
		},
		parts = concat(legs(Vector3.new(0.5, 2.1, 0.5), 0.6, 1.0, "body"), {
			{ size = Vector3.new(1.9, 1.9, 2.8), at = Vector3.new(0, 3.0, 0), color = "body" },
			{ size = Vector3.one * 1.6, at = Vector3.new(0, 3.7, 0.5), color = "body", shape = "Ball" },
			{ size = Vector3.new(0.9, 2.6, 0.9), at = Vector3.new(0, 4.9, -1.1), color = "body", g = "head" },
			{ size = Vector3.new(0.9, 1.0, 1.2), at = Vector3.new(0, 6.4, -1.3), color = "body", g = "head" },
			{ size = Vector3.new(0.6, 0.5, 0.4), at = Vector3.new(0, 6.2, -2.05), color = "muzzle", g = "head" },
			{ size = Vector3.one * 0.9, at = Vector3.new(0, 7.0, -1.2), color = "body", shape = "Ball", g = "head" },
			{ size = Vector3.new(0.25, 0.7, 0.2), at = Vector3.new(0.32, 7.1, -1.05), color = "accent", g = "head" },
			{ size = Vector3.new(0.25, 0.7, 0.2), at = Vector3.new(-0.32, 7.1, -1.05), color = "accent", g = "head" },
			{ size = Vector3.new(0.6, 0.8, 0.5), at = Vector3.new(0, 3.6, 1.55), color = "body", g = "tail" },
		}, eyes(6.55, -1.92, 0.35, 0.2)),
	},
}

local function addPart(
	model: Model,
	root: BasePart,
	spec: PartSpec,
	scale: number,
	color: Color3,
	shiny: boolean,
	pivot: Vector3?
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
	local relative = CFrame.new(spec.at * scale) * (spec.rot or CFrame.identity)
	part.CFrame = root.CFrame * relative
	if spec.g and pivot then
		-- Junta animável: gira em volta do pivô (ombro, pescoço, base do rabo).
		local at = CFrame.new(pivot * scale)
		local motor = Instance.new("Motor6D")
		motor.Name = spec.g
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = at
		motor.C1 = relative:Inverse() * at
		motor.Parent = part
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
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

	-- Pivô de cada junta: patas giram no topo da primeira peça do grupo; o resto vem de joints.
	local pivots: { [string]: Vector3 } = table.clone(shape.joints)
	for _, spec in shape.parts do
		if spec.g and not pivots[spec.g] then
			pivots[spec.g] = spec.at + Vector3.new(0, spec.size.Y / 2, 0)
		end
	end

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
		local part = addPart(model, root, spec, scale, color, shiny and spec.color == "body", if spec.g then pivots[spec.g] else nil)
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
	-- O cliente anima todo modelo com esta tag (patas andando, cabeça, rabo).
	model:SetAttribute("Especie", speciesId)
	CollectionService:AddTag(model, AnimalModel.ANIMATED_TAG)
	return model
end

-- Tamanho do bicho quando anda atrás do jogador como pet.
function AnimalModel.petScale(speciesId: string): number
	local species = Species.byId[speciesId]
	return SHAPES[species.shape].pet
end

return AnimalModel
