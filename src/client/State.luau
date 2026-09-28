local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Balance)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local Request = Remotes.func("Request")

local State = {}
State.profile = nil :: any

local listeners: { (any) -> () } = {}

local function setProfile(profile)
	State.profile = profile
	for _, listener in listeners do
		task.spawn(listener, profile)
	end
end

function State.onProfile(listener: (any) -> ())
	table.insert(listeners, listener)
	if State.profile then
		task.spawn(listener, State.profile)
	end
end

function State.onCoins(listener: (number) -> ())
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		local coins = leaderstats:WaitForChild("Moedas") :: NumberValue
		listener(coins.Value)
		coins.Changed:Connect(listener)
	end)
end

function State.request(action: string, arg: string?): (boolean, any)
	local ok, success, result = pcall(function()
		return Request:InvokeServer(action, arg)
	end)
	if not ok then
		return false, "Sem conexão com o servidor"
	end
	return success, result
end

function State.coins(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Moedas")
	return if coins then (coins :: NumberValue).Value else 0
end

function State.hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function State.goldenHourEnds(): number
	return Workspace:GetAttribute("GoldenHourEnds") or 0
end

function State.isGoldenHour(): boolean
	return State.goldenHourEnds() > Workspace:GetServerTimeNow()
end

function State.production(): number
	return if State.profile then Balance.totalProduction(State.profile, State.hasPass("VIP")) else 0
end

function State.luck(): number
	return if State.profile then Balance.luck(State.profile, State.hasPass("SorteDupla"), State.isGoldenHour()) else 1
end

function State.capacity(): number
	return if State.profile then Balance.capacity(State.profile, State.hasPass("FazendaGigante")) else 0
end

function State.start()
	Remotes.event("Profile").OnClientEvent:Connect(setProfile)
	task.spawn(function()
		while not State.profile do
			local ok, result = State.request("GetProfile")
			if ok and type(result) == "table" then
				if not State.profile then
					setProfile(result)
				end
				return
			end
			task.wait(1)
		end
	end)
end

return State
