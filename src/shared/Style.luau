-- Visual "de brinquedo" dos simuladores de Roblox: plástico com pecinhas (studs) e cores vivas.
local Style = {}

-- Materiais realistas que viram plástico. Neon, vidro, água e plástico liso ficam como estão.
local TOY: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Fabric] = true,
}

-- Área mínima do topo para ganhar studs; peças pequenas ficam lisas e não poluem.
local MIN_STUD_AREA = 6

local function vivid(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.2), math.min(1, v * 1.08))
end

function Style.toy(part: BasePart)
	if not TOY[part.Material] then
		return
	end
	part.Material = Enum.Material.Plastic
	part.Color = vivid(part.Color)
	local isBlock = part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Block)
	if isBlock and part.Size.X * part.Size.Z >= MIN_STUD_AREA then
		part.TopSurface = Enum.SurfaceType.Studs
	end
end

function Style.apply(root: Instance)
	if root:IsA("BasePart") then
		Style.toy(root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			Style.toy(descendant)
		end
	end
end

-- Contorno preto grosso nos textos, igual aos títulos dos simuladores.
function Style.outline(label: TextLabel | TextButton, thickness: number?)
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

return Style
