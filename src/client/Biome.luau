-- Cada rota tem a luz do seu bioma (lamaçal mais quente, savana dourada…). Ao entrar numa
-- rota a cor da tela muda devagar; no centro/fazenda volta ao normal.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Routes = require(ReplicatedStorage:WaitForChild("Shared").Config.Routes)

local Biome = {}

local MARGIN = 30
local NORMAL = Color3.new(1, 1, 1)

local player = Players.LocalPlayer

local function currentRoute(position: Vector3)
	for _, routeId in Routes.order do
		local route = Routes.byId[routeId]
		local offset = position - route.origin
		local half = route.size / 2 + MARGIN
		if math.abs(offset.X) < half and math.abs(offset.Z) < half then
			return route
		end
	end
	return nil
end

function Biome.start()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "Bioma"
	effect.Parent = Lighting
	local last = nil
	task.spawn(function()
		while true do
			task.wait(0.5)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local route = currentRoute(root.Position)
				if route ~= last then
					last = route
					TweenService:Create(effect, TweenInfo.new(1.2), { TintColor = if route then route.tint or NORMAL else NORMAL }):Play()
				end
			end
		end
	end)
end

return Biome
