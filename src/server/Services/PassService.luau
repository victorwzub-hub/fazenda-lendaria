local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePasses = require(ReplicatedStorage:WaitForChild("Shared").Config.GamePasses)
local Notify = require(script.Parent.Notify)

local PassService = {}

local listeners: { (Player, string) -> () } = {}

local function grant(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	for _, listener in listeners do
		task.spawn(listener, player, key)
	end
end

function PassService.has(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function PassService.onGranted(listener: (Player, string) -> ())
	table.insert(listeners, listener)
end

function PassService.load(player: Player)
	for _, key in GamePasses.order do
		local pass = GamePasses.byId[key]
		if pass.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				grant(player, key)
			end
		end
	end
end

function PassService.prompt(player: Player, key: string): (boolean, string?)
	local pass = GamePasses.byId[key]
	if not pass then
		return false, "Passe inválido"
	end
	if PassService.has(player, key) then
		return false, "Você já tem esse passe!"
	end
	if pass.id <= 0 then
		return false, "Em breve!"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
	return true, nil
end

function PassService.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased or not player.Parent then
			return
		end
		for _, key in GamePasses.order do
			local pass = GamePasses.byId[key]
			if pass.id == passId then
				grant(player, key)
				Notify.big(
					player,
					pass.emoji .. " " .. pass.name .. " ativado!",
					pass.desc,
					Color3.fromRGB(255, 205, 60)
				)
			end
		end
	end)
end

return PassService
