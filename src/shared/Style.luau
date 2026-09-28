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

local function vivid(color: Color3): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.2), math.min(1, v * 1.08))
end

-- Pecinhas em todas as faces (paredes, troncos, laterais), não só no topo:
-- é isso que dá o visual "LEGO" dos simuladores.
function Style.studs(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
end

function Style.toy(part: BasePart)
	local isBlock = part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Block)
	if TOY[part.Material] then
		part.Material = Enum.Material.Plastic
		part.Color = vivid(part.Color)
	end
	if isBlock and part.Material == Enum.Material.Plastic then
		Style.studs(part)
	end
end

-- Cor um pouco mais clara ou escura, para montar objetos em dois tons.
function Style.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
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
