local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Routes = require(Shared.Config.Routes)

local State = require(script.Parent.State)

local World = {}

local function statusLabel(routeId: string): TextLabel?
	local world = Workspace:FindFirstChild("Mundo")
	local portals = world and world:FindFirstChild("Portais")
	local portal = portals and portals:FindFirstChild(routeId)
	local beam = portal and (portal :: Model).PrimaryPart
	local gui = beam and beam:FindFirstChild("Rotulo")
	local label = gui and gui:FindFirstChild("Status")
	return label :: TextLabel?
end

local function updatePortals(profile)
	for _, routeId in Routes.order do
		local label = statusLabel(routeId)
		if label then
			if profile.routes[routeId] then
				label.Text = "✅ Entrar"
				label.TextColor3 = Color3.fromRGB(150, 255, 150)
			else
				local route = Routes.byId[routeId]
				label.Text = "🔒 "
					.. Balance.requirementText(routeId)
					.. " + 💰 "
					.. Format.number(route.unlockCost)
				label.TextColor3 = Color3.fromRGB(255, 190, 170)
			end
		end
	end
end

function World.start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "HoraDourada"
	tint.Parent = Lighting
	local golden = false

	task.spawn(function()
		while true do
			local active = State.isGoldenHour()
			if active ~= golden then
				golden = active
				TweenService:Create(tint, TweenInfo.new(1.5), {
					TintColor = if active then Color3.fromRGB(255, 232, 185) else Color3.new(1, 1, 1),
					Brightness = if active then 0.04 else 0,
				}):Play()
			end
			if State.profile then
				updatePortals(State.profile)
			end
			task.wait(0.5)
		end
	end)
end

return World
